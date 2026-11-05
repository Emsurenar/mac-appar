import AppKit
import SwiftUI

/// Settings as one of the island's own pages: a row of icons, one for each tab and
/// for what pops out of the notch, and the switches for that part below it, styled
/// like the rest of the island. Typing (the Google client, the Shortcuts folder) and
/// colors stay in the Settings window, one click away.
struct SettingsTab: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        let section = model.islandSettingsSection
        VStack(alignment: .leading, spacing: 0) {
            sectionBar(selected: section)
                .padding(.top, 2)
            Text(section.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 6)
                .frame(height: IslandLayout.sectionHeaderHeight, alignment: .bottom)
            ScrollView(.vertical) {
                SettingsTabRows(section: section)
                    .id(section)
                    .transition(.islandContent(scale: 0.98))
            }
            .scrollIndicators(.never)
            .frame(height: IslandLayout.settingsListHeight, alignment: .top)
        }
        .padding(.horizontal, -6)
    }

    private func sectionBar(selected: SettingsPage) -> some View {
        HStack(spacing: 2) {
            ForEach(SettingsPage.islandSections) { page in
                Button { model.selectSettingsSection(page) } label: {
                    Image(systemName: page.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(page == selected ? Color.black : Color.white.opacity(0.7))
                        .frame(width: 28, height: 26)
                        .background(Circle().fill(page == selected ? Color.white : Color.white.opacity(0.08)))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(page.title)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

extension SettingsPage {
    /// The parts that have switches in the island's own settings page, in the island's order.
    static let islandSections: [SettingsPage] = [
        .general, .nowPlaying, .home, .posture, .water, .calendar, .clipboard, .system, .unknot, .volume, .screenshots,
    ]
}

// MARK: - Rows

private struct SettingsTabRows: View {
    @Environment(IslandModel.self) private var model
    let section: SettingsPage
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginMessage: String?
    @State private var hasAccessibility = MediaKeyInterceptor.hasPermission
    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var settings = model.settings
        VStack(spacing: 0) {
            switch section {
            case .general:
                IslandToggleRow("Launch at login", detail: loginMessage, isOn: Binding(
                    get: { launchAtLogin },
                    set: { loginMessage = LoginItem.set($0); launchAtLogin = LoginItem.isEnabled }
                ))
                IslandToggleRow("Open on hover", detail: "Rest the pointer on the notch", isOn: $settings.hoverToOpen)
                IslandToggleRow("Haptic feedback", detail: "Taps on the trackpad", isOn: $settings.hapticFeedback)
                IslandActionRow("Show welcome", symbol: "hand.wave.fill") { model.onOpenWelcome?() }
                IslandActionRow("Quit Dynamic Island", symbol: "power", isDestructive: true) { NSApp.terminate(nil) }
            case .nowPlaying:
                IslandToggleRow("Show what’s playing", detail: "Artwork and equalizer by the notch", isOn: $settings.showLiveActivity)
                IslandToggleRow("Show track changes", isOn: $settings.showTrackChanges)
                IslandToggleRow("Show audio output changes", isOn: $settings.showDeviceChanges)
            case .home:
                IslandToggleRow("Show Home tab", isOn: $settings.showHomeTab)
                IslandActionRow("Add shortcuts", symbol: "plus", detail: homeDetail) {
                    settings.showHomeTab = true
                    model.select(.home)
                    model.setChoosingShortcuts(true)
                }
                IslandActionRow("Folder and tile colors", symbol: "paintpalette.fill") { model.openSettings(.home) }
            case .posture:
                companionRow(.posture)
                IslandToggleRow("Show Posture tab", isOn: $settings.showPostureTab)
                IslandToggleRow("Show posture reminders", isOn: $settings.showPostureAlerts)
                IslandToggleRow("Live activity for poor posture", isOn: $settings.showPostureLiveActivity)
                IslandActionRow("Open Posture", symbol: "arrow.up.forward.app",
                                detail: model.posture.isConnected ? "Running" : "Not running") {
                    model.posture.openApp(companions: model.companions)
                }
                .disabled(!model.companions.isAvailable(.posture))
            case .water:
                IslandToggleRow("Show Water tab", isOn: $settings.showWaterTab)
                IslandValueRow("Daily goal", showing: "\(settings.waterDailyGoal) glasses",
                               detail: formatLitres(settings.waterDailyGoal * settings.waterGlassSize) + " a day",
                               value: $settings.waterDailyGoal, in: Array(1...20))
                IslandValueRow("Glass size", showing: "\(settings.waterGlassSize) ml",
                               value: $settings.waterGlassSize, in: [150, 200, 250, 330, 400, 500])
                IslandToggleRow("Remind me to drink", detail: "Only time at the Mac counts", isOn: $settings.showWaterReminders)
                IslandValueRow("Remind me every", showing: "\(settings.waterIntervalMinutes) min",
                               value: $settings.waterIntervalMinutes, in: [20, 30, 45, 60, 90, 120])
                    .disabled(!settings.showWaterReminders)
            case .calendar:
                googleRow
                IslandToggleRow("Show Calendar tab", isOn: $settings.showCalendarTab)
                IslandToggleRow("Remind me before events", isOn: $settings.showCalendarReminders)
                IslandValueRow("Remind me", showing: "\(settings.calendarLeadMinutes) min before",
                               value: $settings.calendarLeadMinutes, in: [1, 5, 10, 15, 30])
                    .disabled(!settings.showCalendarReminders)
            case .clipboard:
                IslandToggleRow("Keep files dropped on the notch", detail: "For 5 minutes", isOn: $settings.showShelfTab)
                IslandToggleRow("Add new screenshots and downloads", isOn: $settings.shelveNewFiles)
                    .disabled(!settings.showShelfTab)
                IslandToggleRow("Show clipboard history", detail: "The last 20 things you copied", isOn: $settings.showClipboardTab)
                IslandToggleRow("Paste the item you pick",
                                detail: settings.pasteFromClipboardHistory && !hasAccessibility ? "Needs Accessibility" : nil,
                                isOn: $settings.pasteFromClipboardHistory)
                if settings.pasteFromClipboardHistory && !hasAccessibility { accessibilityRow }
            case .system:
                IslandToggleRow("Show System tab", detail: "Memory, CPU, heat, battery", isOn: $settings.showSystemTab)
            case .unknot:
                companionRow(.unknot)
                IslandActionRow("Stretch now", symbol: "figure.cooldown") { model.companions.stretchNow() }
                    .disabled(!model.companions.running.contains(.unknot))
                IslandActionRow("Unknot settings", symbol: "arrow.up.forward.app",
                                detail: model.companions.running.contains(.unknot) ? "Running" : "Not running") {
                    model.companions.open(.unknot)
                }
                .disabled(!model.companions.isAvailable(.unknot))
            case .volume:
                IslandToggleRow("Show volume changes", isOn: $settings.showVolumeHUD)
                IslandToggleRow("Replace the system HUD", detail: "Volume and brightness keys", isOn: $settings.replaceSystemHUD)
                if settings.replaceSystemHUD && !hasAccessibility { accessibilityRow }
            case .screenshots:
                IslandToggleRow("Show new screenshots", detail: "Drag them out of the notch", isOn: $settings.showScreenshots)
            case .about:
                EmptyView()
            }
            IslandActionRow("More settings", symbol: "macwindow") { model.openSettings(section) }
        }
        .onReceive(permissionTimer) { _ in
            hasAccessibility = MediaKeyInterceptor.hasPermission
            launchAtLogin = LoginItem.isEnabled
        }
    }

    private var homeDetail: String {
        let count = model.home.shortcuts.count
        return count == 1 ? "1 in the island" : "\(count) in the island"
    }

    @ViewBuilder private var googleRow: some View {
        let calendar = model.calendar
        switch calendar.access {
        case .signedIn:
            IslandActionRow("Google Calendar", symbol: "checkmark", detail: calendar.account ?? "Signed in",
                            buttonTitle: "Sign Out") { calendar.signOut() }
        case .signingIn:
            IslandActionRow("Google Calendar", symbol: "hourglass", detail: "Finish signing in in your browser",
                            buttonTitle: "Cancel") { calendar.cancelSignIn() }
        case .signedOut:
            if calendar.hasClientID {
                IslandActionRow("Sign in with Google", symbol: "person.crop.circle.badge.plus",
                                detail: calendar.errorMessage) { calendar.signIn() }
            } else {
                IslandActionRow("Connect Google Calendar", symbol: "person.crop.circle.badge.plus",
                                detail: "Set up in Settings") { model.openSettings(.calendar) }
            }
        }
    }

    private var accessibilityRow: some View {
        IslandActionRow("Allow Accessibility", symbol: "exclamationmark.triangle.fill", detail: "In System Settings") {
            MediaKeyInterceptor.requestPermission()
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @ViewBuilder private func companionRow(_ companion: CompanionApps.Companion) -> some View {
        let companions = model.companions
        if !companion.isSupported {
            IslandActionRow("Run \(companion.name)", symbol: "xmark", detail: "Needs macOS \(companion.minimumMacOS)") {}
                .disabled(true)
        } else if !companions.isAvailable(companion) {
            IslandActionRow("Run \(companion.name)", symbol: "xmark", detail: "Not included in this build") {}
                .disabled(true)
        } else {
            IslandToggleRow("Run \(companion.name)", detail: "Comes with the island", isOn: Binding(
                get: { companions.isEnabled(companion) },
                set: { companions.setEnabled(companion, $0) }
            ))
        }
    }
}

// MARK: - Row styles

/// The island's row: a title with an optional line under it and a control on the right,
/// the same size and type as the rows in the System tab.
private struct IslandRow<Trailing: View>: View {
    let title: String
    var detail: String?
    let trailing: Trailing
    @Environment(\.isEnabled) private var isEnabled

    init(title: String, detail: String? = nil, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.detail = detail
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.4))
                if let detail {
                    Text(detail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, 6)
        .frame(height: IslandLayout.systemRowHeight)
    }
}

private struct IslandToggleRow: View {
    let title: String
    var detail: String?
    @Binding var isOn: Bool

    init(_ title: String, detail: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.detail = detail
        _isOn = isOn
    }

    var body: some View {
        IslandRow(title: title, detail: detail) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
    }
}

/// A tappable row with a round icon, or a small capsule button when it has a title.
private struct IslandActionRow: View {
    let title: String
    let symbol: String
    var detail: String?
    var buttonTitle: String?
    var isDestructive = false
    let action: () -> Void
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    init(_ title: String, symbol: String, detail: String? = nil, buttonTitle: String? = nil,
         isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.detail = detail
        self.buttonTitle = buttonTitle
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        if let buttonTitle {
            IslandRow(title: title, detail: detail) {
                Button(buttonTitle, action: action).buttonStyle(CapsuleButtonStyle())
            }
        } else {
            Button(action: action) {
                IslandRow(title: title, detail: detail) {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isDestructive ? Color.red : .white.opacity(isEnabled ? 0.75 : 0.3))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.white.opacity(isHovering && isEnabled ? 0.16 : 0.08)))
                }
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.white.opacity(isHovering && isEnabled ? 0.06 : 0)))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
        }
    }
}

/// Steps through a few values with − and +, so no menu has to open over the island.
private struct IslandValueRow: View {
    let title: String
    let label: String
    var detail: String?
    @Binding var value: Int
    let options: [Int]

    init(_ title: String, showing label: String, detail: String? = nil, value: Binding<Int>, in options: [Int]) {
        self.title = title
        self.label = label
        self.detail = detail
        _value = value
        self.options = options
    }

    var body: some View {
        let index = options.firstIndex(of: value) ?? options.lastIndex(where: { $0 < value }) ?? 0
        IslandRow(title: title, detail: detail) {
            HStack(spacing: 2) {
                Button { value = options[max(index - 1, 0)] } label: {
                    Image(systemName: "minus").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(IslandButtonStyle(diameter: 22))
                .disabled(index == 0 && options.first == value)
                Text(label)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.75))
                    .contentTransition(.numericText())
                    .frame(minWidth: 74)
                Button { value = options[min(index + 1, options.count - 1)] } label: {
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(IslandButtonStyle(diameter: 22))
                .disabled(index == options.count - 1 && options.last == value)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
        }
    }
}
