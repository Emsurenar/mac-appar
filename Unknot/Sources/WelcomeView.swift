import SwiftUI

/// Shown on first launch, so people know where the app went and can pick the basics.
struct WelcomeView: View {
    @ObservedObject private var prefs = Preferences.shared
    @StateObject private var login = LoginItemModel()
    var onTryBreak: () -> Void
    var onDone: () -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var moveError: String?
    @State private var buddy = Preferences.shared.randomBuddy()
    private let inApplications = AppMover.isInApplicationsFolder

    var body: some View {
        VStack(spacing: 0) {
            island

            Text(L("Welcome to Unknot"))
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.4)
                .padding(.top, 22)

            Text(L("Every %ld minutes, a member of the Stretch Crew drops down from the top of your screen with a few quick stretches. Each break takes about %ld seconds.", prefs.intervalMinutes, prefs.breakSeconds))
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 390)
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
                            Text(moveError ?? L("Recommended, so Unknot can open at login."))
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
                Button(L("Approve Unknot in System Settings to finish.")) { LoginItem.openSystemSettings() }
                    .buttonStyle(.link)
                    .font(.callout)
                    .padding(.top, 8)
            }

            Label {
                Text(L("Unknot lives in the menu bar, as a small frog. If you can't see it, open Unknot again to get to the settings."))
            } icon: {
                Image(nsImage: MenuBarIcon.image(.awake)).renderingMode(.template)
            }
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 28)
                .padding(.top, 16)

            HStack {
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
        .tint(.orange)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            login.refresh()
        }
    }

    /// A break in miniature, hanging from the top of the window the way the real one hangs from the notch: a
    /// member of the crew waving on its paper tile, and a button that shows a real break.
    private var island: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Pen.paper)
                .overlay(BuddyView(move: .wave, buddy: buddy, epoch: Date()).padding(3))
                .colorMultiply(Color(hex: 0xF1ECE3))
                .frame(width: 78, height: 78)
                .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text(L("Stretch Crew").uppercased(with: Localizer.locale))
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Island.accent)
                Text(buddy.introduction)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                Button(L("Show me a break"), action: onTryBreak)
                    .buttonStyle(IslandCapsuleStyle(prominent: true))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 78)
        }
        .padding(.horizontal, 12 + 16)
        .padding(.top, 34)
        .padding(.bottom, 18)
        .frame(width: 356)
        .background(IslandShape(ear: 12, bottom: 28).fill(Color.black))
        .environment(\.colorScheme, .dark)
    }

    private func row<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 12, content: content)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .padding(.vertical, 4)
    }
}
