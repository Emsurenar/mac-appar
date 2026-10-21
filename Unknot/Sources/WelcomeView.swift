import SwiftUI

/// Shown on first launch, so people know where the app went and can pick the basics.
struct WelcomeView: View {
    @ObservedObject private var prefs = Preferences.shared
    @StateObject private var login = LoginItemModel()
    var onTryBreak: () -> Void
    var onDone: () -> Void

    @State private var moveError: String?
    private let inApplications = AppMover.isInApplicationsFolder

    var body: some View {
        VStack(spacing: 0) {
            BuddyView(move: .wave)
                .frame(width: 150, height: 150)
                .padding(.top, 34)

            Text(L("Hi, I'm Sträckis!"))
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.4)
                .padding(.top, 6)

            Text(L("I live in your menu bar and remind you to get up and stretch. Each break takes about %ld seconds.", prefs.breakSeconds))
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 350)
                .padding(.top, 8)

            VStack(spacing: 0) {
                row {
                    Text(L("Remind me every"))
                    Spacer()
                    Picker(L("Remind me every"), selection: $prefs.intervalMinutes) {
                        ForEach(Preferences.intervalOptions, id: \.self) { Text(L("%ld minutes", $0)).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Divider().padding(.leading, 14)
                row {
                    Text(L("Open at login"))
                    Spacer()
                    Toggle(L("Open at login"), isOn: Binding(get: { login.isEnabled }, set: { login.set($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                if !inApplications {
                    Divider().padding(.leading, 14)
                    row {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("Move to the Applications folder"))
                            Text(moveError ?? L("Recommended, so Sträckis can open at login."))
                                .font(.callout)
                                .foregroundStyle(moveError == nil ? Color.secondary : Color.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Button(L("Move")) {
                            do {
                                try AppMover.moveToApplicationsAndRelaunch()
                            } catch {
                                moveError = error.localizedDescription
                            }
                        }
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.08)))
            .padding(.horizontal, 28)
            .padding(.top, 22)

            if login.needsApproval {
                Button(L("Approve Sträckis in System Settings to finish.")) { LoginItem.openSystemSettings() }
                    .buttonStyle(.link)
                    .font(.callout)
                    .padding(.top, 8)
            }

            Label(L("You'll find me in the menu bar. If the icon is hidden, just open Sträckis again to get to the settings."), systemImage: "menubar.arrow.up.rectangle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)
                .padding(.top, 16)

            HStack {
                Button(L("Try a break"), action: onTryBreak)
                Spacer()
                Button(L("Get started"), action: onDone)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.horizontal, 28)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
        .frame(width: 470)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            login.refresh()
        }
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 12, content: content)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .padding(.vertical, 4)
    }
}
