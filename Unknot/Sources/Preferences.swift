import AppKit

enum ReminderPosition: String, CaseIterable, Identifiable {
    case topCenter, bottomRight, topRight, bottomLeft, topLeft

    var id: String { rawValue }
    var isTop: Bool { self == .topCenter || self == .topRight || self == .topLeft }
    var isLeft: Bool { self == .bottomLeft || self == .topLeft }

    var title: String {
        switch self {
        case .topCenter: return L("Top center")
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
    /// "Unknot" is the app's own sound (Resources/Unknot.wav, made by scripts/make_sound.py); the rest come with macOS.
    static let soundOptions = ["Unknot", "Purr", "Pop", "Tink", "Glass", "Bottle", "Hero", "Submarine", "Blow", "Ping", "Morse", "Frog", "Funk"]

    private enum Key {
        static let interval = "intervalMinutes"
        static let language = "language"
        static let snooze = "snoozeMinutes"
        static let breakLength = "breakSeconds"
        static let exerciseCount = "exercisesPerBreak"
        static let soundEnabled = "soundEnabled"
        static let soundName = "soundName"
        static let position = "position"
        static let showCountdown = "showCountdownInMenuBar"
        static let disabledExercises = "disabledExercises"
        static let disabledBuddies = "disabledBuddies"
        static let countAway = "countAwayAsBreak"
        static let awayMinutes = "awayMinutes"
        static let workHours = "workHoursEnabled"
        static let workStart = "workStartMinutes"
        static let workEnd = "workEndMinutes"
        static let weekdaysOnly = "weekdaysOnly"
        static let waitForFullscreen = "waitForFullscreen"
        static let waitDuringCalls = "waitDuringCalls"
        static let checkForUpdates = "checkForUpdates"
        static let onboarded = "hasCompletedOnboarding"
        static let history = "breakHistory"
        static let breaksTotal = "breaksTotal"
        // Used by 1.0.0, migrated into `history`
        static let legacyStatsDay = "statsDay"
        static let legacyBreaksToday = "breaksToday"
    }

    private let d: UserDefaults

    @Published var language: AppLanguage {
        didSet {
            d.set(language.rawValue, forKey: Key.language)
            Localizer.apply(language)
        }
    }
    @Published var intervalMinutes: Int { didSet { d.set(intervalMinutes, forKey: Key.interval) } }
    @Published var snoozeMinutes: Int { didSet { d.set(snoozeMinutes, forKey: Key.snooze) } }
    @Published var breakSeconds: Int { didSet { d.set(breakSeconds, forKey: Key.breakLength) } }
    @Published var exercisesPerBreak: Int { didSet { d.set(exercisesPerBreak, forKey: Key.exerciseCount) } }
    @Published var soundEnabled: Bool { didSet { d.set(soundEnabled, forKey: Key.soundEnabled) } }
    @Published var soundName: String { didSet { d.set(soundName, forKey: Key.soundName) } }
    @Published var position: ReminderPosition { didSet { d.set(position.rawValue, forKey: Key.position) } }
    @Published var showCountdownInMenuBar: Bool { didSet { d.set(showCountdownInMenuBar, forKey: Key.showCountdown) } }
    @Published var disabledExercises: Set<String> { didSet { d.set(Array(disabledExercises).sorted(), forKey: Key.disabledExercises) } }
    @Published var disabledBuddies: Set<String> { didSet { d.set(Array(disabledBuddies).sorted(), forKey: Key.disabledBuddies) } }
    @Published var countAwayAsBreak: Bool { didSet { d.set(countAwayAsBreak, forKey: Key.countAway) } }
    @Published var awayMinutes: Int { didSet { d.set(awayMinutes, forKey: Key.awayMinutes) } }
    @Published var workHoursEnabled: Bool { didSet { d.set(workHoursEnabled, forKey: Key.workHours) } }
    @Published var workStartMinutes: Int { didSet { d.set(workStartMinutes, forKey: Key.workStart) } }
    @Published var workEndMinutes: Int { didSet { d.set(workEndMinutes, forKey: Key.workEnd) } }
    @Published var weekdaysOnly: Bool { didSet { d.set(weekdaysOnly, forKey: Key.weekdaysOnly) } }
    @Published var waitForFullscreen: Bool { didSet { d.set(waitForFullscreen, forKey: Key.waitForFullscreen) } }
    @Published var waitDuringCalls: Bool { didSet { d.set(waitDuringCalls, forKey: Key.waitDuringCalls) } }
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
            Key.soundName: "Unknot",
            Key.position: ReminderPosition.topCenter.rawValue,
            Key.showCountdown: false,
            Key.countAway: true,
            Key.awayMinutes: 5,
            Key.workHours: false,
            Key.workStart: 8 * 60,
            Key.workEnd: 17 * 60,
            Key.weekdaysOnly: true,
            Key.waitForFullscreen: false,
            Key.waitDuringCalls: true,
            Key.checkForUpdates: true,
        ])
        language = AppLanguage(rawValue: d.string(forKey: Key.language) ?? "") ?? .system
        intervalMinutes = d.integer(forKey: Key.interval)
        snoozeMinutes = d.integer(forKey: Key.snooze)
        breakSeconds = d.integer(forKey: Key.breakLength)
        exercisesPerBreak = d.integer(forKey: Key.exerciseCount)
        soundEnabled = d.bool(forKey: Key.soundEnabled)
        soundName = d.string(forKey: Key.soundName) ?? "Unknot"
        position = ReminderPosition(rawValue: d.string(forKey: Key.position) ?? "") ?? .topCenter
        showCountdownInMenuBar = d.bool(forKey: Key.showCountdown)
        disabledExercises = Set(d.stringArray(forKey: Key.disabledExercises) ?? [])
        disabledBuddies = Set(d.stringArray(forKey: Key.disabledBuddies) ?? [])
        countAwayAsBreak = d.bool(forKey: Key.countAway)
        awayMinutes = d.integer(forKey: Key.awayMinutes)
        workHoursEnabled = d.bool(forKey: Key.workHours)
        workStartMinutes = d.integer(forKey: Key.workStart)
        workEndMinutes = d.integer(forKey: Key.workEnd)
        weekdaysOnly = d.bool(forKey: Key.weekdaysOnly)
        waitForFullscreen = d.bool(forKey: Key.waitForFullscreen)
        waitDuringCalls = d.bool(forKey: Key.waitDuringCalls)
        checkForUpdates = d.bool(forKey: Key.checkForUpdates)
        hasCompletedOnboarding = d.bool(forKey: Key.onboarded)
        history = d.dictionary(forKey: Key.history) as? [String: Int] ?? [:]
        breaksTotal = d.integer(forKey: Key.breaksTotal)
        migrateLegacyStatistics()
        Localizer.apply(language)
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

    // MARK: Buddies

    var enabledBuddies: [Buddy] {
        let enabled = Buddy.allCases.filter { !disabledBuddies.contains($0.id) }
        return enabled.isEmpty ? Buddy.allCases : enabled
    }

    func isEnabled(_ buddy: Buddy) -> Bool { !disabledBuddies.contains(buddy.id) }

    /// Turns a buddy on or off, but always keeps at least one.
    func setEnabled(_ buddy: Buddy, _ on: Bool) {
        if on {
            disabledBuddies.remove(buddy.id)
        } else if enabledBuddies.count > 1 {
            disabledBuddies.insert(buddy.id)
        }
    }

    /// Who leads the next break. On Shrove Tuesday it's always Selma the semla, if she's on the crew.
    func buddyForBreak(avoiding previous: Buddy?, on date: Date = Date()) -> Buddy {
        if Holidays.isShroveTuesday(date) && isEnabled(Buddy.semla) { return .semla }
        return randomBuddy(avoiding: previous)
    }

    /// A random buddy from the enabled ones, avoiding `previous` when there's a choice.
    func randomBuddy(avoiding previous: Buddy? = nil) -> Buddy {
        let choices = enabledBuddies.filter { $0 != previous }
        return (choices.isEmpty ? enabledBuddies : choices).randomElement() ?? .mochi
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

/// Days when the crew does something special.
enum Holidays {
    /// Easter Sunday in the Gregorian calendar (the anonymous Gregorian algorithm).
    static func easter(_ year: Int, calendar: Calendar = .current) -> Date? {
        let a = year % 19, b = year / 100, c = year % 100, d = b / 4, e = b % 4
        let f = (b + 8) / 25, g = (b - f + 1) / 3, h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31, day = (h + l - 7 * m + 114) % 31 + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// Fettisdagen: the Tuesday 47 days before Easter, when Swedes eat semlor.
    static func isShroveTuesday(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard let easter = easter(calendar.component(.year, from: date), calendar: calendar),
              let tuesday = calendar.date(byAdding: .day, value: -47, to: easter) else { return false }
        return calendar.isDate(date, inSameDayAs: tuesday)
    }
}
