import AppKit

enum ReminderPosition: String, CaseIterable, Identifiable {
    case bottomRight, topRight, bottomLeft, topLeft

    var id: String { rawValue }
    var isTop: Bool { self == .topRight || self == .topLeft }
    var isLeft: Bool { self == .bottomLeft || self == .topLeft }

    var title: String {
        switch self {
        case .bottomRight: return L("Bottom right")
        case .topRight: return L("Top right")
        case .bottomLeft: return L("Bottom left")
        case .topLeft: return L("Top left")
        }
    }
}

/// All user settings, persisted in UserDefaults.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    static let intervalOptions = [10, 15, 20, 25, 30, 45, 60, 90]
    static let breakLengthOptions = [15, 30, 45, 60]
    static let exerciseCountOptions = [1, 2, 3, 4]
    static let awayOptions = [2, 5, 10, 15]
    static let soundOptions = ["Purr", "Pop", "Tink", "Glass", "Bottle", "Hero", "Submarine", "Blow", "Ping", "Morse", "Frog", "Funk"]

    private enum Key {
        static let interval = "intervalMinutes"
        static let breakLength = "breakSeconds"
        static let exerciseCount = "exercisesPerBreak"
        static let soundEnabled = "soundEnabled"
        static let soundName = "soundName"
        static let position = "position"
        static let showCountdown = "showCountdownInMenuBar"
        static let disabledExercises = "disabledExercises"
        static let countAway = "countAwayAsBreak"
        static let awayMinutes = "awayMinutes"
        static let workHours = "workHoursEnabled"
        static let workStart = "workStartMinutes"
        static let workEnd = "workEndMinutes"
        static let weekdaysOnly = "weekdaysOnly"
        static let waitForFullscreen = "waitForFullscreen"
        static let checkForUpdates = "checkForUpdates"
        static let onboarded = "hasCompletedOnboarding"
        static let statsDay = "statsDay"
        static let breaksToday = "breaksToday"
        static let breaksTotal = "breaksTotal"
    }

    private let d: UserDefaults

    @Published var intervalMinutes: Int { didSet { d.set(intervalMinutes, forKey: Key.interval) } }
    @Published var breakSeconds: Int { didSet { d.set(breakSeconds, forKey: Key.breakLength) } }
    @Published var exercisesPerBreak: Int { didSet { d.set(exercisesPerBreak, forKey: Key.exerciseCount) } }
    @Published var soundEnabled: Bool { didSet { d.set(soundEnabled, forKey: Key.soundEnabled) } }
    @Published var soundName: String { didSet { d.set(soundName, forKey: Key.soundName) } }
    @Published var position: ReminderPosition { didSet { d.set(position.rawValue, forKey: Key.position) } }
    @Published var showCountdownInMenuBar: Bool { didSet { d.set(showCountdownInMenuBar, forKey: Key.showCountdown) } }
    @Published var disabledExercises: Set<String> { didSet { d.set(Array(disabledExercises).sorted(), forKey: Key.disabledExercises) } }
    @Published var countAwayAsBreak: Bool { didSet { d.set(countAwayAsBreak, forKey: Key.countAway) } }
    @Published var awayMinutes: Int { didSet { d.set(awayMinutes, forKey: Key.awayMinutes) } }
    @Published var workHoursEnabled: Bool { didSet { d.set(workHoursEnabled, forKey: Key.workHours) } }
    @Published var workStartMinutes: Int { didSet { d.set(workStartMinutes, forKey: Key.workStart) } }
    @Published var workEndMinutes: Int { didSet { d.set(workEndMinutes, forKey: Key.workEnd) } }
    @Published var weekdaysOnly: Bool { didSet { d.set(weekdaysOnly, forKey: Key.weekdaysOnly) } }
    @Published var waitForFullscreen: Bool { didSet { d.set(waitForFullscreen, forKey: Key.waitForFullscreen) } }
    @Published var checkForUpdates: Bool { didSet { d.set(checkForUpdates, forKey: Key.checkForUpdates) } }
    @Published var hasCompletedOnboarding: Bool { didSet { d.set(hasCompletedOnboarding, forKey: Key.onboarded) } }
    @Published private(set) var breaksToday: Int { didSet { d.set(breaksToday, forKey: Key.breaksToday) } }
    @Published private(set) var breaksTotal: Int { didSet { d.set(breaksTotal, forKey: Key.breaksTotal) } }
    private var statsDay: String { didSet { d.set(statsDay, forKey: Key.statsDay) } }

    init(defaults: UserDefaults = .standard) {
        d = defaults
        d.register(defaults: [
            Key.interval: 20,
            Key.breakLength: 30,
            Key.exerciseCount: 3,
            Key.soundEnabled: true,
            Key.soundName: "Purr",
            Key.position: ReminderPosition.bottomRight.rawValue,
            Key.showCountdown: false,
            Key.countAway: true,
            Key.awayMinutes: 5,
            Key.workHours: false,
            Key.workStart: 8 * 60,
            Key.workEnd: 17 * 60,
            Key.weekdaysOnly: true,
            Key.waitForFullscreen: false,
            Key.checkForUpdates: true,
        ])
        intervalMinutes = d.integer(forKey: Key.interval)
        breakSeconds = d.integer(forKey: Key.breakLength)
        exercisesPerBreak = d.integer(forKey: Key.exerciseCount)
        soundEnabled = d.bool(forKey: Key.soundEnabled)
        soundName = d.string(forKey: Key.soundName) ?? "Purr"
        position = ReminderPosition(rawValue: d.string(forKey: Key.position) ?? "") ?? .bottomRight
        showCountdownInMenuBar = d.bool(forKey: Key.showCountdown)
        disabledExercises = Set(d.stringArray(forKey: Key.disabledExercises) ?? [])
        countAwayAsBreak = d.bool(forKey: Key.countAway)
        awayMinutes = d.integer(forKey: Key.awayMinutes)
        workHoursEnabled = d.bool(forKey: Key.workHours)
        workStartMinutes = d.integer(forKey: Key.workStart)
        workEndMinutes = d.integer(forKey: Key.workEnd)
        weekdaysOnly = d.bool(forKey: Key.weekdaysOnly)
        waitForFullscreen = d.bool(forKey: Key.waitForFullscreen)
        checkForUpdates = d.bool(forKey: Key.checkForUpdates)
        hasCompletedOnboarding = d.bool(forKey: Key.onboarded)
        breaksToday = d.integer(forKey: Key.breaksToday)
        breaksTotal = d.integer(forKey: Key.breaksTotal)
        statsDay = d.string(forKey: Key.statsDay) ?? ""
        refreshDay()
    }

    // MARK: Exercises

    var enabledExercises: [Exercise] {
        let enabled = allExercises.filter { !disabledExercises.contains($0.id) }
        return enabled.isEmpty ? allExercises : enabled
    }

    func isEnabled(_ exercise: Exercise) -> Bool { !disabledExercises.contains(exercise.id) }

    /// Turns an exercise on or off, but always keeps at least one enabled.
    func setEnabled(_ exercise: Exercise, _ on: Bool) {
        if on {
            disabledExercises.remove(exercise.id)
        } else if enabledExercises.count > 1 {
            disabledExercises.insert(exercise.id)
        }
    }

    // MARK: Statistics

    func recordCompletedBreak() {
        refreshDay()
        breaksToday += 1
        breaksTotal += 1
    }

    /// Resets today's counter when the date changes.
    func refreshDay() {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let today = "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
        if statsDay != today {
            statsDay = today
            breaksToday = 0
        }
    }

    func resetStatistics() {
        breaksToday = 0
        breaksTotal = 0
    }
}

/// Helpers for the optional working-hours window. Times are minutes after midnight.
enum WorkHours {
    static func contains(_ date: Date, start: Int, end: Int, weekdaysOnly: Bool, calendar: Calendar = .current) -> Bool {
        if weekdaysOnly && calendar.isDateInWeekend(date) { return false }
        if start == end { return true }
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return start < end ? (minute >= start && minute < end) : (minute >= start || minute < end)
    }

    /// The next time working hours begin after `date`.
    static func nextStart(after date: Date, start: Int, weekdaysOnly: Bool, calendar: Calendar = .current) -> Date? {
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)),
                  let candidate = calendar.date(byAdding: .minute, value: start, to: day) else { continue }
            if candidate > date && !(weekdaysOnly && calendar.isDateInWeekend(candidate)) { return candidate }
        }
        return nil
    }
}
