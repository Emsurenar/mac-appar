import AppKit
import Foundation

enum PostureStatus: Equatable {
    case idle
    case good
    case bad(PostureIssue)
    case uncertain
    case away
    case paused(until: Date?)
    case cameraBusy
    case noPermission
    case error(String)

    var title: String {
        switch self {
        case .idle: "Inte kalibrerad"
        case .good: "Bra hållning"
        case .bad(let issue): issue.title
        case .uncertain: "Osäker hållning"
        case .away: "Ingen vid datorn"
        case .paused: "Pausad"
        case .cameraBusy: "Kameran används"
        case .noPermission: "Ingen kameraåtkomst"
        case .error: "Något gick fel"
        }
    }

    /// The status string in the island protocol.
    var islandValue: String {
        switch self {
        case .good: "good"
        case .bad: "bad"
        case .uncertain: "uncertain"
        case .away: "away"
        case .paused, .cameraBusy: "paused"
        case .idle, .noPermission, .error: "idle"
        }
    }

    var issue: PostureIssue? {
        if case .bad(let issue) = self { return issue }
        return nil
    }

    var isBad: Bool { issue != nil }

    var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}

/// The outcome of one check.
struct CheckResult {
    var date: Date
    var kind: SampleKind
    var issue: PostureIssue?
    var badProbability: Double
    var vectors: [FeatureVector]
    var pose: BodyPose?
    var head: HeadSample?
}

/// Takes a burst every `interval` seconds, classifies it and keeps the sliding window
/// that decides when to remind: bad for `threshold` of the checks over `duration`.
@MainActor @Observable
final class PostureMonitor {
    private(set) var status: PostureStatus = .idle
    private(set) var lastResult: CheckResult?
    private(set) var lastCheck: Date?
    /// 0…100, an exponential moving average of how good the posture is.
    private(set) var score: Double = 100
    /// 0…1 towards the next reminder while the posture is bad.
    private(set) var progress: Double = 0
    /// Estimated time until a reminder while the posture is bad.
    private(set) var remaining: TimeInterval?
    private(set) var pausedUntil: Date?
    private(set) var isChecking = false
    private(set) var isSystemPaused = false

    @ObservationIgnored var classifier: PostureClassifier?
    @ObservationIgnored var onAlert: ((PostureIssue, Int) -> Void)?
    /// Called after every status change, so the island can be updated.
    @ObservationIgnored var onUpdate: (() -> Void)?

    @ObservationIgnored private let camera: CameraService
    @ObservationIgnored private let analyzer: PoseAnalyzer
    @ObservationIgnored private let motion: HeadphoneMotionService
    @ObservationIgnored private let settings: PostureSettings
    @ObservationIgnored private let history: HistoryStore

    @ObservationIgnored private var window: [(date: Date, kind: SampleKind, issue: PostureIssue?)] = []
    @ObservationIgnored private var windowStart = Date()
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var hasScore = false

    init(camera: CameraService, analyzer: PoseAnalyzer, motion: HeadphoneMotionService,
         settings: PostureSettings, history: HistoryStore) {
        self.camera = camera
        self.analyzer = analyzer
        self.motion = motion
        self.settings = settings
        self.history = history
        observeSystem()
    }

    // MARK: Loop

    func start() {
        loop?.cancel()
        resetWindow()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.check()
                try? await Task.sleep(for: .seconds(max(self.settings.interval, 3)))
            }
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    func checkNow() {
        Task { await check() }
    }

    func pause(for duration: TimeInterval?) {
        let until = duration.map { Date().addingTimeInterval($0) } ?? endOfDay()
        pausedUntil = until
        status = .paused(until: until)
        progress = 0
        remaining = nil
        onUpdate?()
    }

    func resume() {
        pausedUntil = nil
        resetWindow()
        checkNow()
    }

    /// The next reminder needs a full new window.
    func resetWindow() {
        windowStart = Date()
        window.removeAll()
        progress = 0
        remaining = nil
    }

    // MARK: Check

    func check() async {
        guard !isChecking else { return }
        let now = Date()

        if let pausedUntil {
            if pausedUntil > now {
                setStatus(.paused(until: pausedUntil))
                return
            }
            self.pausedUntil = nil
            resetWindow()
        }
        if isSystemPaused {
            setStatus(.paused(until: nil))
            return
        }
        guard let classifier else {
            setStatus(.idle)
            return
        }
        guard CameraService.authorization == .authorized else {
            setStatus(.noPermission)
            return
        }
        if settings.pauseDuringCalls && camera.isInUseByAnotherApplication(deviceID: settings.cameraID) {
            resetWindow()
            setStatus(.cameraBusy)
            return
        }

        isChecking = true
        defer { isChecking = false }
        do {
            let images = try await camera.captureBurst(count: 3)
            let head = settings.useAirPods ? motion.currentSample() : nil
            var poses: [BodyPose] = []
            for image in images {
                if let pose = await analyzer.analyze(image) { poses.append(pose) }
            }
            let vectors = poses.compactMap { FeatureVector(pose: $0, head: head) }
            let pose = poses.filter(\.isUsable).max { $0.confidence < $1.confidence } ?? poses.first
            let threshold = settings.sensitivity.threshold
            let date = Date()

            guard let vector = FeatureVector.median(vectors),
                  let result = classifier.classify(vector, threshold: threshold) else {
                record(CheckResult(date: date, kind: .away, issue: nil, badProbability: 0, vectors: [], pose: pose, head: head))
                return
            }
            let kind: SampleKind = result.isUncertain ? .uncertain : (result.badProbability >= threshold ? .bad : .good)
            record(CheckResult(date: date, kind: kind, issue: kind == .bad ? result.issue ?? .slouching : nil,
                               badProbability: result.badProbability, vectors: vectors, pose: pose, head: head))
        } catch {
            lastCheck = Date()
            setStatus(error is CameraError && CameraService.authorization != .authorized
                      ? .noPermission : .error(error.localizedDescription))
        }
    }

    private func record(_ result: CheckResult) {
        lastResult = result
        lastCheck = result.date
        history.record(result.kind, issue: result.issue, at: result.date)

        switch result.kind {
        case .good, .bad:
            let value = (1 - result.badProbability) * 100
            score = hasScore ? score * 0.8 + value * 0.2 : value
            hasScore = true
            window.append((result.date, result.kind, result.issue))
        case .uncertain, .away:
            break
        }

        switch result.kind {
        case .good: status = .good
        case .bad: status = .bad(result.issue ?? .slouching)
        case .uncertain: status = .uncertain
        case .away: status = .away
        }
        evaluateWindow(now: result.date, latestIsBad: result.kind == .bad)
        onUpdate?()
    }

    private func evaluateWindow(now: Date, latestIsBad: Bool) {
        let duration = settings.alertDuration
        let interval = max(settings.interval, 1)
        let threshold = settings.alertThreshold
        let start = max(windowStart, now.addingTimeInterval(-duration))
        window.removeAll { $0.date < start }

        let expected = max(duration / interval, 1)
        let needed = max(ceil(threshold * expected), 1)
        let badCount = window.filter { $0.kind == .bad }.count
        let span = window.first.map { now.timeIntervalSince($0.date) } ?? 0
        let requiredSpan = duration - 1.5 * interval

        if latestIsBad {
            progress = min(Double(badCount) / needed, 1)
            remaining = max(max(needed - Double(badCount), 0) * interval, requiredSpan - span, 0)
        } else {
            progress = 0
            remaining = nil
        }

        let fraction = window.isEmpty ? 0 : Double(badCount) / Double(window.count)
        guard span >= requiredSpan, Double(window.count) >= 0.6 * expected, fraction >= threshold else { return }

        var counts: [PostureIssue: Int] = [:]
        for sample in window { if let issue = sample.issue { counts[issue, default: 0] += 1 } }
        let issue = counts.max { $0.value < $1.value }?.key ?? .slouching
        history.recordAlert(issue, at: now)
        resetWindow()
        onAlert?(issue, max(Int((duration / 60).rounded()), 1))
    }

    private func setStatus(_ status: PostureStatus) {
        self.status = status
        if status.isPaused || status == .noPermission || status == .idle {
            progress = 0
            remaining = nil
        }
        onUpdate?()
    }

    /// Drops the latest bad checks after the user said the posture was fine.
    func forgiveRecentBad() {
        resetWindow()
        if status.isBad { status = .good }
        onUpdate?()
    }

    // MARK: System

    private func observeSystem() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        let pairs: [(NotificationCenter, Notification.Name, Bool)] = [
            (workspace, NSWorkspace.screensDidSleepNotification, true),
            (workspace, NSWorkspace.screensDidWakeNotification, false),
            (workspace, NSWorkspace.willSleepNotification, true),
            (workspace, NSWorkspace.didWakeNotification, false),
            (distributed, Notification.Name("com.apple.screenIsLocked"), true),
            (distributed, Notification.Name("com.apple.screenIsUnlocked"), false),
        ]
        for (center, name, pauses) in pairs {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.setSystemPaused(pauses) }
            }
            observers.append((center, token))
        }
    }

    private func setSystemPaused(_ paused: Bool) {
        guard paused != isSystemPaused else { return }
        isSystemPaused = paused
        if paused {
            setStatus(.paused(until: nil))
        } else {
            resetWindow()
            checkNow()
        }
    }

    private func endOfDay() -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date().addingTimeInterval(8 * 3600)
    }
}
