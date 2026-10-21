// Unknot – a tiny menu bar friend that reminds you to stretch.

import AppKit
import Combine

@main
struct UnknotMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        if Snapshot.run(CommandLine.arguments) { return }
        LegacyMigration.run()  // before anything reads the settings
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

/// Posted by a second copy of the app before it quits, so the running one can show its settings.
private let showSettingsNotification = Notification.Name("io.github.emsurenar.unknot.showSettings")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let scheduler = BreakScheduler()
    private let prefs = Preferences.shared
    private var cancellables = Set<AnyCancellable>()
    private var shownIcon = ""
    private var shownTitle: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if quitIfAlreadyRunning() { return }
        MainMenu.install()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(anotherCopyWasOpened(_:)),
                                                            name: showSettingsNotification, object: nil)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        statusItem.button?.setAccessibilityTitle("Unknot")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        WindowManager.shared.onTestBreak = { [weak self] in self?.scheduler.showBreakNow() }
        scheduler.onChange = { [weak self] in self?.updateStatusItem() }
        scheduler.start()
        prefs.$intervalMinutes
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] minutes in self?.scheduler.reschedule(afterMinutes: minutes) }
            .store(in: &cancellables)

        if !prefs.hasCompletedOnboarding {
            WindowManager.shared.showWelcome()
        }
        Updater.shared.checkIfDue()
        if CommandLine.arguments.contains("--show-now") {
            // Window animations started while the app is still launching are dropped.
            perform(#selector(stretchNow), with: nil, afterDelay: 0.6)
        }
    }

    /// Opening the app again (Finder, Spotlight, Launchpad) shows the settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowManager.shared.showSettings()
        return false
    }

    private func quitIfAlreadyRunning() -> Bool {
        guard !CommandLine.arguments.contains("--relaunched"),
              let id = Bundle.main.bundleIdentifier else { return false }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: id).filter { $0 != .current }
        guard !others.isEmpty else { return false }
        DistributedNotificationCenter.default().postNotificationName(showSettingsNotification, object: nil,
                                                                     userInfo: nil, deliverImmediately: true)
        NSApp.terminate(nil)
        return true
    }

    @objc private func anotherCopyWasOpened(_ notification: Notification) {
        WindowManager.shared.showSettings()
    }

    // MARK: Menu bar icon

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }
        var icon = "figure.cooldown"
        var title = ""
        switch scheduler.status {
        case .paused, .outsideWorkHours:
            icon = "moon.zzz"
        case .inBreak:
            break
        case .upcoming(let minutes):
            if prefs.showCountdownInMenuBar { title = " " + L("%ld min", minutes) }
        }
        if icon != shownIcon {
            let image = NSImage(systemSymbolName: icon, accessibilityDescription: "Unknot")
            image?.isTemplate = true
            button.image = image
            shownIcon = icon
        }
        if title != shownTitle {
            button.title = title
            shownTitle = title
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        menu.addItem(infoItem(statusText))
        menu.addItem(infoItem(todayText))
        if let version = Updater.shared.availableVersion {
            menu.addItem(.separator())
            addItem(to: menu, L("Update available: %@…", version), #selector(openUpdate), symbol: "arrow.down.circle")
        }
        menu.addItem(.separator())

        addItem(to: menu, L("Stretch now"), #selector(stretchNow), symbol: "figure.cooldown")
        if scheduler.pausedUntil != nil {
            addItem(to: menu, L("Resume reminders"), #selector(resume), symbol: "play.circle")
        } else {
            let pause = NSMenuItem(title: L("Pause"), action: nil, keyEquivalent: "")
            pause.image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: nil)
            let sub = NSMenu()
            for (title, minutes) in [(L("For 30 minutes"), 30), (L("For 1 hour"), 60), (L("For 2 hours"), 120)] {
                addItem(to: sub, title, #selector(pauseFor(_:))).tag = minutes
            }
            sub.addItem(.separator())
            addItem(to: sub, L("For the rest of the day"), #selector(pauseToday))
            pause.submenu = sub
            menu.addItem(pause)
        }
        menu.addItem(.separator())
        addItem(to: menu, L("Settings…"), #selector(showSettings), key: ",", symbol: "gearshape")
        addItem(to: menu, L("Quit Unknot"), #selector(quit), key: "q")
    }

    private var statusText: String {
        switch scheduler.status {
        case .upcoming(let minutes):
            return minutes <= 1 ? L("Next break in less than a minute") : L("Next break in %ld minutes", minutes)
        case .inBreak:
            return L("Stretch break in progress")
        case .paused(let until):
            return L("Paused until %@", Self.format(until))
        case .outsideWorkHours(let resumes):
            guard let resumes else { return L("Outside working hours") }
            return L("Outside working hours · back %@", Self.format(resumes))
        }
    }

    private var todayText: String {
        switch prefs.breaksToday {
        case 0: return L("No stretch breaks yet today")
        case 1: return L("1 stretch break today")
        default: return L("%ld stretch breaks today", prefs.breaksToday)
        }
    }

    private static func format(_ date: Date) -> String {
        let f = DateFormatter()
        if Calendar.current.isDateInToday(date) {
            f.timeStyle = .short
        } else {
            f.setLocalizedDateFormatFromTemplate("EEEEjmm")
        }
        return f.string(from: date)
    }

    private func infoItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    @discardableResult
    private func addItem(to menu: NSMenu, _ title: String, _ action: Selector, key: String = "", symbol: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        menu.addItem(item)
        return item
    }

    // MARK: Actions

    @objc private func stretchNow() { scheduler.showBreakNow() }
    @objc private func pauseFor(_ sender: NSMenuItem) { scheduler.pause(minutes: sender.tag) }
    @objc private func pauseToday() { scheduler.pauseForRestOfDay() }
    @objc private func resume() { scheduler.resume() }
    @objc private func openUpdate() { Updater.shared.openReleasePage() }
    @objc func showSettings() { WindowManager.shared.showSettings() }
    @objc func showAbout() { WindowManager.shared.showSettings(.about) }
    @objc private func quit() { NSApp.terminate(nil) }
}
