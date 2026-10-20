import AppKit
import SwiftUI

/// Owns the settings and welcome windows. While one is open the app shows a Dock icon,
/// so it can be found with ⌘-Tab; afterwards it goes back to living only in the menu bar.
@MainActor
final class WindowManager: NSObject, NSWindowDelegate {
    static let shared = WindowManager()
    static let settingsSize = NSSize(width: 580, height: 620)

    var onTestBreak: (() -> Void)?

    private var settingsWindow: NSWindow?
    private var settingsTabs: NSTabViewController?
    private var welcomeWindow: NSWindow?

    func showSettings(_ tab: SettingsTab = .general) {
        if settingsWindow == nil {
            let (window, tabs) = makeSettingsWindow()
            window.delegate = self
            window.center()
            settingsWindow = window
            settingsTabs = tabs
        }
        settingsTabs?.selectedTabViewItemIndex = tab.rawValue
        present(settingsWindow!)
    }

    func showWelcome() {
        if welcomeWindow == nil {
            let view = WelcomeView(onTryBreak: { [weak self] in self?.onTestBreak?() },
                                   onDone: { [weak self] in self?.welcomeWindow?.close() })
            let host = NSHostingController(rootView: view)
            let window = NSWindow(contentViewController: host)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.title = L("Welcome to Sträckis")
            window.delegate = self
            window.setContentSize(host.view.fittingSize)
            window.center()
            welcomeWindow = window
        }
        present(welcomeWindow!)
    }

    func makeSettingsWindow() -> (NSWindow, NSTabViewController) {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        for tab in SettingsTab.allCases {
            let host = NSHostingController(rootView: tab.makeView(onTestBreak: { [weak self] in self?.onTestBreak?() }))
            host.sizingOptions = []
            host.preferredContentSize = Self.settingsSize
            host.title = tab.title
            let item = NSTabViewItem(viewController: host)
            item.label = tab.title
            item.image = NSImage(systemSymbolName: tab.symbol, accessibilityDescription: tab.title)
            tabs.addTabViewItem(item)
        }
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.toolbarStyle = .preference
        window.setContentSize(Self.settingsSize)
        window.isReleasedWhenClosed = false
        return (window, tabs)
    }

    private func present(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow else { return }
        if closing === welcomeWindow {
            Preferences.shared.hasCompletedOnboarding = true
        }
        let othersOpen = [settingsWindow, welcomeWindow].contains { window in
            guard let window, window !== closing else { return false }
            return window.isVisible
        }
        if !othersOpen {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

/// The app's own menu bar, visible while a window is open.
enum MainMenu {
    @MainActor
    static func install() {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: L("About Sträckis"), action: #selector(AppDelegate.showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Settings…"), action: #selector(AppDelegate.showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: L("Hide Sträckis"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: L("Quit Sträckis"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(submenu: appMenu)

        let editMenu = NSMenu(title: L("Edit"))
        editMenu.addItem(withTitle: L("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L("Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: L("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(submenu: editMenu)

        let windowMenu = NSMenu(title: L("Window"))
        windowMenu.addItem(withTitle: L("Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: L("Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(submenu: windowMenu)

        NSApp.mainMenu = main
        NSApp.windowsMenu = windowMenu
    }
}

private extension NSMenu {
    func addItem(submenu: NSMenu) {
        let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }
}
