import AppKit
import Foundation
import SwiftUI

/// The composition root: owns the services and connects them.
@MainActor @Observable
final class AppModel {
    struct WindowRequest: Equatable {
        let id: String
        let token = UUID()
    }

    enum WindowID {
        static let main = "main"
        static let onboarding = "onboarding"
    }

    let settings = PostureSettings()
    let camera = CameraService()
    let analyzer = PoseAnalyzer()
    let motion = HeadphoneMotionService()
    let history = HistoryStore()
    let island = IslandBridge()
    let notifications = NotificationService()
    let monitor: PostureMonitor

    private(set) var samples: [CalibrationSample] = []
    private(set) var classifier: PostureClassifier?
    private(set) var evaluation: PostureClassifier.Evaluation?
    private(set) var isEvaluating = false

    /// Latest live camera frame while a preview is shown (never stored).
    private(set) var previewImage: CGImage?
    private(set) var livePose: BodyPose?
    private(set) var liveResult: PostureClassifier.Result?

    /// A window the UI should open; observed by the menu bar label.
    private(set) var windowRequest: WindowRequest?

    @ObservationIgnored private var previewClients = 0
    @ObservationIgnored private var isAnalyzingPreview = false
    @ObservationIgnored private var lastPreviewAnalysis = Date.distantPast
    @ObservationIgnored private var terminateObserver: NSObjectProtocol?
    @ObservationIgnored private var airPodsActivated = false
    @ObservationIgnored private var evaluationTask: Task<Void, Never>?

    var isCalibrated: Bool { classifier != nil }

    init() {
        monitor = PostureMonitor(camera: camera, analyzer: analyzer, motion: motion, settings: settings, history: history)
        samples = CalibrationStore.load()
        retrain(evaluate: true)

        monitor.onAlert = { [weak self] issue, minutes in self?.deliverAlert(issue: issue, minutes: minutes) }
        monitor.onUpdate = { [weak self] in self?.publishState() }
        settings.onTimingChange = { [weak self] in self?.monitor.start() }
        settings.onCameraChange = { [weak self] in self?.applyCameraSettings() }
        settings.onAirPodsChange = { [weak self] in self?.applyAirPodsSetting() }

        notifications.onAction = { [weak self] action in
            guard let self else { return }
            switch action {
            case .pause: self.monitor.pause(for: 30 * 60)
            case .falseAlarm: self.giveFeedback(.good)
            case .open: self.openWindow(WindowID.main)
            }
        }
        island.stateProvider = { [weak self] in self?.islandState() ?? IslandBridge.State(
            status: "idle", title: "Hållning", progress: 0, score: 0, todayGood: 0, airpods: false, interval: 10) }
        island.onCommand = { [weak self] command in
            guard let self else { return }
            switch command {
            case .pause30: self.monitor.pause(for: 30 * 60)
            case .resume: self.monitor.resume()
            case .check: self.monitor.checkNow()
            case .open: self.openWindow(self.isCalibrated ? WindowID.main : WindowID.onboarding)
            }
        }

        notifications.configure()
        island.start()
        applyCameraSettings()
        applyAirPodsSetting()
        monitor.start()
        publishState()

        terminateObserver = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.island.sendOff() }
        }
    }

    // MARK: Windows

    func openWindow(_ id: String) {
        windowRequest = WindowRequest(id: id)
    }

    // MARK: Calibration

    func replaceCalibration(with samples: [CalibrationSample]) {
        self.samples = samples
        CalibrationStore.save(samples)
        retrain(evaluate: true)
        applyAirPodsSetting()
        monitor.resetWindow()
        monitor.checkNow()
    }

    func deleteSample(_ id: UUID) {
        samples.removeAll { $0.id == id }
        CalibrationStore.save(samples)
        retrain(evaluate: true)
    }

    /// "Stämmer inte?": adds the latest check as a new sample with the given label.
    func giveFeedback(_ label: PostureLabel) {
        guard let result = monitor.lastResult, !result.vectors.isEmpty else { return }
        var issue: PostureIssue?
        if label == .bad {
            issue = result.issue
            if issue == nil, let classifier, let vector = FeatureVector.median(result.vectors) {
                issue = classifier.inferIssue(vector)
            }
        }
        samples.append(CalibrationSample(label: label, issue: issue, promptIndex: -1, vectors: result.vectors,
                                         pose: result.pose, source: .feedback))
        CalibrationStore.save(samples)
        retrain(evaluate: true)
        if label == .good { monitor.forgiveRecentBad() }
    }

    private func retrain(evaluate: Bool) {
        classifier = PostureClassifier(samples: samples)
        monitor.classifier = classifier
        evaluationTask?.cancel()
        guard evaluate, classifier != nil else {
            evaluation = nil
            isEvaluating = false
            return
        }
        let samples = samples
        let threshold = settings.sensitivity.threshold
        isEvaluating = true
        evaluationTask = Task {
            let result = await Task.detached(priority: .utility) {
                PostureClassifier.crossValidate(samples, threshold: threshold)
            }.value
            guard !Task.isCancelled else { return }
            self.evaluation = result
            self.isEvaluating = false
        }
    }

    func deleteAllData() {
        samples = []
        CalibrationStore.delete()
        history.deleteAll()
        retrain(evaluate: false)
        monitor.resetWindow()
        monitor.checkNow()
        openWindow(WindowID.onboarding)
    }

    // MARK: Live preview

    func beginPreview() {
        previewClients += 1
        guard previewClients == 1 else { return }
        camera.startPreview { [weak self] image in self?.handlePreviewFrame(image) }
    }

    func endPreview() {
        previewClients = max(previewClients - 1, 0)
        guard previewClients == 0 else { return }
        camera.stopPreview()
        previewImage = nil
        livePose = nil
        liveResult = nil
    }

    private func handlePreviewFrame(_ image: CGImage) {
        guard previewClients > 0 else { return }
        previewImage = image
        guard !isAnalyzingPreview, Date().timeIntervalSince(lastPreviewAnalysis) > 0.25 else { return }
        isAnalyzingPreview = true
        lastPreviewAnalysis = Date()
        Task {
            let pose = await analyzer.analyze(image)
            isAnalyzingPreview = false
            guard previewClients > 0 else { return }
            livePose = pose
            if let pose, let classifier, let vector = FeatureVector(pose: pose, head: currentHeadSample) {
                liveResult = classifier.classify(vector, threshold: settings.sensitivity.threshold)
            } else {
                liveResult = nil
            }
        }
    }

    var currentHeadSample: HeadSample? {
        settings.useAirPods ? motion.currentSample() : nil
    }

    // MARK: AirPods

    /// Neck angle in degrees relative to the good calibration (positive is down).
    var neckAngle: Double? {
        guard settings.useAirPods, let pitch = motion.latest?.pitch else { return nil }
        return classifier?.neckAngle(pitch: pitch) ?? -pitch
    }

    /// Starts AirPods motion; before calibration this waits for onboarding, which explains the prompt.
    func activateAirPods() {
        airPodsActivated = true
        applyAirPodsSetting()
    }

    private func applyAirPodsSetting() {
        if settings.useAirPods && (isCalibrated || airPodsActivated) { motion.start() } else { motion.stop() }
    }

    private func applyCameraSettings() {
        camera.selectDevice(settings.cameraID)
        camera.setKeepRunning(settings.keepCameraOn)
    }

    // MARK: Alerts

    private func deliverAlert(issue: PostureIssue, minutes: Int) {
        let islandActive = island.isIslandActive
        switch settings.alertStyle {
        case .islandFirst:
            if islandActive {
                island.sendAlert(issue: issue, minutes: minutes)
                if settings.playSound { notifications.playSoftSound() }
            } else {
                notifications.postAlert(issue: issue, minutes: minutes)
            }
        case .both:
            if islandActive { island.sendAlert(issue: issue, minutes: minutes) }
            notifications.postAlert(issue: issue, minutes: minutes)
        case .notificationOnly:
            notifications.postAlert(issue: issue, minutes: minutes)
        }
    }

    // MARK: Island state

    private func islandState() -> IslandBridge.State {
        let status = monitor.status
        return IslandBridge.State(
            status: status.islandValue,
            issue: status.issue,
            title: status.title,
            progress: monitor.progress,
            score: Int(monitor.score.rounded()),
            todayGood: history.today.goodFraction ?? 0,
            headPitch: neckAngle,
            airpods: motion.isReceiving,
            interval: settings.interval,
            lastCheck: monitor.lastCheck,
            pausedUntil: monitor.pausedUntil
        )
    }

    private func publishState() {
        island.send(islandState())
    }
}
