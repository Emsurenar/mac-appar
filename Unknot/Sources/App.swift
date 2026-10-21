// Unknot – a tiny menu bar friend that reminds you to stretch.

import AppKit
import Combine
import SwiftUI

@main
struct UnknotMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        if Snapshot.run(CommandLine.arguments) { return }
        if CommandLine.arguments.contains("--remove-login-item") {
            try? LoginItem.setEnabled(false)  // used by `install.sh --uninstall`
            return
        }
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
    private var shownMood: MenuBarIcon.Mood?
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
        WindowManager.shared.onWelcomeFinished = { [weak self] in self?.showMenuBarHint() }
        scheduler.onChange = { [weak self] in self?.updateStatusItem() }
        scheduler.start()
        // Switch language straight away: menus and the settings window are rebuilt with the new strings.
        prefs.$language
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { _ in
                MainMenu.install()
                WindowManager.shared.reloadForLanguageChange()
            }
            .store(in: &cancellables)
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
        // A copy that was just quit (by an update, say) can still be listed for a moment; ignore it.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .filter { $0 != .current && !$0.isTerminated }
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
        var mood = MenuBarIcon.Mood.awake
        var title = ""
        switch scheduler.status {
        case .paused, .outsideWorkHours:
            mood = .asleep
        case .inBreak:
            mood = .happy
        case .waiting:
            break
        case .upcoming(let minutes):
            if prefs.showCountdownInMenuBar { title = " " + L("%ld min", minutes) }
        }
        if mood != shownMood {
            button.image = MenuBarIcon.image(mood)
            shownMood = mood
        }
        if title != shownTitle {
            button.title = title
            shownTitle = title
        }
        let tip = statusText
        if button.toolTip != tip { button.toolTip = tip }
    }

    /// After the welcome window, point at the icon once, so people know where the app went.
    private func showMenuBarHint() {
        guard let button = statusItem?.button, let window = button.window,
              window.occlusionState.contains(.visible),
              NSScreen.screens.contains(where: { $0.frame.intersects(window.frame) }) else { return }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarHint(next: statusText)
            .environment(\.locale, Localizer.locale))
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        DispatchQueue.main.asyncAfter(deadline: .now() + 9) { [weak popover] in popover?.performClose(nil) }
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

        if let session = scheduler.session, !session.finished {
            // A break is on screen, maybe on another display: finish or snooze it from here too
            addItem(to: menu, L("Done"), #selector(finishBreak), symbol: "checkmark.circle")
            addItem(to: menu, L("In %ld min", session.snoozeMinutes), #selector(snoozeBreak), symbol: "clock.arrow.circlepath")
        } else {
            addItem(to: menu, L("Stretch now"), #selector(stretchNow), symbol: "figure.cooldown")
        }
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
            if minutes <= 1 { return L("Next break in less than a minute") }
            return L("Next break at %@, in %ld min", Self.format(scheduler.nextBreak), minutes)
        case .waiting(.call(let app)):
            guard let app else { return L("Break waiting until your call ends") }
            return L("Break waiting until your call in %@ ends", app)
        case .waiting(.fullScreen):
            return L("Break waiting until you leave full screen")
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
        f.locale = Localizer.locale
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
    @objc private func finishBreak() { scheduler.session?.complete() }
    @objc private func snoozeBreak() { scheduler.session?.snooze() }
    @objc private func pauseFor(_ sender: NSMenuItem) { scheduler.pause(minutes: sender.tag) }
    @objc private func pauseToday() { scheduler.pauseForRestOfDay() }
    @objc private func resume() { scheduler.resume() }
    @objc private func openUpdate() { Updater.shared.offerUpdate() }
    @objc func showSettings() { WindowManager.shared.showSettings() }
    @objc func showAbout() { WindowManager.shared.showSettings(.about) }
    @objc private func quit() { NSApp.terminate(nil) }
}

/// The one-time pointer to the menu bar icon after the welcome window.
private struct MenuBarHint: View {
    let next: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("Unknot lives up here"))
                .font(.system(size: 13, weight: .semibold))
            Text(L("%@. Click the frog to stretch now, pause reminders or change the settings.", next))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 250, alignment: .leading)
        .padding(14)
    }
}
