import Charts
import SwiftUI

enum SettingsTab: Int, CaseIterable {
    case general, exercises, schedule, activity, about

    var title: String {
        switch self {
        case .general: return L("General")
        case .exercises: return L("Exercises")
        case .schedule: return L("Schedule")
        case .activity: return L("Activity")
        case .about: return L("About")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape"
        case .exercises: return "figure.cooldown"
        case .schedule: return "calendar.badge.clock"
        case .activity: return "chart.bar.xaxis"
        case .about: return "info.circle"
        }
    }

    /// Each tab gets a window height that fits its content.
    var contentSize: NSSize {
        switch self {
        case .general: return NSSize(width: 580, height: 655)
        case .exercises: return NSSize(width: 580, height: 640)
        case .schedule: return NSSize(width: 580, height: 450)
        case .activity: return NSSize(width: 580, height: 440)
        case .about: return NSSize(width: 580, height: 440)
        }
    }

    @MainActor
    func makeView(onTestBreak: @escaping () -> Void) -> AnyView {
        switch self {
        case .general: return AnyView(GeneralSettingsView(onTestBreak: onTestBreak))
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
                .onChange(of: prefs.soundName) { name in NSSound(named: name)?.play() }
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

// MARK: - Exercises

struct ExercisesSettingsView: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        let enabledCount = allExercises.filter { prefs.isEnabled($0) }.count
        Form {
            Section {
                ForEach(allExercises) { exercise in
                    ExerciseRow(exercise: exercise,
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
    @Binding var isOn: Bool
    var isLocked: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            BuddyView(move: exercise.move, fixedTime: hovering ? nil : 1.2)
                .frame(width: 46, height: 46)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
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
                Toggle(L("Wait while an app is in full screen"), isOn: $prefs.waitForFullscreen)
            } header: {
                Text(L("Smart pauses"))
            } footer: {
                Text(L("Full screen usually means a presentation, a video call or a movie. Unknot waits until you're done."))
                    .foregroundStyle(.secondary)
                    .font(.callout)
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
                    Button(L("Download")) { updater.openReleasePage() }
                        .buttonStyle(.borderedProminent)
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
            .frame(height: 28)
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
