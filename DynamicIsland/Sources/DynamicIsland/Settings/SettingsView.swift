import AppKit
import ServiceManagement
import SwiftUI

/// Settings laid out like a Home app sheet: a rounded card with grouped,
/// white rows on a soft gray background, scrolling when it doesn't fit.
struct SettingsView: View {
    @Environment(IslandModel.self) private var model
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var hasAccessibility = MediaKeyInterceptor.hasPermission
    var onClose: () -> Void = {}

    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView(.vertical) { content }
            .scrollIndicators(.automatic)
            .background(Color(nsColor: .windowBackgroundColor))
            .tint(.orange)
            .frame(width: 520, height: 500)
            .onReceive(permissionTimer) { _ in
                hasAccessibility = MediaKeyInterceptor.hasPermission
            }
            .onAppear {
                model.home.refresh()
                model.calendar.reload()
                TileColorPanel.shared.detach()
            }
    }

    /// Everything inside the scroll view (also rendered on its own by `--snapshots`).
    var content: some View {
        @Bindable var settings = model.settings
        return VStack(alignment: .leading, spacing: 0) {
                header

                SettingsSection("General", footer: settings.hoverToOpen
                    ? "You feel a tap when the pointer reaches the notch and when a slider hits its end – only with a finger on the trackpad."
                    : "Click the notch to open the island. You feel a tap when a slider hits its end.") {
                    SettingsToggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                    SettingsToggle("Open when the pointer rests on the notch", isOn: $settings.hoverToOpen)
                    SettingsToggle("Haptic feedback", isOn: $settings.hapticFeedback)
                }

                SettingsSection("Live Activities") {
                    SettingsToggle("Show what’s playing", isOn: $settings.showLiveActivity)
                    SettingsToggle("Show track changes", isOn: $settings.showTrackChanges)
                    SettingsToggle("Show audio output changes", isOn: $settings.showDeviceChanges)
                }

                SettingsSection("Screenshots", footer: "A new screenshot pops out of the notch for a few seconds. Drag it into any app, or click it to open it.") {
                    SettingsToggle("Show new screenshots", isOn: $settings.showScreenshots)
                }

                SettingsSection("Home", footer: "Pick any shortcut with the + tile in the island’s Home tab. Shortcuts in this folder get a tile automatically. A leading emoji becomes the tile’s icon, and a shortcut that outputs “on” or “off” shows that state.") {
                    SettingsToggle("Show Home tab", isOn: $settings.showHomeTab)
                    SettingsRow {
                        Text("Shortcuts folder")
                        Spacer()
                        TextField("Optional", text: $settings.homeFolderName)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: 180)
                            .onSubmit { model.home.refresh() }
                    }
                    .disabled(!settings.showHomeTab)
                    SettingsRow(action: HomeService.openShortcutsApp) {
                        Text("Open Shortcuts")
                        Spacer()
                        Text(homeStatus).foregroundStyle(.secondary)
                        Chevron()
                    }
                }

                if settings.showHomeTab && !model.home.shortcuts.isEmpty {
                    SettingsSection("Tile Colors", footer: "Click a color to open the color wheel. You can also right-click a tile in the island and choose Choose Color…") {
                        ForEach(model.home.shortcuts) { shortcut in
                            TileColorRow(shortcut: shortcut)
                        }
                    }
                }

                SettingsSection("Posture", footer: "Posture is a companion app that watches how you sit. While it runs, its reminders and status appear in the island.") {
                    SettingsToggle("Show Posture tab", isOn: $settings.showPostureTab)
                    SettingsToggle("Show posture reminders", isOn: $settings.showPostureAlerts)
                    SettingsToggle("Show a live activity for poor posture", isOn: $settings.showPostureLiveActivity)
                    SettingsRow(action: { model.posture.openApp() }) {
                        Image(systemName: model.posture.isConnected ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(model.posture.isConnected ? Color.green : Color.secondary)
                        Text("Open Posture")
                        Spacer()
                        Text(model.posture.isConnected ? "Running" : "Not Running").foregroundStyle(.secondary)
                        Chevron()
                    }
                }

                SettingsSection("Calendar", footer: "Events come from the Calendar app. To see your Google Calendar, add your Google account under System Settings › Internet Accounts and turn on Calendars.") {
                    SettingsToggle("Show Calendar tab", isOn: $settings.showCalendarTab)
                    SettingsToggle("Remind me before events", isOn: $settings.showCalendarReminders)
                    SettingsRow {
                        Text("Remind me")
                        Spacer()
                        Picker("", selection: $settings.calendarLeadMinutes) {
                            ForEach([1, 5, 10, 15, 30], id: \.self) { Text("\($0) min before").tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    .disabled(!settings.showCalendarReminders)
                    SettingsRow(action: { model.calendar.requestAccess() }) {
                        Image(systemName: calendarAccessSymbol)
                            .foregroundStyle(model.calendar.access == .granted ? Color.green
                                : model.calendar.access == .denied ? Color.orange : Color.secondary)
                        Text("Calendar access")
                        Spacer()
                        Text(calendarAccessStatus).foregroundStyle(.secondary)
                        if model.calendar.access != .granted { Chevron() }
                    }
                    .disabled(model.calendar.access == .granted)
                }

                if model.calendar.access == .granted {
                    SettingsSection("Calendars", footer: "Missing your Google calendar? In System Settings › Internet Accounts, open your Google account and turn on Calendars, then open the Calendar app once so it syncs.") {
                        ForEach(model.calendar.sources) { source in
                            CalendarSourceRow(source: source)
                        }
                    }
                }

                SettingsSection("Shelf", footer: "Drag files onto the notch to keep them on the shelf. They stay there until you drag them out, and the files themselves never move.") {
                    SettingsToggle("Show Shelf tab", isOn: $settings.showShelfTab)
                }

                SettingsSection("Water", footer: "Only time at the Mac counts: the timer pauses while you're away and while the Mac sleeps. Later asks again in 10 minutes.") {
                    SettingsToggle("Remind me to drink water", isOn: $settings.showWaterReminders)
                    SettingsRow {
                        Text("Remind me every")
                        Spacer()
                        Picker("", selection: $settings.waterIntervalMinutes) {
                            ForEach([20, 30, 45, 60, 90, 120], id: \.self) { Text("\($0) min").tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    .disabled(!settings.showWaterReminders)
                    SettingsRow {
                        Text("Daily goal")
                        Spacer()
                        Text("\(model.water.glassesToday) today").foregroundStyle(.secondary)
                        Stepper("\(settings.waterDailyGoal) glasses", value: $settings.waterDailyGoal, in: 1...20)
                            .fixedSize()
                    }
                    .disabled(!settings.showWaterReminders)
                }

                SettingsSection("Clipboard", footer: "The last 20 things you copied, newest first. They stay in memory only, and passwords from password managers are skipped. Pasting needs Accessibility access; without it, an item is just copied.") {
                    SettingsToggle("Show Clipboard tab", isOn: $settings.showClipboardTab)
                    SettingsToggle("Paste the item you pick", isOn: $settings.pasteFromClipboardHistory)
                    if settings.pasteFromClipboardHistory && !hasAccessibility {
                        SettingsRow(action: openAccessibilitySettings) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text("Pasting requires Accessibility permission")
                            Spacer()
                            Text("Open Settings").foregroundStyle(.secondary)
                            Chevron()
                        }
                    }
                }

                SettingsSection("Volume and Brightness", footer: "The volume and brightness keys then show only in the island. Hold ⌥⇧ for finer steps.") {
                    SettingsToggle("Show volume changes in the island", isOn: $settings.showVolumeHUD)
                    SettingsToggle("Replace the system volume and brightness HUD", isOn: $settings.replaceSystemHUD)
                    if settings.replaceSystemHUD && !hasAccessibility {
                        SettingsRow(action: openAccessibilitySettings) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Text("Requires Accessibility permission")
                            Spacer()
                            Text("Open Settings").foregroundStyle(.secondary)
                            Chevron()
                        }
                    }
                }

                SettingsSection("About") {
                    SettingsRow(action: { model.onOpenWelcome?() }) {
                        Text("Show welcome")
                        Spacer()
                        Chevron()
                    }
                    SettingsRow {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }
                    SettingsRow(action: { NSApp.terminate(nil) }) {
                        Text("Quit Dynamic Island").foregroundStyle(.red)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Dynamic Island")
                .font(.system(size: 22, weight: .bold))
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .help("Close")
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    private var calendarAccessSymbol: String {
        switch model.calendar.access {
        case .granted: "checkmark.circle.fill"
        case .denied: "exclamationmark.triangle.fill"
        case .unknown: "circle.dashed"
        }
    }

    private var calendarAccessStatus: String {
        switch model.calendar.access {
        case .granted: "\(model.calendar.events.count) upcoming"
        case .denied: "Open Settings"
        case .unknown: "Allow"
        }
    }

    private var homeStatus: String {
        let count = model.home.shortcuts.count
        return count == 1 ? "1 in the island" : "\(count) in the island"
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let isEnabled = LoginItem.set(enabled)
        if isEnabled != launchAtLogin { launchAtLogin = isEnabled }
    }

    private func openAccessibilitySettings() {
        MediaKeyInterceptor.requestPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Grouped rows

struct SettingsSection<Content: View>: View {
    let title: String
    let footer: String?
    @ViewBuilder let content: Content

    init(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 20)
            VStack(spacing: 0) {
                if #available(macOS 15, *) {
                    Group(subviews: content) { rows in
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            row
                            if index < rows.count - 1 {
                                Divider().padding(.leading, 20)
                            }
                        }
                    }
                } else {
                    content
                }
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor)))
            if let footer {
                Text(footer)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 22)
    }
}

/// A row with the sheet's padding; tappable when given an action.
struct SettingsRow<Content: View>: View {
    var action: (() -> Void)?
    @ViewBuilder let content: Content
    @State private var isHovering = false

    init(action: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        let row = HStack(spacing: 10) { content }
            .font(.system(size: 14))
            .padding(.horizontal, 20)
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        if let action {
            Button(action: action) {
                row.background(Color.primary.opacity(isHovering ? 0.04 : 0))
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
        } else {
            row
        }
    }
}

struct SettingsToggle: View {
    let title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    var body: some View {
        SettingsRow {
            Text(title)
            Spacer(minLength: 12)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

/// One island tile with a color well; the well opens the system color panel.
private struct TileColorRow: View {
    @Environment(IslandModel.self) private var model
    let shortcut: HomeShortcut

    var body: some View {
        let home = model.home
        let color = home.color(for: shortcut)
        SettingsRow {
            Group {
                if let emoji = shortcut.emoji {
                    Text(emoji).font(.system(size: 13))
                } else {
                    Image(systemName: shortcut.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 26, height: 26)
            .background(Circle().fill(Color(nsColor: color ?? .systemGray)))
            Text(shortcut.title)
            Spacer(minLength: 12)
            if color != nil {
                Button("Reset") { home.setColor(nil, for: shortcut) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            ColorPicker("", selection: home.colorBinding(for: shortcut), supportsOpacity: false)
                .labelsHidden()
        }
    }
}

/// A calendar with a switch for whether the island shows it.
private struct CalendarSourceRow: View {
    @Environment(IslandModel.self) private var model
    let source: CalendarService.Source

    var body: some View {
        let settings = model.settings
        let isOn = Binding(
            get: { !settings.hiddenCalendarIDs.contains(source.id) },
            set: { shown in
                if shown { settings.hiddenCalendarIDs.remove(source.id) } else { settings.hiddenCalendarIDs.insert(source.id) }
                model.calendar.reload()
            }
        )
        SettingsRow {
            Circle()
                .fill(Color(nsColor: source.color))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(source.title)
                Text(source.account)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

struct Chevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.tertiary)
    }
}

// MARK: - Window

@MainActor
final class SettingsWindowController {
    private let model: IslandModel
    private var window: NSWindow?

    init(model: IslandModel) {
        self.model = model
    }

    func show() {
        model.close()
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
                                  styleMask: [.titled, .closable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.contentView = NSHostingView(rootView: SettingsView(onClose: { [weak window] in window?.close() })
                .environment(model))
            window.title = "Dynamic Island"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
                window.standardWindowButton(button)?.isHidden = true
            }
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
