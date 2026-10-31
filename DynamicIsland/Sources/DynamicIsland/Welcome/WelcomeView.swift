import AppKit
import SwiftUI

/// Shown on first launch: where the island lives, how to open it, and the few
/// things that need a decision or a permission. Everything here is also in Settings.
struct WelcomeView: View {
    @Environment(IslandModel.self) private var model
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var hasAccessibility = MediaKeyInterceptor.hasPermission
    @State private var moveError: String?
    private let inApplications = AppMover.isInApplicationsFolder
    private let permissionTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    /// Closes the welcome; true opens the island for a moment to show where it is.
    var onDone: (_ showIsland: Bool) -> Void

    var body: some View {
        let settings = Bindable(model.settings)
        return VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    hero

                    if !inApplications {
                        SettingsSection("Install", footer: moveError ?? "Keeps the app where macOS expects it, so it can launch at login and keep its permissions.") {
                            SettingsRow(action: moveToApplications) {
                                Image(systemName: "folder.fill").foregroundStyle(.blue)
                                Text("Move to Applications")
                                Spacer()
                                Chevron()
                            }
                        }
                    }

                    SettingsSection("Basics") {
                        SettingsToggle("Launch at login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { _, enabled in
                                let isEnabled = LoginItem.set(enabled)
                                if isEnabled != launchAtLogin { launchAtLogin = isEnabled }
                            }
                        SettingsToggle("Open when the pointer rests on the notch", isOn: settings.hoverToOpen)
                    }

                    SettingsSection("Optional", footer: "Replacing the volume and brightness overlay needs Accessibility, so the island can see those keys. Nothing else is read.") {
                        SettingsRow(action: askForCalendar) {
                            Image(systemName: "calendar").foregroundStyle(.red)
                            Text("Show upcoming events")
                            Spacer()
                            status(model.calendar.access == .signedIn,
                                   pending: model.calendar.hasClientID ? "Sign in with Google" : "Set Up in Settings")
                        }
                        SettingsToggle("Show volume and brightness in the notch", isOn: settings.replaceSystemHUD)
                        if model.settings.replaceSystemHUD {
                            SettingsRow(action: askForAccessibility) {
                                Image(systemName: "accessibility").foregroundStyle(.blue)
                                Text("Accessibility")
                                Spacer()
                                status(hasAccessibility, pending: "Allow")
                            }
                        }
                        SettingsRow(action: chooseShortcuts) {
                            Image(systemName: "house.fill").foregroundStyle(.orange)
                            Text("Add Home scenes from Shortcuts")
                            Spacer()
                            Chevron()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }

            Divider()
            HStack {
                Text("You can change all of this later in Settings.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Show me the island") { onDone(true) }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(.orange)
        .frame(width: 520, height: 600)
        .onReceive(permissionTimer) { _ in
            hasAccessibility = MediaKeyInterceptor.hasPermission
        }
    }

    private var askForCalendar: (() -> Void)? {
        let calendar = model.calendar
        guard calendar.access == .signedOut else { return nil }
        return calendar.hasClientID ? { calendar.signIn() } : { model.onOpenSettings?() }
    }

    private var askForAccessibility: (() -> Void)? {
        guard !hasAccessibility else { return nil }
        return { MediaKeyInterceptor.requestPermission() }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            MiniIsland()
                .padding(.top, 8)
            Text("Welcome to Dynamic Island")
                .font(.system(size: 24, weight: .bold))
            Text(model.metrics.hasNotch
                 ? "It lives in your MacBook’s notch. Rest the pointer on the notch to open it, and move away to close it. Right-click it for Settings."
                 : "It lives at the top center of your screen, where a MacBook’s notch would be. Rest the pointer there to open it. Right-click it for Settings.")
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    @ViewBuilder
    private func status(_ done: Bool, pending: String) -> some View {
        if done {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else {
            Text(pending).foregroundStyle(.secondary)
            Chevron()
        }
    }

    private func moveToApplications() {
        do {
            try AppMover.moveToApplicationsAndRelaunch()
        } catch {
            moveError = "Couldn’t move the app: \(error.localizedDescription) Drag it to Applications in Finder instead."
        }
    }

    private func chooseShortcuts() {
        onDone(false)
        model.select(.home)
        model.open()
        model.setChoosingShortcuts(true)
    }
}

/// A small island with a song playing, so people know what to look for.
private struct MiniIsland: View {
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.6))
                .frame(width: 300, height: 12)
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(LinearGradient(colors: [.orange, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 18, height: 18)
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 18)
            .frame(width: 200, height: 30)
            .background(NotchShape(topRadius: 8, bottomRadius: 13).fill(.black))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Window

@MainActor
final class WelcomeWindowController {
    private let model: IslandModel
    private var window: NSWindow?

    init(model: IslandModel) {
        self.model = model
    }

    func show() {
        // Closing the window any way counts, so it never comes back on its own.
        model.settings.hasSeenWelcome = true
        model.close()
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
                                  styleMask: [.titled, .closable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.contentView = NSHostingView(rootView: WelcomeView(onDone: { [weak self] showIsland in self?.finish(showIsland: showIsland) })
                .environment(model))
            window.title = "Welcome to Dynamic Island"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    /// Closes the window and can open the island for a moment, so people see where it is.
    private func finish(showIsland: Bool) {
        window?.close()
        guard showIsland, !model.isOpen else { return }
        model.open()
        Task { [model] in
            try? await Task.sleep(for: .seconds(2.5))
            if !model.isHovering { model.close() }
        }
    }
}
