import AppKit
import CoreAudio
import CoreMediaIO
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

    /// Opens the app at `destination` and quits this copy.
    @MainActor
    static func relaunch(from destination: URL) {
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

/// Whether you're on a call. Reads only whether a microphone or camera is running, never what it records,
/// so it needs no permissions.
enum Calls {
    static var inProgress: Bool { microphoneInUse || cameraInUse }

    /// The processes recording from a microphone right now, other than this one. Needs macOS 14.2;
    /// nil when the system can't tell.
    private static var recordingProcesses: [pid_t]? {
        let system = AudioObjectID(kAudioObjectSystemObject)
        let processes = audioObjects(system, kAudioHardwarePropertyProcessObjectList)
        guard !processes.isEmpty else { return nil }
        let me = getpid()
        return processes.compactMap { process in
            guard audioValue(process, kAudioProcessPropertyIsRunningInput, UInt32(0)) != 0 else { return nil }
            let pid = audioValue(process, kAudioProcessPropertyPID, pid_t(0))
            return pid == me ? nil : pid
        }
    }

    /// The name of the app on the call, when it can be told: "zoom.us", "Google Chrome", "FaceTime".
    /// A helper process is named after the app it lives in; system services have no name.
    static var appUsingMicrophone: String? {
        guard let pid = recordingProcesses?.first else { return nil }
        var path = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return nil }
        let parts = String(cString: path).split(separator: "/")
        guard let outermost = parts.firstIndex(where: { $0.hasSuffix(".app") }) else { return nil }
        let name = FileManager.default.displayName(atPath: "/" + parts[...outermost].joined(separator: "/"))
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    /// True while another app records from a microphone.
    static var microphoneInUse: Bool {
        // macOS 14.2 and later list every process that uses audio, and whether it's recording
        if let recording = recordingProcesses { return !recording.isEmpty }
        let system = AudioObjectID(kAudioObjectSystemObject)
        // Earlier: the default microphone, unless it also plays sound, like headphones playing music
        let device = audioValue(system, kAudioHardwarePropertyDefaultInputDevice, AudioDeviceID(0))
        guard device != 0, audioObjects(device, kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeOutput).isEmpty
        else { return false }
        return audioValue(device, kAudioDevicePropertyDeviceIsRunningSomewhere, UInt32(0)) != 0
    }

    /// True while any app uses a camera.
    static var cameraInUse: Bool {
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var address = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
                                                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                                                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return false }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == noErr else { return false }
        address.mSelector = CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere)
        return devices.contains { device in
            var running: UInt32 = 0
            var read: UInt32 = 0
            let status = CMIOObjectGetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &read, &running)
            return status == noErr && running != 0
        }
    }

    private static func audioValue<T>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ fallback: T) -> T {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        var value = fallback
        var size = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &value) { AudioObjectGetPropertyData(object, &address, 0, nil, &size, $0) }
        return status == noErr ? value : fallback
    }

    private static func audioObjects(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                                     scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(object, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var ids = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(object, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return Array(ids.prefix(Int(size) / MemoryLayout<AudioObjectID>.size))
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
