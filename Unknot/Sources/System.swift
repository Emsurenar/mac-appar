import AppKit
import ServiceManagement

/// "Open at login", backed by the system's login items.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }
    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func setEnabled(_ on: Bool) throws {
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

/// Offers to move the app into /Applications, so login items and updates keep working.
enum AppMover {
    static var isInApplicationsFolder: Bool {
        let path = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        let folders = FileManager.default.urls(for: .applicationDirectory, in: [.localDomainMask, .userDomainMask])
        return folders.contains { path.hasPrefix($0.resolvingSymlinksInPath().path + "/") }
    }

    /// Copies the app to /Applications, moves the old copy to the Trash and relaunches.
    @MainActor
    static func moveToApplicationsAndRelaunch() throws {
        let fm = FileManager.default
        let source = Bundle.main.bundleURL
        let destination = URL(fileURLWithPath: "/Applications").appendingPathComponent(source.lastPathComponent)
        if fm.fileExists(atPath: destination.path) {
            let installed = Bundle(url: destination)?.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            if !Updater.isVersion(Updater.currentVersion, newerThan: installed) {
                // The same or a newer version is already installed: switch to that one.
                if !source.path.contains("/AppTranslocation/") {
                    try? fm.trashItem(at: source, resultingItemURL: nil)
                }
                relaunch(from: destination)
                return
            }
            try fm.trashItem(at: destination, resultingItemURL: nil)
        }
        try fm.copyItem(at: source, to: destination)
        // A translocated (read-only, quarantined) copy can't be trashed; the user can delete the download.
        if !source.path.contains("/AppTranslocation/") {
            try? fm.trashItem(at: source, resultingItemURL: nil)
        }
        relaunch(from: destination)
    }

    @MainActor
    private static func relaunch(from destination: URL) {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.arguments = ["--relaunched"]
        NSWorkspace.shared.openApplication(at: destination, configuration: config) { _, _ in
            Task { @MainActor in NSApp.terminate(nil) }
        }
    }
}

enum Activity {
    /// Seconds since the last keyboard or mouse event. Needs no special permissions.
    static var secondsSinceLastInput: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    /// True while the main display is off. Nobody would see a break then.
    static var displayIsAsleep: Bool {
        CGDisplayIsAsleep(CGMainDisplayID()) != 0
    }

    /// True when the frontmost app shows a window that covers a whole screen (presentations, video, games).
    /// Window bounds and owners are readable without the Screen Recording permission.
    static var frontmostAppIsFullscreen: Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        else { return false }

        func bounds(_ window: [String: Any]) -> CGRect? {
            guard let dict = window[kCGWindowBounds as String] as? NSDictionary else { return nil }
            return CGRect(dictionaryRepresentation: dict)
        }
        // The Dock draws the wallpaper. A full-screen space has none, a zoomed window still does.
        let desktopLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
        let wallpapers = windows
            .filter { ($0[kCGWindowOwnerName as String] as? String) == "Dock" && ($0[kCGWindowLayer as String] as? Int ?? 0) < desktopLevel }
            .compactMap(bounds)

        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let rect = bounds(window) else { continue }
            for screen in NSScreen.screens {
                let frame = screen.frame
                guard abs(rect.width - frame.width) < 1 else { continue }
                if abs(rect.height - frame.height) < 1 { return true }
                // On Macs with a camera notch, full-screen windows stop below it.
                let notch = screen.safeAreaInsets.top
                let center = CGPoint(x: rect.midX, y: rect.midY)
                if notch > 0 && rect.height >= frame.height - notch - 1 && !wallpapers.contains(where: { $0.contains(center) }) {
                    return true
                }
            }
        }
        return false
    }
}

/// The app was called Sträckis before 1.2.0. Carries settings and statistics over,
/// and quits and removes the old app so there aren't two of them.
enum LegacyMigration {
    static let oldBundleIdentifier = "io.github.emsurenar.strackis"
    private static let doneKey = "migratedFromStrackis"

    @MainActor
    static func run() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: doneKey) {
            for (key, value) in defaults.persistentDomain(forName: oldBundleIdentifier) ?? [:]
            where defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
            defaults.set(true, forKey: doneKey)
        }

        for app in NSRunningApplication.runningApplications(withBundleIdentifier: oldBundleIdentifier) {
            app.terminate()
        }
        let folders = FileManager.default.urls(for: .applicationDirectory, in: [.localDomainMask, .userDomainMask])
        for folder in folders {
            let old = folder.appendingPathComponent("Str\u{00E4}ckis.app")
            guard Bundle(url: old)?.bundleIdentifier == oldBundleIdentifier else { continue }
            try? FileManager.default.trashItem(at: old, resultingItemURL: nil)
        }
    }
}
