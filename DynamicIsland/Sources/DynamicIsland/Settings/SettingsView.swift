import AppKit
import ServiceManagement
import SwiftUI

/// The pages in the settings sidebar, grouped like the island:
/// the tabs, then what pops out of the notch on its own.
enum SettingsPage: String, CaseIterable, Identifiable {
    case general, nowPlaying, home, calendar, clipboard, system, posture, unknot
    case volume, screenshots, water
    case about

    var id: Self { self }

    static let groups: [[SettingsPage]] = [
        [.general],
        [.nowPlaying, .home, .water, .calendar, .clipboard, .system, .posture, .unknot],
        [.volume, .screenshots],
        [.about],
    ]

    var title: String {
        switch self {
        case .general: "General"
        case .nowPlaying: "Now Playing"
        case .home: "Home"
        case .calendar: "Calendar"
        case .clipboard: "Clipboard and Files"
        case .system: "System"
        case .posture: "Posture"
        case .unknot: "Unknot"
        case .volume: "Volume and Brightness"
        case .screenshots: "Screenshots"
        case .water: "Water"
        case .about: "About"
        }
    }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .nowPlaying: "music.note"
        case .home: "house.fill"
        case .calendar: "calendar"
        case .clipboard: "doc.on.clipboard.fill"
        case .system: "gauge.with.dots.needle.67percent"
        case .posture: "figure.stand"
        case .unknot: "figure.cooldown"
        case .volume: "speaker.wave.2.fill"
        case .screenshots: "camera.viewfinder"
        case .water: "drop.fill"
        case .about: "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .general, .about: .gray
        case .nowPlaying: .pink
        case .home: .orange
        case .calendar: .red
        case .clipboard: .blue
        case .system: .green
        case .posture: .teal
        case .unknot: .indigo
        case .volume: .purple
        case .screenshots: .mint
        case .water: .cyan
        }
    }
}

/// Settings like System Settings: a sidebar of pages, each with grouped,
/// rounded cards of rows on a soft gray background.
struct SettingsView: View {
    @Environment(IslandModel.self) private var model
    @State private var selection: SettingsPage = .general
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var hasAccessibility = MediaKeyInterceptor.hasPermission
    var onClose: () -> Void = {}

    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(spacing: 0) {
                header
                ScrollView(.vertical) { page(selection) }
                    .scrollIndicators(.automatic)
                    .id(selection)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .tint(.orange)
        .frame(width: SettingsWindowController.size.width, height: SettingsWindowController.size.height)
            .onReceive(permissionTimer) { _ in
                hasAccessibility = MediaKeyInterceptor.hasPermission
            }
            .onAppear {
                model.home.refresh()
                model.calendar.reload()
                TileColorPanel.shared.detach()
            }
    }

    /// One page of settings (also rendered on its own by `--snapshots`).
    func page(_ page: SettingsPage) -> some View {
        @Bindable var settings = model.settings
        return VStack(alignment: .leading, spacing: 0) {
            switch page {
            case .general:
                SettingsSection(footer: settings.hoverToOpen
                    ? "You feel a tap when the pointer reaches the notch and when a slider hits its end – only with a finger on the trackpad."
                    : "Click the notch to open the island. You feel a tap when a slider hits its end.") {
                    SettingsToggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                    SettingsToggle("Open when the pointer rests on the notch", isOn: $settings.hoverToOpen)
                    SettingsToggle("Haptic feedback", isOn: $settings.hapticFeedback)
                }
            case .nowPlaying:
                SettingsSection(footer: "While music plays, the artwork and an equalizer sit on either side of the notch.") {
                    SettingsToggle("Show what’s playing", isOn: $settings.showLiveActivity)
                    SettingsToggle("Show track changes", isOn: $settings.showTrackChanges)
                    SettingsToggle("Show audio output changes", isOn: $settings.showDeviceChanges)
                }
            case .home:
                SettingsSection(footer: "Pick any shortcut with the + tile in the island’s Home tab. Shortcuts in this folder get a tile automatically. A leading emoji becomes the tile’s icon, and a shortcut that outputs “on” or “off” shows that state.") {
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
            case .calendar:
                SettingsSection(footer: "Events come from the Calendar app. To see your Google Calendar, add your Google account under System Settings › Internet Accounts and turn on Calendars.") {
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
            case .clipboard:
                SettingsSection("Files", footer: "Drag files onto the notch to keep them at the top of this tab. New screenshots and downloads show up there by themselves. Every file stays for 5 minutes, also after you drag it out, unless you remove it. The files themselves never move.") {
                    SettingsToggle("Keep files you drop on the notch", isOn: $settings.showShelfTab)
                    if settings.showShelfTab {
                        SettingsToggle("Add new screenshots and downloads", isOn: $settings.shelveNewFiles)
                    }
                }
                SettingsSection("Clipboard", footer: "The last 20 things you copied, newest first. They stay in memory only, and passwords from password managers are skipped. Pasting needs Accessibility access; without it, an item is just copied.") {
                    SettingsToggle("Show clipboard history", isOn: $settings.showClipboardTab)
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
            case .system:
                SettingsSection(footer: "Memory, CPU, heat, battery and uptime. It only measures while the tab is open.") {
                    SettingsToggle("Show System tab", isOn: $settings.showSystemTab)
                }
            case .posture:
                SettingsSection(footer: "Posture watches how you sit through the camera. It comes with the island; while it runs, its reminders and status appear in the notch.") {
                    CompanionToggle(companion: .posture)
                    SettingsToggle("Show Posture tab", isOn: $settings.showPostureTab)
                    SettingsToggle("Show posture reminders", isOn: $settings.showPostureAlerts)
                    SettingsToggle("Show a live activity for poor posture", isOn: $settings.showPostureLiveActivity)
                    SettingsRow(action: { model.posture.openApp(companions: model.companions) }) {
                        Image(systemName: model.posture.isConnected ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(model.posture.isConnected ? Color.green : Color.secondary)
                        Text("Open Posture")
                        Spacer()
                        Text(model.posture.isConnected ? "Running" : "Not Running").foregroundStyle(.secondary)
                        Chevron()
                    }
                    .disabled(!model.companions.isAvailable(.posture))
                }
            case .unknot:
                SettingsSection(footer: "Unknot drops a stretch break out of the notch every 20 minutes. It comes with the island and has its own settings for the interval, the exercises and the sound.") {
                    CompanionToggle(companion: .unknot)
                    SettingsRow(action: { model.companions.stretchNow() }) {
                        Text("Stretch now")
                        Spacer()
                        Chevron()
                    }
                    .disabled(!model.companions.running.contains(.unknot))
                    SettingsRow(action: { model.companions.open(.unknot) }) {
                        Image(systemName: model.companions.running.contains(.unknot) ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundStyle(model.companions.running.contains(.unknot) ? Color.green : Color.secondary)
                        Text("Open Unknot Settings")
                        Spacer()
                        Text(model.companions.running.contains(.unknot) ? "Running" : "Not Running").foregroundStyle(.secondary)
                        Chevron()
                    }
                    .disabled(!model.companions.isAvailable(.unknot))
                }
            case .volume:
                SettingsSection(footer: "The volume and brightness keys then show only in the island. Hold ⌥⇧ for finer steps.") {
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
            case .screenshots:
                SettingsSection(footer: "A new screenshot pops out of the notch for a few seconds. Drag it into any app, or click it to open it.") {
                    SettingsToggle("Show new screenshots", isOn: $settings.showScreenshots)
                }
            case .water:
                SettingsSection("Goal", footer: "Log a glass from the island’s Water tab. Days that reach the goal build a streak.") {
                    SettingsToggle("Show Water tab", isOn: $settings.showWaterTab)
                    SettingsRow {
                        Text("Daily goal")
                        Spacer()
                        Text("\(model.water.glassesToday) today").foregroundStyle(.secondary)
                        Stepper("\(settings.waterDailyGoal) glasses", value: $settings.waterDailyGoal, in: 1...20)
                            .fixedSize()
                    }
                    SettingsRow {
                        Text("Glass size")
                        Spacer()
                        Text(formatLitres(settings.waterDailyGoal * settings.waterGlassSize) + " a day").foregroundStyle(.secondary)
                        Picker("", selection: $settings.waterGlassSize) {
                            ForEach([150, 200, 250, 330, 400, 500], id: \.self) { Text("\($0) ml").tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                SettingsSection("Reminders", footer: "Only time at the Mac counts: the timer pauses while you're away and while the Mac sleeps. Later asks again in 10 minutes.") {
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
                }
            case .about:
                SettingsSection {
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
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    private var sidebar: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Dynamic Island")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.top, 38)
                    .padding(.bottom, 6)
                ForEach(Array(SettingsPage.groups.enumerated()), id: \.offset) { index, group in
                    if index > 0 {
                        Divider().padding(.vertical, 6).padding(.horizontal, 10)
                    }
                    ForEach(group) { page in
                        SidebarRow(page: page, isSelected: page == selection) { selection = page }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.never)
        .frame(width: 210)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text(selection.title)
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
        .padding(.horizontal, 20)
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
    let title: String?
    let footer: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            }
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

/// Turns one of the apps that come with the island on or off.
private struct CompanionToggle: View {
    @Environment(IslandModel.self) private var model
    let companion: CompanionApps.Companion

    var body: some View {
        let companions = model.companions
        if !companion.isSupported {
            SettingsRow {
                Text("Run \(companion.name)")
                Spacer()
                Text("Needs macOS \(companion.minimumMacOS)").foregroundStyle(.secondary)
            }
        } else if !companions.isAvailable(companion) {
            SettingsRow {
                Text("Run \(companion.name)")
                Spacer()
                Text("Not included in this build").foregroundStyle(.secondary)
            }
        } else {
            SettingsToggle("Run \(companion.name)", isOn: Binding(
                get: { companions.isEnabled(companion) },
                set: { companions.setEnabled(companion, $0) }
            ))
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

/// A page in the sidebar: a colored icon and its title, highlighted when selected.
private struct SidebarRow: View {
    let page: SettingsPage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: page.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(page.color.gradient))
                Text(page.title)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    static let size = CGSize(width: 720, height: 520)
    private let model: IslandModel
    private var window: NSWindow?

    init(model: IslandModel) {
        self.model = model
    }

    func show() {
        model.close()
        if window == nil {
            let window = NSWindow(contentRect: NSRect(origin: .zero, size: Self.size),
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
