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
        case .idle: "Not calibrated"
        case .good: "Good posture"
        case .bad(let issue): issue.title
        case .uncertain: "Unsure"
        case .away: "Away from the computer"
        case .paused: "Paused"
        case .cameraBusy: "Camera in use"
        case .noPermission: "No camera access"
        case .error: "Something went wrong"
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
/// Alongside it, the AirPods neck angle is sampled every second against its own limit
/// and shorter window.
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
    /// Degrees the neck is bent down from neutral (AirPods), updated every second.
    private(set) var neckAngle: Double?
    /// The neck is past the limit (with a little hysteresis so it does not flicker).
    private(set) var isNeckBent = false

    @ObservationIgnored var classifier: PostureClassifier? {
        didSet { updateCamera() }
    }
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
    @ObservationIgnored private var neckWindow: [(date: Date, bent: Bool)] = []
    @ObservationIgnored private var neckTimer: Timer?
    @ObservationIgnored private var neckTicks = 0
    /// What the camera checks (or the system) say, before the neck is taken into account.
    @ObservationIgnored private var baseStatus: PostureStatus = .idle
    @ObservationIgnored private var cameraProgress = 0.0
    @ObservationIgnored private var cameraRemaining: TimeInterval?
    @ObservationIgnored private var neckProgress = 0.0
    @ObservationIgnored private var neckRemaining: TimeInterval?
    @ObservationIgnored private var wantsCamera = false
    @ObservationIgnored private var loop: Task<Void, Never>?
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var hasScore = false
    @ObservationIgnored private var isAsleep = false
    @ObservationIgnored private var isLocked = false

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
        if neckTimer == nil {
            neckTimer = Timer.scheduledTimer(withTimeInterval: Self.neckTick, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tickNeck() }
            }
        }
        updateCamera()
    }

    func stop() {
        loop?.cancel()
        loop = nil
        neckTimer?.invalidate()
        neckTimer = nil
        updateCamera()
    }

    func checkNow() {
        Task { await check() }
    }

    func pause(for duration: TimeInterval?) {
        let until = duration.map { Date().addingTimeInterval($0) } ?? endOfDay()
        pausedUntil = until
        resetWindow()
        setStatus(.paused(until: until))
    }

    func resume() {
        pausedUntil = nil
        resetWindow()
        checkNow()
    }

    /// The next reminder needs a full new window, for both the camera and the neck.
    func resetWindow() {
        windowStart = Date()
        window.removeAll()
        neckWindow.removeAll()
        cameraProgress = 0
        cameraRemaining = nil
        neckProgress = 0
        neckRemaining = nil
        isNeckBent = false
        refreshStatus()
    }

    private var isPausedNow: Bool {
        isSystemPaused || (pausedUntil.map { $0 > Date() } ?? false)
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
                // Someone is there but too little matched the calibration: uncertain, not away.
                record(CheckResult(date: date, kind: vectors.isEmpty ? .away : .uncertain, issue: nil,
                                   badProbability: 0, vectors: vectors, pose: pose, head: head))
                return
            }
            var kind: SampleKind = result.isUncertain ? .uncertain : (result.badProbability >= threshold ? .bad : .good)
            var issue = kind == .bad ? result.issue ?? .slouching : nil
            // The neck limit is a hard rule: a bent neck is bad posture whatever the camera thinks.
            if kind == .good && isNeckBent {
                kind = .bad
                issue = .neckBent
            }
            record(CheckResult(date: date, kind: kind, issue: issue,
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
        case .good: baseStatus = .good
        case .bad: baseStatus = .bad(result.issue ?? .slouching)
        case .uncertain: baseStatus = .uncertain
        case .away: baseStatus = .away
        }
        evaluateWindow(now: result.date, latestIsBad: result.kind == .bad)
        refreshStatus()
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
            cameraProgress = min(Double(badCount) / needed, 1)
            cameraRemaining = max(max(needed - Double(badCount), 0) * interval, requiredSpan - span, 0)
        } else {
            cameraProgress = 0
            cameraRemaining = nil
        }

        let fraction = window.isEmpty ? 0 : Double(badCount) / Double(window.count)
        guard span >= requiredSpan, Double(window.count) >= 0.6 * expected, fraction >= threshold else { return }

        var counts: [PostureIssue: Int] = [:]
        for sample in window { if let issue = sample.issue { counts[issue, default: 0] += 1 } }
        let issue = counts.max { $0.value < $1.value }?.key ?? .slouching
        remind(issue, minutes: duration, at: now)
    }

    private func remind(_ issue: PostureIssue, minutes duration: TimeInterval, at date: Date) {
        history.recordAlert(issue, at: date)
        resetWindow()
        onAlert?(issue, max(Int((duration / 60).rounded()), 1))
    }

    private func setStatus(_ status: PostureStatus) {
        baseStatus = status
        if status.isPaused || status == .noPermission || status == .idle || status == .cameraBusy {
            cameraProgress = 0
            cameraRemaining = nil
        }
        refreshStatus()
        onUpdate?()
    }

    /// Drops the latest bad checks after the user said the posture was fine.
    func forgiveRecentBad() {
        resetWindow()
        if baseStatus.isBad { baseStatus = .good }
        refreshStatus()
        onUpdate?()
    }

    /// Combines the camera status with the neck, and the two reminder countdowns.
    private func refreshStatus() {
        var combined = baseStatus
        switch baseStatus {
        case .good, .uncertain, .away:
            if isNeckBent { combined = .bad(.neckBent) }
        case .bad:
            if isNeckBent && neckProgress >= cameraProgress { combined = .bad(.neckBent) }
        default:
            break
        }
        if combined != status { status = combined }

        let cameraActive = baseStatus.isBad
        let neckActive = isNeckBent
        let newProgress = max(cameraActive ? cameraProgress : 0, neckActive ? neckProgress : 0)
        let newRemaining = [cameraActive ? cameraRemaining : nil, neckActive ? neckRemaining : nil].compactMap { $0 }.min()
        if newProgress != progress { progress = newProgress }
        if newRemaining != remaining { remaining = newRemaining }
        updateCamera()
    }

    // MARK: Neck (AirPods)

    static let neckTick: TimeInterval = 1

    /// The neck angle for an AirPods pitch, relative to the neutral position.
    func neckAngle(pitch: Double) -> Double {
        let neutral = settings.neckNeutralPitch
        return classifier?.neckAngle(pitch: pitch, neutral: neutral) ?? -(pitch - (neutral ?? 0))
    }

    private func tickNeck() {
        let now = Date()
        guard settings.useAirPods, let sample = motion.currentSample(now: now) else {
            if neckAngle != nil || isNeckBent {
                neckAngle = nil
                clearNeck()
            }
            return
        }
        let angle = neckAngle(pitch: sample.pitch)
        neckAngle = angle
        guard !isPausedNow else {
            if isNeckBent { clearNeck() }
            return
        }

        let limit = settings.maxNeckAngle
        let wasBent = isNeckBent
        isNeckBent = wasBent ? angle >= limit - 2 : angle >= limit
        neckWindow.append((now, angle >= limit))
        evaluateNeck(now: now)
        refreshStatus()

        // Keep the island current without posting every second.
        neckTicks += 1
        if wasBent != isNeckBent || (isNeckBent && neckTicks % 5 == 0) { onUpdate?() }
    }

    private func clearNeck() {
        isNeckBent = false
        neckProgress = 0
        neckRemaining = nil
        refreshStatus()
        onUpdate?()
    }

    private func evaluateNeck(now: Date) {
        let duration = settings.neckAlertDuration
        let threshold = settings.alertThreshold
        let start = max(windowStart, now.addingTimeInterval(-duration))
        neckWindow.removeAll { $0.date < start }

        let expected = max(duration / Self.neckTick, 1)
        let needed = max(ceil(threshold * expected), 1)
        let bentCount = neckWindow.filter(\.bent).count
        let span = neckWindow.first.map { now.timeIntervalSince($0.date) } ?? 0
        let requiredSpan = duration - 2 * Self.neckTick

        if isNeckBent {
            neckProgress = min(Double(bentCount) / needed, 1)
            neckRemaining = max(max(needed - Double(bentCount), 0) * Self.neckTick, requiredSpan - span, 0)
        } else {
            neckProgress = 0
            neckRemaining = nil
        }

        let fraction = neckWindow.isEmpty ? 0 : Double(bentCount) / Double(neckWindow.count)
        guard span >= requiredSpan, Double(neckWindow.count) >= 0.6 * expected, fraction >= threshold else { return }
        remind(.neckBent, minutes: duration, at: now)
    }

    // MARK: Camera

    /// The camera stays on for as long as checks run, so its light never blinks. It turns
    /// off while paused, locked, during video calls and before calibration.
    private func updateCamera() {
        let wanted = loop != nil && classifier != nil && !isPausedNow && baseStatus != .cameraBusy
            && CameraService.authorization == .authorized
        guard wanted != wantsCamera else { return }
        wantsCamera = wanted
        camera.setKeepRunning(wanted)
    }

    // MARK: System

    private func observeSystem() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        // Sleep and lock are tracked separately: the display can wake on the lock screen.
        let pairs: [(NotificationCenter, Notification.Name, @MainActor (PostureMonitor) -> Void)] = [
            (workspace, NSWorkspace.screensDidSleepNotification, { $0.isAsleep = true }),
            (workspace, NSWorkspace.screensDidWakeNotification, { $0.isAsleep = false }),
            (workspace, NSWorkspace.willSleepNotification, { $0.isAsleep = true }),
            (workspace, NSWorkspace.didWakeNotification, { $0.isAsleep = false }),
            (distributed, Notification.Name("com.apple.screenIsLocked"), { $0.isLocked = true }),
            (distributed, Notification.Name("com.apple.screenIsUnlocked"), { $0.isLocked = false }),
        ]
        for (center, name, update) in pairs {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    update(self)
                    self.setSystemPaused(self.isAsleep || self.isLocked)
                }
            }
            observers.append((center, token))
        }
    }

    private func setSystemPaused(_ paused: Bool) {
        guard paused != isSystemPaused else { return }
        isSystemPaused = paused
        if paused {
            resetWindow()
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
