import AppKit
import Foundation

/// Posture and Unknot, the other apps in mac-appar. A full Dynamic Island build carries both in
/// Contents/Library/Helpers and runs them alongside the island; a copy installed on its own wins.
@MainActor @Observable
final class CompanionApps {
    enum Companion: String, CaseIterable, Identifiable {
        case posture, unknot

        var id: Self { self }

        var name: String {
            switch self {
            case .posture: "Posture"
            case .unknot: "Unknot"
            }
        }

        var bundleID: String {
            switch self {
            case .posture: "com.emresunar.Hallning"
            case .unknot: "io.github.emsurenar.unknot"
            }
        }

        /// The app's folder name inside Contents/Library/Helpers.
        var bundleName: String { "\(name).app" }

        var minimumMacOS: Int {
            switch self {
            case .posture: 26
            case .unknot: 14
            }
        }

        var isSupported: Bool {
            ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= minimumMacOS
        }
    }

    private(set) var running: Set<Companion> = []

    @ObservationIgnored private let settings: AppSettings
    /// The companions the island opened from inside itself, quit again with the island.
    @ObservationIgnored private var launchedHere: Set<Companion> = []
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            })
        }
        refresh()
        for companion in Companion.allCases where isEnabled(companion) {
            launch(companion)
        }
    }

    /// Quits the companions that run from inside the island.
    func stop() {
        for companion in launchedHere {
            instances(of: companion).forEach { $0.terminate() }
        }
        launchedHere.removeAll()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    func isEnabled(_ companion: Companion) -> Bool {
        switch companion {
        case .posture: settings.runPosture
        case .unknot: settings.runUnknot
        }
    }

    func setEnabled(_ companion: Companion, _ enabled: Bool) {
        switch companion {
        case .posture: settings.runPosture = enabled
        case .unknot: settings.runUnknot = enabled
        }
        if enabled {
            launch(companion)
        } else {
            instances(of: companion).forEach { $0.terminate() }
            launchedHere.remove(companion)
        }
    }

    /// The copy to run: one installed on its own, otherwise the one inside the island.
    func url(for companion: Companion) -> URL? {
        if let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: companion.bundleID),
           !isInsideAnotherApp(installed) {
            return installed
        }
        return bundledURL(for: companion)
    }

    func bundledURL(for companion: Companion) -> URL? {
        let url = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/Helpers/\(companion.bundleName)")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Whether the island can run the companion at all: there's a copy, and this macOS is new enough.
    func isAvailable(_ companion: Companion) -> Bool {
        companion.isSupported && url(for: companion) != nil
    }

    /// Opens the companion, or brings up its window if it already runs.
    func open(_ companion: Companion) {
        launch(companion, activates: true)
    }

    /// Starts a stretch break in Unknot straight away.
    func stretchNow() {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("io.github.emsurenar.unknot.stretchNow"), object: nil, userInfo: nil, deliverImmediately: true)
    }

    private func launch(_ companion: Companion, activates: Bool = false) {
        guard companion.isSupported, let url = url(for: companion) else { return }
        if !activates && running.contains(companion) { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = activates
        let isBundled = url == bundledURL(for: companion)
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, error in
            Task { @MainActor in
                if error == nil && isBundled { self.launchedHere.insert(companion) }
                self.refresh()
            }
        }
    }

    private func instances(of companion: Companion) -> [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: companion.bundleID).filter { !$0.isTerminated }
    }

    private func refresh() {
        let now = Set(Companion.allCases.filter { !instances(of: $0).isEmpty })
        if now != running { running = now }
    }

    private func isInsideAnotherApp(_ url: URL) -> Bool {
        url.deletingLastPathComponent().path.contains(".app/")
    }
}
