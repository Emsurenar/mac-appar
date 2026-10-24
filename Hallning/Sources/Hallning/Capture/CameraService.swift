@preconcurrency import AVFoundation
import CoreImage
import Foundation
import os

enum CameraError: LocalizedError {
    case noPermission, noDevice, timeout

    var errorDescription: String? {
        switch self {
        case .noPermission: "Posture doesn't have access to the camera."
        case .noDevice: "No camera was found."
        case .timeout: "The camera didn't respond."
        }
    }
}

struct CameraDevice: Identifiable, Hashable {
    let id: String
    let name: String
}

/// Owns the capture session. While monitoring, the session runs continuously at a low
/// frame rate so the camera light stays steady instead of blinking at every check; checks
/// take short bursts from that stream. Onboarding and the live views use a preview stream.
/// Frames are converted to CGImage and never written anywhere.
final class CameraService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private struct Burst {
        let count: Int
        let spacing: TimeInterval
        let warmup: TimeInterval
        let continuation: CheckedContinuation<[CGImage], Error>
        var images: [CGImage] = []
        var nextFrameAt: Date = .distantPast
    }

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.emresunar.Hallning.session")
    private let videoQueue = DispatchQueue(label: "com.emresunar.Hallning.video", qos: .userInitiated)
    private let context = CIContext(options: [.cacheIntermediates: false])
    private let log = Logger(subsystem: "com.emresunar.Hallning", category: "camera")

    // Shared between the queues, guarded by `lock`.
    private let lock = NSLock()
    private var bursts: [UUID: Burst] = [:]
    private var previewHandler: (@MainActor (CGImage) -> Void)?
    private var lastPreviewAt = Date.distantPast
    private var firstFrameAt: Date?
    private var keepRunning = false

    // Only touched on `sessionQueue`.
    private var isConfigured = false
    private var currentInput: AVCaptureDeviceInput?
    private var preferredDeviceID: String?
    /// Whether the preview frame rate (true) or the low monitoring rate (false) is set.
    private var appliedPreviewRate: Bool?

    static var authorization: AVAuthorizationStatus { AVCaptureDevice.authorizationStatus(for: .video) }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    static func availableDevices() -> [CameraDevice] {
        discovery().devices.map { CameraDevice(id: $0.uniqueID, name: $0.localizedName) }
    }

    private static func discovery() -> AVCaptureDevice.DiscoverySession {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                                         mediaType: .video, position: .unspecified)
    }

    private static func device(for id: String?) -> AVCaptureDevice? {
        let devices = discovery().devices
        if let id, let match = devices.first(where: { $0.uniqueID == id }) { return match }
        return devices.first { $0.deviceType == .builtInWideAngleCamera } ?? AVCaptureDevice.default(for: .video) ?? devices.first
    }

    /// True when another app (a video call) is using the selected camera right now.
    /// Our own session does not count, so this works while the camera is kept running.
    func isInUseByAnotherApplication(deviceID: String?) -> Bool {
        guard let device = Self.device(for: deviceID) else { return false }
        let inUse = device.isInUseByAnotherApplication
        if inUse { log.info("Camera is in use by another app") }
        return inUse
    }

    // MARK: Configuration

    func selectDevice(_ id: String?) {
        sessionQueue.async {
            self.preferredDeviceID = id
            guard self.isConfigured else { return }
            self.session.beginConfiguration()
            self.attachInput()
            self.session.commitConfiguration()
            self.appliedPreviewRate = nil
            self.applyFrameRate()
        }
    }

    func setKeepRunning(_ value: Bool) {
        lock.withLock { keepRunning = value }
        sessionQueue.async { self.updateRunning() }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        session.beginConfiguration()
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else if session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        }
        attachInput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        isConfigured = true
    }

    private func attachInput() {
        if let currentInput { session.removeInput(currentInput) }
        currentInput = nil
        guard let device = Self.device(for: preferredDeviceID),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        currentInput = input
        // The preset may not suit an external camera; fall back if needed.
        if !session.canSetSessionPreset(session.sessionPreset), session.canSetSessionPreset(.vga640x480) {
            session.sessionPreset = .vga640x480
        }
    }

    /// Runs the session while anyone needs frames.
    private func updateRunning() {
        let needed = lock.withLock { keepRunning || previewHandler != nil || !bursts.isEmpty }
        if needed {
            guard Self.authorization == .authorized else { return }
            configureIfNeeded()
            if !session.isRunning {
                lock.withLock { firstFrameAt = nil }
                appliedPreviewRate = nil
                session.startRunning()
                log.info("Camera started")
            }
            applyFrameRate()
        } else if session.isRunning {
            session.stopRunning()
            log.info("Camera stopped")
        }
    }

    /// 15 fps while only monitoring saves power; the live preview gets the camera's default.
    private func applyFrameRate() {
        guard session.isRunning, let device = currentInput?.device else { return }
        let wantsPreview = lock.withLock { previewHandler != nil }
        guard appliedPreviewRate != wantsPreview else { return }
        let duration = wantsPreview ? CMTime.invalid : CMTime(value: 1, timescale: 15)
        if !wantsPreview {
            let supported = device.activeFormat.videoSupportedFrameRateRanges.contains { $0.minFrameRate <= 15 && 15 <= $0.maxFrameRate }
            guard supported else { return }
        }
        appliedPreviewRate = wantsPreview
        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = duration
            device.activeVideoMaxFrameDuration = duration
            device.unlockForConfiguration()
        } catch {
            log.error("Could not set the frame rate: \(error.localizedDescription)")
        }
    }

    // MARK: Capture

    /// Starts the camera if needed, lets exposure settle and returns `count` frames.
    func captureBurst(count: Int = 3, spacing: TimeInterval = 0.1, warmup: TimeInterval = 0.8) async throws -> [CGImage] {
        guard Self.authorization == .authorized else { throw CameraError.noPermission }
        let id = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            lock.withLock {
                bursts[id] = Burst(count: count, spacing: spacing, warmup: warmup, continuation: continuation)
            }
            sessionQueue.async {
                self.updateRunning()
                if self.currentInput == nil { self.finish(id, error: CameraError.noDevice) }
            }
            videoQueue.asyncAfter(deadline: .now() + 6) { self.finish(id, error: CameraError.timeout) }
        }
    }

    /// Delivers about 15 frames per second on the main actor until `stopPreview()`.
    func startPreview(_ handler: @escaping @MainActor (CGImage) -> Void) {
        lock.withLock { previewHandler = handler }
        sessionQueue.async { self.updateRunning() }
    }

    func stopPreview() {
        lock.withLock { previewHandler = nil }
        sessionQueue.async { self.updateRunning() }
    }

    private func finish(_ id: UUID, error: Error?) {
        guard let burst = lock.withLock({ bursts.removeValue(forKey: id) }) else { return }
        if let error, burst.images.isEmpty {
            burst.continuation.resume(throwing: error)
        } else {
            burst.continuation.resume(returning: burst.images)
        }
        sessionQueue.async { self.updateRunning() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        let (wantsPreview, wantsBurst) = lock.withLock { () -> (Bool, Bool) in
            if firstFrameAt == nil { firstFrameAt = now }
            let since = now.timeIntervalSince(firstFrameAt ?? now)
            let preview = previewHandler != nil && now.timeIntervalSince(lastPreviewAt) >= 1 / 15
            let burst = bursts.values.contains { since >= $0.warmup && now >= $0.nextFrameAt }
            return (preview, burst)
        }
        guard wantsPreview || wantsBurst,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let image = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        var finished: [UUID] = []
        var handler: (@MainActor (CGImage) -> Void)?
        lock.withLock {
            let since = now.timeIntervalSince(firstFrameAt ?? now)
            for (id, pending) in bursts where since >= pending.warmup && now >= pending.nextFrameAt {
                var burst = pending
                burst.images.append(image)
                burst.nextFrameAt = now.addingTimeInterval(burst.spacing)
                bursts[id] = burst
                if burst.images.count >= burst.count { finished.append(id) }
            }
            if wantsPreview, let previewHandler {
                lastPreviewAt = now
                handler = previewHandler
            }
        }
        for id in finished { finish(id, error: nil) }
        if let handler {
            DispatchQueue.main.async { MainActor.assumeIsolated { handler(image) } }
        }
    }
}
