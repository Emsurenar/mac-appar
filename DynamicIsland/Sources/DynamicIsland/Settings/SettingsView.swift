import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @Environment(IslandModel.self) private var model
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var hasAccessibility = MediaKeyInterceptor.hasPermission

    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                Toggle("Starta vid inloggning", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                Toggle("Öppna när pekaren vilar på notchen", isOn: $settings.hoverToOpen)
                Toggle("Haptisk återkoppling", isOn: $settings.hapticFeedback)
            } header: {
                Text("Allmänt")
            } footer: {
                Text(settings.hoverToOpen
                     ? "Haptiken känns när pekaren når notchen och när ett reglage dras till ändläget – bara med fingret på styrplattan."
                     : "Klicka på notchen för att öppna ön. Haptiken känns när ett reglage dras till ändläget.")
                    .foregroundStyle(.secondary)
            }

            Section("Live-aktiviteter") {
                Toggle("Visa musik som spelas", isOn: $settings.showLiveActivity)
                Toggle("Visa låtbyten", isOn: $settings.showTrackChanges)
                Toggle("Visa byte av ljudutgång", isOn: $settings.showDeviceChanges)
            }

            Section {
                Toggle("Visa Hem-fliken", isOn: $settings.showHomeTab)
                TextField("Mapp i Genvägar", text: $settings.homeFolderName)
                    .onSubmit { model.home.refresh() }
                    .disabled(!settings.showHomeTab)
                HStack {
                    Text(homeStatus).foregroundStyle(.secondary)
                    Spacer()
                    Button("Öppna Genvägar") { HomeService.openShortcutsApp() }
                }
            } header: {
                Text("Hem")
            } footer: {
                Text("Skapa genvägar med åtgärden Styr hem (t.ex. tänd lampor eller aktivera en scen) och lägg dem i mappen. Börjar namnet med en emoji blir den ikonen. Returnerar genvägen ”på” eller ”av” visas brickan som tänd eller släckt.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Visa Hållning-fliken", isOn: $settings.showPostureTab)
                Toggle("Visa påminnelser om hållning", isOn: $settings.showPostureAlerts)
                Toggle("Visa live-aktivitet vid dålig hållning", isOn: $settings.showPostureLiveActivity)
                HStack {
                    Label(model.posture.isConnected ? "Hållning är igång" : "Hållning är inte igång",
                          systemImage: model.posture.isConnected ? "checkmark.circle.fill" : "circle.dashed")
                        .foregroundStyle(model.posture.isConnected ? Color.green : Color.secondary)
                    Spacer()
                    Button("Öppna Hållning") { model.posture.openApp() }
                }
            } header: {
                Text("Hållning")
            } footer: {
                Text("Hållning är en separat app som håller koll på hur du sitter. När den är igång visas påminnelser och status här i ön.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Visa volymändringar i ön", isOn: $settings.showVolumeHUD)
                Toggle("Ersätt systemets volym- och ljusstyrkeruta", isOn: $settings.replaceSystemHUD)
                if settings.replaceSystemHUD && !hasAccessibility {
                    HStack {
                        Label("Kräver behörighet för Hjälpmedel", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Öppna Inställningar…") { openAccessibilitySettings() }
                    }
                }
            } header: {
                Text("Volym och ljusstyrka")
            } footer: {
                Text("Volym- och ljusstyrketangenterna visas då bara i ön. Håll ned ⌥⇧ för finare steg.")
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dynamic Island")
                        Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Avsluta") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(permissionTimer) { _ in
            hasAccessibility = MediaKeyInterceptor.hasPermission
        }
        .onAppear { model.home.refresh() }
    }

    private var homeStatus: String {
        let home = model.home
        if !home.folderExists { return "Mappen finns inte än" }
        return home.shortcuts.count == 1 ? "1 genväg" : "\(home.shortcuts.count) genvägar"
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
            let hosting = NSHostingController(rootView: SettingsView().environment(model))
            hosting.sizingOptions = .preferredContentSize
            let window = NSWindow(contentViewController: hosting)
            window.title = "Dynamic Island"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}
