import AppKit
import ServiceManagement

/// Where the app runs from, and moving it to /Applications.
enum AppMover {
    static var isInApplicationsFolder: Bool {
        let path = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        let folders = FileManager.default.urls(for: .applicationDirectory, in: [.localDomainMask, .userDomainMask])
        return folders.contains { path.hasPrefix($0.resolvingSymlinksInPath().path + "/") }
    }

    /// Copies the app to /Applications, replacing an older copy, moves this one to the Trash and relaunches.
    @MainActor
    static func moveToApplicationsAndRelaunch() throws {
        let fm = FileManager.default
        let source = Bundle.main.bundleURL
        let destination = URL(fileURLWithPath: "/Applications").appendingPathComponent(source.lastPathComponent)
        if fm.fileExists(atPath: destination.path) {
            try fm.trashItem(at: destination, resultingItemURL: nil)
        }
        try fm.copyItem(at: source, to: destination)
        // A translocated (read-only, quarantined) copy can't be trashed; the user can delete the download.
        if !source.path.contains("/AppTranslocation/") {
            try? fm.trashItem(at: source, resultingItemURL: nil)
        }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: destination, configuration: config) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    /// Turns launching at login on or off. Returns nil when it worked, otherwise what to tell the user.
    static func set(_ enabled: Bool) -> String? {
        let service = SMAppService.mainApp
        var failure: Error?
        do {
            if enabled { try service.register() } else { try service.unregister() }
        } catch {
            failure = error
        }
        // macOS can ask the user to allow the login item first.
        if enabled && service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
            return "Allow Dynamic Island under Login Items in System Settings, then it starts at login."
        }
        if isEnabled == enabled { return nil }
        let reason = failure.map { " \($0.localizedDescription)" } ?? ""
        return "Couldn’t change launch at login.\(reason)"
    }
}
