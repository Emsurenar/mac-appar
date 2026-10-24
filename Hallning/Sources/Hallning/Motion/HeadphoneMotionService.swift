import CoreMotion
import Foundation

/// A unit vector, used for the AirPods gravity direction.
struct Vector3: Codable, Equatable, Sendable {
    var x: Double, y: Double, z: Double

    var length: Double { (x * x + y * y + z * z).squareRoot() }

    var normalized: Vector3 {
        let l = length
        return l > 0 ? Vector3(x: x / l, y: y / l, z: z / l) : self
    }

    /// Angle to another vector in degrees.
    func angle(to other: Vector3) -> Double {
        let a = normalized, b = other.normalized
        let dot = min(max(a.x * b.x + a.y * b.y + a.z * b.z, -1), 1)
        return acos(dot) * 180 / .pi
    }

    static func mean(_ vectors: [Vector3]) -> Vector3? {
        guard !vectors.isEmpty else { return nil }
        let n = Double(vectors.count)
        let sum = vectors.reduce(Vector3(x: 0, y: 0, z: 0)) { Vector3(x: $0.x + $1.x, y: $0.y + $1.y, z: $0.z + $1.z) }
        return Vector3(x: sum.x / n, y: sum.y / n, z: sum.z / n).normalized
    }
}

/// Head orientation from AirPods, averaged over a few seconds.
struct HeadSample: Codable, Equatable, Sendable {
    var gravity: Vector3
    /// Degrees.
    var pitch: Double
    var roll: Double
}

/// Reads head motion from AirPods (Pro, Max, 3rd gen and later). Optional: everything
/// works without it, and missing data is handled quietly.
@MainActor @Observable
final class HeadphoneMotionService {
    private(set) var isConnected = false
    private(set) var isReceiving = false
    private(set) var latest: HeadSample?

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    var authorization: CMAuthorizationStatus { CMHeadphoneMotionManager.authorizationStatus() }

    @ObservationIgnored private let manager = CMHeadphoneMotionManager()
    @ObservationIgnored private let delegateProxy = DelegateProxy()
    @ObservationIgnored private var buffer: [(date: Date, sample: HeadSample)] = []
    @ObservationIgnored private var isRunning = false

    init() {
        delegateProxy.owner = self
        manager.delegate = delegateProxy
    }

    func start() {
        guard !isRunning, manager.isDeviceMotionAvailable else { return }
        isRunning = true
        manager.startConnectionStatusUpdates()
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let sample = HeadSample(
                gravity: Vector3(x: motion.gravity.x, y: motion.gravity.y, z: motion.gravity.z),
                pitch: motion.attitude.pitch * 180 / .pi,
                roll: motion.attitude.roll * 180 / .pi
            )
            MainActor.assumeIsolated { self?.append(sample) }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        manager.stopDeviceMotionUpdates()
        manager.stopConnectionStatusUpdates()
        buffer.removeAll()
        latest = nil
        isReceiving = false
    }

    /// The mean of the last 3 s, or nil if the newest value is stale.
    func currentSample(now: Date = Date()) -> HeadSample? {
        guard let newest = buffer.last, now.timeIntervalSince(newest.date) < 1.5 else { return nil }
        let recent = buffer.filter { now.timeIntervalSince($0.date) <= 3 }.map(\.sample)
        guard let gravity = Vector3.mean(recent.map(\.gravity)) else { return nil }
        let n = Double(recent.count)
        return HeadSample(gravity: gravity,
                          pitch: recent.reduce(0) { $0 + $1.pitch } / n,
                          roll: recent.reduce(0) { $0 + $1.roll } / n)
    }

    private func append(_ sample: HeadSample) {
        let now = Date()
        buffer.append((now, sample))
        buffer.removeAll { now.timeIntervalSince($0.date) > 5 }
        // Publish at a calm rate; the UI only needs a couple of updates per second.
        if latest == nil || buffer.count % 12 == 0 { latest = currentSample(now: now) }
        if !isReceiving { isReceiving = true }
    }

    fileprivate func setConnected(_ connected: Bool) {
        isConnected = connected
        if !connected {
            buffer.removeAll()
            latest = nil
            isReceiving = false
        }
    }

    private final class DelegateProxy: NSObject, CMHeadphoneMotionManagerDelegate {
        weak var owner: HeadphoneMotionService?

        func headphoneMotionManagerDidConnect(_ manager: CMHeadphoneMotionManager) {
            let owner = owner
            Task { @MainActor in owner?.setConnected(true) }
        }

        func headphoneMotionManagerDidDisconnect(_ manager: CMHeadphoneMotionManager) {
            let owner = owner
            Task { @MainActor in owner?.setConnected(false) }
        }
    }
}
