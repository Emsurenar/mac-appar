import AppKit
import ServiceManagement
import SwiftUI

/// Settings laid out like a Home app sheet: a rounded card with grouped,
/// white rows on a soft gray background, scrolling when it doesn't fit.
struct SettingsView: View {
    @Environment(IslandModel.self) private var model
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
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
            .onAppear { model.home.refresh() }
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

    private var homeStatus: String {
        let count = model.home.shortcuts.count
        return count == 1 ? "1 in the island" : "\(count) in the island"
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    private func openAccessibilitySettings() {
        MediaKeyInterceptor.requestPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Grouped rows

private struct SettingsSection<Content: View>: View {
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
private struct SettingsRow<Content: View>: View {
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

private struct SettingsToggle: View {
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

private struct Chevron: View {
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
