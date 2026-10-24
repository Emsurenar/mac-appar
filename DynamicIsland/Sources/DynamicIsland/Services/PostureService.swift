import AppKit
import Foundation

/// Follows the Hållning posture app over distributed notifications.
@MainActor @Observable
final class PostureService {
    struct State: Equatable {
        var status: String
        var issue: String?
        var title: String
        var progress: Double
        var score: Int
        var todayGood: Double
        var headPitch: Double?
        var airpods: Bool
        var interval: Double
        var lastCheck: Date?
        var pausedUntil: Date?

        var isBad: Bool { status == "bad" }
        var isPaused: Bool { status == "paused" }
    }

    struct Alert: Equatable {
        var issue: String
        var title: String
        var body: String
        var minutes: Int
    }

    enum Command: String {
        case pause30, resume, check, open
    }

    private(set) var state: State?
    private(set) var lastUpdate: Date?
    private(set) var latestAlert: Alert?
    private(set) var isConnected = false

    @ObservationIgnored var onAlert: ((Alert) -> Void)?

    private static let stateName = Notification.Name("com.emresunar.Hallning.state")
    private static let alertName = Notification.Name("com.emresunar.Hallning.alert")
    private static let commandName = Notification.Name("com.emresunar.Hallning.command")
    private static let helloName = Notification.Name("com.emresunar.DynamicIsland.posture.hello")

    @ObservationIgnored private let center = DistributedNotificationCenter.default()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var lastHello = Date.distantPast
    @ObservationIgnored private var timer: Timer?

    func start() {
        guard observers.isEmpty else { return }
        observers.append(center.addObserver(forName: Self.stateName, object: nil, queue: .main) { [weak self] note in
            let state = Self.parseState(note.userInfo)
            MainActor.assumeIsolated { self?.receive(state) }
        })
        observers.append(center.addObserver(forName: Self.alertName, object: nil, queue: .main) { [weak self] note in
            let alert = Self.parseAlert(note.userInfo)
            MainActor.assumeIsolated {
                guard let self, let alert else { return }
                self.latestAlert = alert
                self.onAlert?(alert)
            }
        })
        // Re-evaluates the connection when Hållning goes quiet (e.g. it crashed).
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshConnection() }
        }
        sayHello()
    }

    func stop() {
        for observer in observers { center.removeObserver(observer) }
        observers.removeAll()
        timer?.invalidate()
    }

    func send(_ command: Command) {
        center.postNotificationName(Self.commandName, object: nil, userInfo: ["command": command.rawValue],
                                    deliverImmediately: true)
    }

    /// Opens Hållning even if it is not running.
    func openApp() {
        if isConnected {
            send(.open)
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.emresunar.Hallning") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func sayHello() {
        lastHello = Date()
        center.postNotificationName(Self.helloName, object: nil, userInfo: nil, deliverImmediately: true)
    }

    private func receive(_ state: State?) {
        guard let state else { return }
        self.state = state
        lastUpdate = Date()
        refreshConnection()
        if Date().timeIntervalSince(lastHello) >= 30 { sayHello() }
    }

    private func refreshConnection() {
        guard let state, let lastUpdate, state.status != "off" else {
            if isConnected { isConnected = false }
            return
        }
        let connected = Date().timeIntervalSince(lastUpdate) < 2 * state.interval + 20
        if connected != isConnected { isConnected = connected }
    }

    // MARK: Parsing

    private nonisolated static func parseState(_ info: [AnyHashable: Any]?) -> State? {
        guard let info, let status = info["status"] as? String else { return nil }
        func double(_ key: String) -> Double? { (info[key] as? NSNumber)?.doubleValue }
        return State(
            status: status,
            issue: info["issue"] as? String,
            title: info["title"] as? String ?? "Hållning",
            progress: double("progress") ?? 0,
            score: (info["score"] as? NSNumber)?.intValue ?? 0,
            todayGood: double("todayGood") ?? 0,
            headPitch: double("headPitch"),
            airpods: (info["airpods"] as? NSNumber)?.boolValue ?? false,
            interval: double("interval") ?? 10,
            lastCheck: double("lastCheck").map { Date(timeIntervalSince1970: $0) },
            pausedUntil: double("pausedUntil").map { Date(timeIntervalSince1970: $0) }
        )
    }

    private nonisolated static func parseAlert(_ info: [AnyHashable: Any]?) -> Alert? {
        guard let info, let title = info["title"] as? String else { return nil }
        return Alert(issue: info["issue"] as? String ?? "slouching",
                     title: title,
                     body: info["body"] as? String ?? "",
                     minutes: (info["minutes"] as? NSNumber)?.intValue ?? 3)
    }

    #if DEBUG
    /// Fake states for the snapshot renderer.
    func showPreview(_ state: State) {
        self.state = state
        lastUpdate = Date()
        isConnected = true
    }

    func showPreviewAlert(_ alert: Alert) {
        latestAlert = alert
    }
    #endif
}
