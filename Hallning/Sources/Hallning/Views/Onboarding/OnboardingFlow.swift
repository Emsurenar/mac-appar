import AVFoundation
import Foundation
import UserNotifications

/// State for the onboarding window: the steps and the guided captures.
@MainActor @Observable
final class OnboardingFlow {
    enum Step: Int, CaseIterable {
        case welcome, permissions, placement, good, bad, review
    }

    enum Phase: Equatable {
        case ready
        case countdown(Int)
        case capturing
        case captured
        case failed(String)
    }

    static let framesPerPose = 6
    static let minimumFrames = 4

    private(set) var step: Step = .welcome
    private(set) var promptIndex = 0
    private(set) var phase: Phase = .ready
    private(set) var samples: [CalibrationSample] = []

    private(set) var cameraStatus = CameraService.authorization
    private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined

    @ObservationIgnored private let model: AppModel
    @ObservationIgnored private var captureTask: Task<Void, Never>?

    init(model: AppModel) {
        self.model = model
    }

    var prompts: [OnboardingPrompt] {
        step == .bad ? OnboardingPrompt.bad : OnboardingPrompt.good
    }

    var prompt: OnboardingPrompt { prompts[min(promptIndex, prompts.count - 1)] }

    /// Captured samples in the current step.
    var capturedInStep: Int {
        samples.filter { $0.label == (step == .bad ? .bad : .good) }.count
    }

    var isBusy: Bool {
        switch phase {
        case .countdown, .capturing, .captured: true
        default: false
        }
    }

    // MARK: Navigation

    func go(to step: Step) {
        captureTask?.cancel()
        phase = .ready
        self.step = step
        promptIndex = step == .bad ? samples.filter { $0.label == .bad }.count : samples.filter { $0.label == .good }.count
        if step == .review { model.replaceCalibration(with: samples) }
    }

    func next() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        go(to: next)
    }

    func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        go(to: previous)
    }

    /// Starts over from the first good posture.
    func restartCaptures() {
        samples.removeAll()
        go(to: .good)
    }

    // MARK: Permissions

    func refreshPermissions() async {
        cameraStatus = CameraService.authorization
        notificationStatus = await model.notifications.authorizationStatus()
    }

    func requestCamera() async {
        _ = await CameraService.requestAccess()
        cameraStatus = CameraService.authorization
    }

    func requestNotifications() async {
        _ = await model.notifications.requestAuthorization()
        notificationStatus = await model.notifications.authorizationStatus()
    }

    // MARK: Capture

    func capture() {
        guard !isBusy, step == .good || step == .bad, promptIndex < prompts.count else { return }
        captureTask = Task { await runCapture() }
    }

    /// Redoes the previous pose; after a failure it just clears the message.
    func redo() {
        guard !isBusy else { return }
        if case .failed = phase {
            phase = .ready
            return
        }
        let label: PostureLabel = step == .bad ? .bad : .good
        if let index = samples.lastIndex(where: { $0.label == label }) {
            samples.remove(at: index)
            promptIndex = max(promptIndex - 1, 0)
        }
        phase = .ready
    }

    private func runCapture() async {
        for second in [3, 2, 1] {
            phase = .countdown(second)
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
        }
        phase = .capturing
        let current = prompt
        do {
            let images = try await model.camera.captureBurst(count: Self.framesPerPose, spacing: 0.15, warmup: 0.3)
            var poses: [BodyPose] = []
            var vectors: [FeatureVector] = []
            for image in images {
                guard let pose = await model.analyzer.analyze(image) else { continue }
                poses.append(pose)
                if let vector = FeatureVector(pose: pose, head: model.currentHeadSample) { vectors.append(vector) }
            }
            if Task.isCancelled { return }
            guard vectors.count >= Self.minimumFrames else {
                phase = .failed("Jag ser inte dina axlar och ditt huvud. Se till att överkroppen syns i bilden och försök igen.")
                return
            }
            let pose = poses.filter(\.isUsable).max { $0.confidence < $1.confidence }
            samples.append(CalibrationSample(label: current.label, issue: current.issue, promptIndex: current.id,
                                             vectors: vectors, pose: pose))
            phase = .captured
            try? await Task.sleep(for: .seconds(0.8))
            if Task.isCancelled { return }
            promptIndex += 1
            phase = .ready
            if promptIndex >= prompts.count { next() }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
