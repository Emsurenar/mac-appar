import Foundation

/// Talks to the Dynamic Island app over distributed notifications.
///
/// - `com.emresunar.Hallning.state` (→ island): the current status, on every check.
/// - `com.emresunar.Hallning.alert` (→ island): a reminder to show.
/// - `com.emresunar.Hallning.command` (← island): pause30 | resume | check | open.
/// - `com.emresunar.DynamicIsland.posture.hello` (← island): the island is running; answer with a state.
@MainActor @Observable
final class IslandBridge {
    enum Command: String {
        case pause30, resume, check, open
    }

    struct State {
        var status: String
        var issue: PostureIssue?
        var title: String
        var progress: Double
        var score: Int
        var todayGood: Double
        var headPitch: Double?
        var neckLimit: Double
        var airpods: Bool
        var interval: Double
        var lastCheck: Date?
        var pausedUntil: Date?
    }

    static let stateName = Notification.Name("com.emresunar.Hallning.state")
    static let alertName = Notification.Name("com.emresunar.Hallning.alert")
    static let commandName = Notification.Name("com.emresunar.Hallning.command")
    static let helloName = Notification.Name("com.emresunar.DynamicIsland.posture.hello")

    private(set) var lastHello: Date?

    @ObservationIgnored var onCommand: ((Command) -> Void)?
    /// Asked for the current state when the island says hello.
    @ObservationIgnored var stateProvider: (() -> State)?

    @ObservationIgnored private let center = DistributedNotificationCenter.default()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    /// True when the island has said hello recently enough to show reminders itself.
    var isIslandActive: Bool {
        guard let lastHello else { return false }
        return Date().timeIntervalSince(lastHello) < 75
    }

    func start() {
        guard observers.isEmpty else { return }
        observers.append(center.addObserver(forName: Self.helloName, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.lastHello = Date()
                if let state = self.stateProvider?() { self.send(state) }
            }
        })
        observers.append(center.addObserver(forName: Self.commandName, object: nil, queue: .main) { [weak self] note in
            let raw = note.userInfo?["command"] as? String
            MainActor.assumeIsolated {
                guard let raw, let command = Command(rawValue: raw) else { return }
                self?.lastHello = Date()
                self?.onCommand?(command)
            }
        })
    }

    func send(_ state: State) {
        var info: [String: Any] = [
            "status": state.status,
            "title": state.title,
            "progress": state.progress,
            "score": state.score,
            "todayGood": state.todayGood,
            "airpods": state.airpods,
            "interval": state.interval,
            "version": 1,
        ]
        if let issue = state.issue { info["issue"] = issue.rawValue }
        if let pitch = state.headPitch { info["headPitch"] = pitch }
        info["neckLimit"] = state.neckLimit
        if let date = state.lastCheck { info["lastCheck"] = date.timeIntervalSince1970 }
        if let date = state.pausedUntil { info["pausedUntil"] = date.timeIntervalSince1970 }
        center.postNotificationName(Self.stateName, object: nil, userInfo: info, deliverImmediately: true)
    }

    func sendAlert(issue: PostureIssue, body: String, minutes: Int) {
        let info: [String: Any] = ["issue": issue.rawValue, "title": issue.title, "body": body, "minutes": minutes]
        center.postNotificationName(Self.alertName, object: nil, userInfo: info, deliverImmediately: true)
    }

    /// Tells the island that Posture has quit.
    func sendOff() {
        let info: [String: Any] = ["status": "off", "title": "Posture", "progress": 0.0, "score": 0, "todayGood": 0.0,
                                   "airpods": false, "interval": 10.0, "version": 1]
        center.postNotificationName(Self.stateName, object: nil, userInfo: info, deliverImmediately: true)
    }
}
