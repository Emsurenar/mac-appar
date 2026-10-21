import Charts
import SwiftUI

enum SettingsTab: Int, CaseIterable {
    case general, buddies, exercises, schedule, activity, about

    var title: String {
        switch self {
        case .general: return L("General")
        case .buddies: return L("Stretch Crew")
        case .exercises: return L("Exercises")
        case .schedule: return L("Schedule")
        case .activity: return L("Activity")
        case .about: return L("About")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .buddies: return "pawprint"
        case .exercises: return "figure.cooldown"
        case .schedule: return "calendar.badge.clock"
        case .activity: return "chart.bar.xaxis"
        case .about: return "info.circle"
        }
    }

    /// Each tab gets a window height that fits its content.
    var contentSize: NSSize {
        switch self {
        case .general: return NSSize(width: 580, height: 695)
        case .buddies: return NSSize(width: 580, height: 408)
        case .exercises: return NSSize(width: 580, height: 640)
        case .schedule: return NSSize(width: 580, height: 500)
        case .activity: return NSSize(width: 580, height: 440)
        case .about: return NSSize(width: 580, height: 440)
        }
    }

    @MainActor
    func makeView(onTestBreak: @escaping () -> Void) -> AnyView {
        AnyView(content(onTestBreak: onTestBreak).environment(\.locale, Localizer.locale))
    }

    @MainActor
    private func content(onTestBreak: @escaping () -> Void) -> AnyView {
        switch self {
        case .general: return AnyView(GeneralSettingsView(onTestBreak: onTestBreak))
        case .buddies: return AnyView(BuddiesSettingsView())
        case .exercises: return AnyView(ExercisesSettingsView())
        case .schedule: return AnyView(ScheduleSettingsView())
        case .activity: return AnyView(ActivitySettingsView())
        case .about: return AnyView(AboutSettingsView())
        }
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    var onTestBreak: () -> Void

    var body: some View {
        Form {
            Section(L("Breaks")) {
                Picker(L("Remind me every"), selection: $prefs.intervalMinutes) {
                    ForEach(Preferences.intervalOptions, id: \.self) { Text(L("%ld minutes", $0)).tag($0) }
                }
                Picker(L("Break length"), selection: $prefs.breakSeconds) {
                    ForEach(Preferences.breakLengthOptions, id: \.self) { Text(L("%ld seconds", $0)).tag($0) }
                }
                Picker(L("Exercises per break"), selection: $prefs.exercisesPerBreak) {
                    ForEach(Preferences.exerciseCountOptions, id: \.self) { Text(verbatim: "\($0)").tag($0) }
                }
                Picker(L("Snooze for"), selection: $prefs.snoozeMinutes) {
                    ForEach(Preferences.snoozeOptions, id: \.self) { Text(L("%ld minutes", $0)).tag($0) }
                }
                LabeledContent(L("Try it out")) {
                    Button(L("Show a break now"), action: onTestBreak)
                }
            }

            Section(L("Appearance")) {
                Picker(L("Language"), selection: $prefs.language) {
                    ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
                }
                Picker(L("Position on screen"), selection: $prefs.position) {
                    ForEach(ReminderPosition.allCases) { Text($0.title).tag($0) }
                }
                Toggle(L("Show time until the next break in the menu bar"), isOn: $prefs.showCountdownInMenuBar)
            }

            Section(L("Sound")) {
                Toggle(L("Play a sound when a break starts"), isOn: $prefs.soundEnabled)
                Picker(L("Sound"), selection: $prefs.soundName) {
                    ForEach(Preferences.soundOptions, id: \.self) { Text(verbatim: $0).tag($0) }
                }
                .disabled(!prefs.soundEnabled)
                .onChange(of: prefs.soundName) { _, name in NSSound(named: name)?.play() }
            }

            Section(L("System")) {
                LoginItemRows()
                Toggle(L("Check for updates automatically"), isOn: $prefs.checkForUpdates)
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }
}

// MARK: - Buddies

struct BuddiesSettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        let enabledCount = Buddy.allCases.filter { prefs.isEnabled($0) }.count
        Form {
            Section {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(Buddy.allCases.enumerated()), id: \.element) { index, buddy in
                        BuddyCard(buddy: buddy,
                                  isOn: prefs.isEnabled(buddy),
                                  isLocked: enabledCount == 1 && prefs.isEnabled(buddy),
                                  stillTime: 0.5 + Double(index) * 0.37) {
                            prefs.setEnabled(buddy, !prefs.isEnabled(buddy))
                        }
                    }
                }
                .padding(.vertical, 6)
            } header: {
                Text(L("Choose who's on your Stretch Crew. With more than one, a random member leads each break."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
            } footer: {
                HStack {
                    Text(L("%ld of %ld selected", enabledCount, Buddy.allCases.count))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L("Select all")) { prefs.disabledBuddies = [] }
                        .disabled(prefs.disabledBuddies.isEmpty)
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
    }
}

struct BuddyCard: View {
    let buddy: Buddy
    let isOn: Bool
    let isLocked: Bool
    let stillTime: Double
    let toggle: () -> Void
    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let accent = Brand.accent(scheme == .dark)
        Button {
            if !isLocked { toggle() }
        } label: {
            VStack(spacing: 6) {
                BuddyView(move: .wave, buddy: buddy, fixedTime: hovering ? nil : stillTime)
                    .frame(width: 72, height: 72)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Pen.paper))
                    .paperTone(scheme)
                    .saturation(isOn ? 1 : 0)
                    .opacity(isOn ? 1 : 0.5)
                Text(buddy.name)
                    .font(.callout.weight(isOn ? .medium : .regular))
                    .foregroundStyle(isOn ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isOn ? accent.opacity(0.06) : Color.primary.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isOn ? accent.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: isOn ? 1.5 : 1))
            .overlay(alignment: .topTrailing) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(isOn ? accent : Color.secondary.opacity(0.5))
                    .padding(6)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(isLocked ? L("Your crew needs at least one member.") : "")
        .accessibilityLabel(buddy.name)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - Exercises

struct ExercisesSettingsView: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        let enabledCount = allExercises.filter { prefs.isEnabled($0) }.count
        let buddies = prefs.enabledBuddies
        Form {
            Section {
                ForEach(Array(allExercises.enumerated()), id: \.element.id) { index, exercise in
                    ExerciseRow(exercise: exercise,
                                buddy: buddies[index % buddies.count],
                                isOn: Binding(get: { prefs.isEnabled(exercise) },
                                              set: { prefs.setEnabled(exercise, $0) }),
                                isLocked: enabledCount == 1 && prefs.isEnabled(exercise))
                }
            } header: {
                Text(L("Choose which exercises Unknot can suggest. Hover over one to see the movement."))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 4)
            } footer: {
                HStack {
                    Text(L("%ld of %ld selected", enabledCount, allExercises.count))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L("Select all")) { prefs.disabledExercises = [] }
                        .disabled(prefs.disabledExercises.isEmpty)
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
    }
}

struct ExerciseRow: View {
    let exercise: Exercise
    let buddy: Buddy
    @Binding var isOn: Bool
    var isLocked: Bool
    @State private var hovering = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 12) {
            BuddyView(move: exercise.move, buddy: buddy, fixedTime: hovering ? nil : 1.2)
                .frame(width: 48, height: 48)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Pen.paper))
                .paperTone(scheme)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.title).fontWeight(.medium)
                Text(exercise.text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle(exercise.title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(isLocked)
                .help(isLocked ? L("At least one exercise has to stay on.") : "")
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }
}

// MARK: - Schedule

struct ScheduleSettingsView: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Form {
            Section {
                Toggle(L("Only remind me during working hours"), isOn: $prefs.workHoursEnabled)
                DatePicker(L("From"), selection: time(\.workStartMinutes), displayedComponents: .hourAndMinute)
                    .disabled(!prefs.workHoursEnabled)
                DatePicker(L("Until"), selection: time(\.workEndMinutes), displayedComponents: .hourAndMinute)
                    .disabled(!prefs.workHoursEnabled)
                Toggle(L("Weekdays only"), isOn: $prefs.weekdaysOnly)
                    .disabled(!prefs.workHoursEnabled)
            } header: {
                Text(L("Working hours"))
            }

            Section {
                Toggle(L("Count time away from the computer as a break"), isOn: $prefs.countAwayAsBreak)
                Picker(L("Away for at least"), selection: $prefs.awayMinutes) {
                    ForEach(Preferences.awayOptions, id: \.self) { Text(L("%ld minutes", $0)).tag($0) }
                }
                .disabled(!prefs.countAwayAsBreak)
                Toggle(L("Wait until calls end"), isOn: $prefs.waitDuringCalls)
                Toggle(L("Wait while an app is in full screen"), isOn: $prefs.waitForFullscreen)
            } header: {
                Text(L("Smart pauses"))
            } footer: {
                Text(L("A call is when another app uses the microphone or camera. Unknot only checks whether they're on, never what they hear or see. Full screen usually means a presentation or a movie."))
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
    }

    private func time(_ keyPath: ReferenceWritableKeyPath<Preferences, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = prefs[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                prefs[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }
}

// MARK: - Activity

struct ActivitySettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @Environment(\.colorScheme) private var scheme
    @State private var confirmingReset = false

    var body: some View {
        let week = prefs.recentDays(7)
        let streak = prefs.streak()
        Form {
            Section {
                HStack(spacing: 0) {
                    stat(L("Today"), "\(prefs.breaksToday)")
                    Divider().frame(height: 36)
                    stat(L("This week"), "\(week.reduce(0) { $0 + $1.count })")
                    Divider().frame(height: 36)
                    stat(L("Streak"), streak == 1 ? L("1 day") : L("%ld days", streak))
                    Divider().frame(height: 36)
                    stat(L("All time"), "\(prefs.breaksTotal)")
                }
                .padding(.vertical, 6)
            }

            Section(L("Last 7 days")) {
                Chart(week) { day in
                    BarMark(x: .value(L("Day"), day.date, unit: .day),
                            y: .value(L("Breaks"), day.count))
                        .foregroundStyle(Brand.accent(scheme == .dark).gradient)
                        .cornerRadius(5)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3))
                }
                .chartYScale(domain: 0...max(4, week.map(\.count).max() ?? 0))
                .frame(height: 170)
                .padding(.vertical, 8)
                .overlay {
                    if week.allSatisfy({ $0.count == 0 }) {
                        Text(L("Your stretch breaks will show up here."))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(.background, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Section {
                HStack {
                    Text(L("Statistics stay on this Mac."))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(L("Reset…")) { confirmingReset = true }
                        .disabled(prefs.breaksTotal == 0)
                }
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(L("Reset your statistics?"), isPresented: $confirmingReset) {
            Button(L("Reset"), role: .destructive) { prefs.resetStatistics() }
        } message: {
            Text(L("This removes your history and streak. It can't be undone."))
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - About

struct AboutSettingsView: View {
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 112, height: 112)
            Text(verbatim: "Unknot")
                .font(.system(size: 26, weight: .bold))
                .tracking(-0.4)
                .padding(.top, 6)
            Text(L("Version %@", Updater.currentVersion))
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            Text(L("A tiny friend that reminds you to stretch."))
                .padding(.top, 12)

            HStack(spacing: 10) {
                switch updater.status {
                case .available(let version):
                    Text(L("Version %@ is available.", version))
                    Button(L("Install and Restart")) { updater.install() }
                        .buttonStyle(.borderedProminent)
                case .installing(let version):
                    ProgressView().controlSize(.small)
                    Text(L("Installing version %@…", version))
                        .foregroundStyle(.secondary)
                case .installFailed(let message):
                    Text(message)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Button(L("Try Again")) { updater.install() }
                    Button(L("Download")) { updater.openReleasePage() }
                default:
                    Button(L("Check for updates")) { updater.check() }
                        .disabled(updater.status == .checking)
                    if updater.status == .checking {
                        ProgressView().controlSize(.small)
                    } else if updater.status == .upToDate {
                        Label(L("You're up to date"), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    } else if updater.status == .failed {
                        Text(L("Couldn't reach GitHub."))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(minHeight: 28)
            .padding(.top, 20)

            Spacer()

            HStack(spacing: 18) {
                Link(L("GitHub"), destination: Updater.repositoryURL)
                Link(L("Release notes"), destination: Updater.releasesURL)
                Link(L("Report a problem"), destination: Updater.issuesURL)
            }
            .font(.callout)
            Text(L("Free and open source under the MIT license."))
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Open at login

@MainActor
final class LoginItemModel: ObservableObject {
    @Published private(set) var isEnabled = LoginItem.isEnabled
    @Published private(set) var needsApproval = LoginItem.needsApproval
    @Published private(set) var error: String?

    func set(_ on: Bool) {
        do {
            try LoginItem.setEnabled(on)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        refresh()
    }

    func refresh() {
        isEnabled = LoginItem.isEnabled
        needsApproval = LoginItem.needsApproval
    }
}

/// "Open at login" toggle plus the follow-up macOS sometimes asks for.
struct LoginItemRows: View {
    @StateObject private var model = LoginItemModel()

    var body: some View {
        Toggle(L("Open at login"), isOn: Binding(get: { model.isEnabled }, set: { model.set($0) }))
            .toggleStyle(.switch)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                model.refresh()
            }
        if model.needsApproval {
            LabeledContent {
                Button(L("Open System Settings")) { LoginItem.openSystemSettings() }
            } label: {
                Text(L("Approve Unknot in System Settings to finish."))
                    .foregroundStyle(.secondary)
            }
        }
        if let error = model.error {
            Text(error).foregroundStyle(.red).font(.callout)
        }
    }
}
