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
    static let shared: Preferences = CommandLine.arguments.contains("--settings-screenshots") ? .sample() : Preferences()

    static let intervalOptions = [10, 15, 20, 25, 30, 45, 60, 90]
    static let breakLengthOptions = [15, 30, 45, 60]
    static let exerciseCountOptions = [1, 2, 3, 4]
    static let awayOptions = [2, 5, 10, 15]
    static let snoozeOptions = [5, 10, 15]
    static let soundOptions = ["Purr", "Pop", "Tink", "Glass", "Bottle", "Hero", "Submarine", "Blow", "Ping", "Morse", "Frog", "Funk"]

    private enum Key {
        static let interval = "intervalMinutes"
        static let snooze = "snoozeMinutes"
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
        static let history = "breakHistory"
        static let breaksTotal = "breaksTotal"
        // Used by 1.0.0, migrated into `history`
        static let legacyStatsDay = "statsDay"
        static let legacyBreaksToday = "breaksToday"
    }

    private let d: UserDefaults

    @Published var intervalMinutes: Int { didSet { d.set(intervalMinutes, forKey: Key.interval) } }
    @Published var snoozeMinutes: Int { didSet { d.set(snoozeMinutes, forKey: Key.snooze) } }
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
    /// Completed breaks per day, keyed "yyyy-MM-dd". Kept for 90 days.
    @Published private(set) var history: [String: Int] { didSet { d.set(history, forKey: Key.history) } }
    @Published private(set) var breaksTotal: Int { didSet { d.set(breaksTotal, forKey: Key.breaksTotal) } }

    init(defaults: UserDefaults = .standard) {
        d = defaults
        d.register(defaults: [
            Key.interval: 20,
            Key.snooze: 5,
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
        snoozeMinutes = d.integer(forKey: Key.snooze)
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
        history = d.dictionary(forKey: Key.history) as? [String: Int] ?? [:]
        breaksTotal = d.integer(forKey: Key.breaksTotal)
        migrateLegacyStatistics()
    }

    /// Default settings with a made-up week of breaks, for screenshots. Never touches the real settings.
    static func sample() -> Preferences {
        let suite = "io.github.emsurenar.unknot.screenshots"
        UserDefaults().removePersistentDomain(forName: suite)
        let prefs = Preferences(defaults: UserDefaults(suiteName: suite)!)
        let today = Calendar.current.startOfDay(for: Date())
        for (offset, count) in [4, 6, 3, 0, 5, 7, 4].reversed().enumerated() {
            guard let day = Calendar.current.date(byAdding: .day, value: -offset, to: today) else { continue }
            for _ in 0..<count { prefs.recordCompletedBreak(at: day.addingTimeInterval(10 * 3600)) }
        }
        prefs.breaksTotal += 112
        return prefs
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

    var breaksToday: Int { history[Self.dayKey(Date())] ?? 0 }

    func recordCompletedBreak(at date: Date = Date()) {
        history[Self.dayKey(date), default: 0] += 1
        breaksTotal += 1
        // Keep the last 90 days
        if let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: date) {
            let oldest = Self.dayKey(cutoff)
            history = history.filter { $0.key >= oldest }
        }
    }

    func resetStatistics() {
        history = [:]
        breaksTotal = 0
    }

    struct DayCount: Identifiable {
        let date: Date
        let count: Int
        var id: Date { date }
    }

    /// Break counts for the last `days` days, oldest first, ending today.
    func recentDays(_ days: Int, until now: Date = Date(), calendar: Calendar = .current) -> [DayCount] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return DayCount(date: day, count: history[Self.dayKey(day, calendar: calendar)] ?? 0)
        }
    }

    /// Days in a row with at least one break. Today only counts once you've had a break,
    /// so the streak isn't broken in the morning.
    func streak(until now: Date = Date(), calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: now)
        if (history[Self.dayKey(day, calendar: calendar)] ?? 0) == 0 {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while (history[Self.dayKey(day, calendar: calendar)] ?? 0) > 0 {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    nonisolated static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Version 1.0.0 only stored today's count, as "year-month-day" without padding.
    private func migrateLegacyStatistics() {
        guard let day = d.string(forKey: Key.legacyStatsDay) else { return }
        let parts = day.split(separator: "-").compactMap { Int($0) }
        let count = d.integer(forKey: Key.legacyBreaksToday)
        if parts.count == 3, count > 0 {
            let key = String(format: "%04d-%02d-%02d", parts[0], parts[1], parts[2])
            history[key, default: 0] += count
        }
        d.removeObject(forKey: Key.legacyStatsDay)
        d.removeObject(forKey: Key.legacyBreaksToday)
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
