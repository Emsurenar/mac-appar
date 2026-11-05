import AppKit

@main
enum DynamicIslandApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: IslandModel?
    private var islandWindow: IslandWindowController?
    private var settingsWindow: SettingsWindowController?
    private var welcomeWindow: WelcomeWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        let media = NowPlayingService()
        let audio = AudioService()
        let settings = AppSettings()
        let home = HomeService(settings: settings)
        let posture = PostureService()
        let calendar = CalendarService()
        let clipboard = ClipboardService()
        let water = WaterService()
        let screenshots = ScreenshotService()
        let downloads = DownloadsService()
        let model = IslandModel(media: media, audio: audio, brightness: BrightnessService(), airPods: AirPodsService(),
                                home: home, posture: posture, system: SystemService(), calendar: calendar, clipboard: clipboard,
                                water: water, screenshots: screenshots, downloads: downloads, settings: settings)
        let settingsWindow = SettingsWindowController(model: model)
        model.onOpenSettings = { [weak settingsWindow] in settingsWindow?.show() }
        let welcomeWindow = WelcomeWindowController(model: model)
        model.onOpenWelcome = { [weak welcomeWindow] in welcomeWindow?.show() }

        let islandWindow = IslandWindowController(model: model)
        islandWindow.show()
        media.start()
        audio.start()
        home.refresh()
        posture.start()
        calendar.start()
        clipboard.start()
        water.start()
        screenshots.start()
        downloads.start()
        if !CommandLine.arguments.contains("--snapshots") { model.companions.start() }

        self.model = model
        self.islandWindow = islandWindow
        self.settingsWindow = settingsWindow
        self.welcomeWindow = welcomeWindow
        if !settings.hasSeenWelcome && !CommandLine.arguments.contains("--snapshots") {
            welcomeWindow.show()
        }

        #if DEBUG
        if let flag = CommandLine.arguments.firstIndex(of: "--snapshots"), flag + 1 < CommandLine.arguments.count {
            SnapshotRenderer.run(model: model, directory: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
        }
        #endif
    }

    /// The app has no Dock icon, but its windows still need the standard shortcuts:
    /// without an Edit menu, ⌘V, ⌘C and ⌘A do nothing in the settings' text fields.
    private func installMainMenu() {
        let main = NSMenu()

        let app = NSMenu()
        app.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",").target = self
        app.addItem(.separator())
        app.addItem(withTitle: "Quit Dynamic Island", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(withTitle: "Dynamic Island", action: nil, keyEquivalent: "").submenu = app

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = edit

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(closeWindow), keyEquivalent: "w").target = self
        main.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = window

        NSApp.mainMenu = main
    }

    @objc private func showSettings() {
        model?.openSettings()
    }

    /// Closes the settings or welcome window; their close buttons may be hidden.
    @objc private func closeWindow() {
        guard let window = NSApp.keyWindow, window.styleMask.contains(.titled) else { return }
        window.close()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Launching the app again (e.g. from Finder) opens the settings.
        settingsWindow?.show()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.media.stop()
        model?.posture.stop()
        model?.calendar.stop()
        model?.clipboard.stop()
        model?.water.stop()
        model?.screenshots.stop()
        model?.downloads.stop()
        model?.companions.stop()
    }
}
