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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let media = NowPlayingService()
        let audio = AudioService()
        let settings = AppSettings()
        let home = HomeService(settings: settings)
        let model = IslandModel(media: media, audio: audio, brightness: BrightnessService(), home: home, settings: settings)
        let settingsWindow = SettingsWindowController(model: model)
        model.onOpenSettings = { [weak settingsWindow] in settingsWindow?.show() }

        let islandWindow = IslandWindowController(model: model)
        islandWindow.show()
        media.start()
        audio.start()
        home.refresh()

        self.model = model
        self.islandWindow = islandWindow
        self.settingsWindow = settingsWindow

        #if DEBUG
        if let flag = CommandLine.arguments.firstIndex(of: "--snapshots"), flag + 1 < CommandLine.arguments.count {
            SnapshotRenderer.run(model: model, directory: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
        }
        #endif
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Launching the app again (e.g. from Finder) opens the settings.
        settingsWindow?.show()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        model?.media.stop()
    }
}
