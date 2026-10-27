import AppKit
import CoreGraphics

/// Counts the time the user is at the Mac and decides when it's time for a glass of water.
/// Kept as a plain value so the timing can be tested without timers or a real idle clock.
struct WaterSchedule: Equatable {
    /// No input for this long counts as away from the Mac.
    static let idleThreshold: TimeInterval = 5 * 60
    /// A longer gap between ticks means the Mac slept, which doesn't count.
    static let maxStep: TimeInterval = 120

    /// Time at the Mac since the last glass.
    var activeSeconds: TimeInterval = 0
    var lastTick: Date?

    mutating func advance(to now: Date, idle: TimeInterval) {
        defer { lastTick = now }
        guard let lastTick else { return }
        let step = now.timeIntervalSince(lastTick)
        guard step > 0, step <= Self.maxStep, idle < Self.idleThreshold else { return }
        activeSeconds += step
    }

    func isDue(interval: TimeInterval) -> Bool { activeSeconds >= interval }

    mutating func reset() { activeSeconds = 0 }

    /// Brings the next reminder to `seconds` of active time from now.
    mutating func snooze(_ seconds: TimeInterval, interval: TimeInterval) {
        activeSeconds = max(0, interval - seconds)
    }
}

/// Glasses drunk per day, so the island can show today, the last week and a streak.
struct WaterLog: Equatable {
    /// Glasses keyed by day, as "yyyy-MM-dd" in the user's calendar.
    var days: [String: Int] = [:]

    /// Days kept around; older ones are dropped when a glass is logged.
    static let keptDays = 120

    static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    func count(on date: Date, calendar: Calendar = .current) -> Int {
        days[Self.key(for: date, calendar: calendar)] ?? 0
    }

    /// Adds (or with a negative `delta`, takes back) glasses on `date`, never going below zero.
    mutating func add(_ delta: Int, on date: Date, calendar: Calendar = .current) {
        let key = Self.key(for: date, calendar: calendar)
        let count = max(0, (days[key] ?? 0) + delta)
        days[key] = count == 0 ? nil : count
        if let oldest = calendar.date(byAdding: .day, value: -Self.keptDays, to: date) {
            let cutoff = Self.key(for: oldest, calendar: calendar)
            days = days.filter { $0.key >= cutoff }
        }
    }

    /// The last `count` days, oldest first, ending with `date`.
    func history(_ count: Int, endingOn date: Date, calendar: Calendar = .current) -> [(day: Date, glasses: Int)] {
        let today = calendar.startOfDay(for: date)
        return (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map { (day: $0, glasses: self.count(on: $0, calendar: calendar)) }
        }
    }

    /// Days in a row that reached `goal`. Today counts once it's reached,
    /// but a day still in progress doesn't break the streak.
    func streak(goal: Int, on date: Date, calendar: Calendar = .current) -> Int {
        var day = calendar.startOfDay(for: date)
        if count(on: day, calendar: calendar) < goal {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while count(on: day, calendar: calendar) >= goal, streak < Self.keptDays {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}

@MainActor @Observable
final class WaterService {
    private(set) var isDue = false
    private(set) var log: WaterLog

    var glassesToday: Int { log.count(on: Date()) }

    /// Called on every tick while a glass is due and the user is at the Mac.
    @ObservationIgnored var onDue: (() -> Void)?
    @ObservationIgnored var isEnabled: () -> Bool = { true }
    @ObservationIgnored var interval: () -> TimeInterval = { 45 * 60 }

    static let snoozeSeconds: TimeInterval = 10 * 60
    private static let tickSeconds: TimeInterval = 30

    private enum Key {
        static let log = "waterLog"
        // Before the log: just today's count.
        static let glasses = "waterGlasses"
        static let day = "waterDay"
    }

    @ObservationIgnored private var schedule = WaterSchedule()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let days = defaults.dictionary(forKey: Key.log) as? [String: Int] {
            log = WaterLog(days: days)
        } else {
            log = WaterLog()
            if let day = defaults.object(forKey: Key.day) as? Date {
                log.add(defaults.integer(forKey: Key.glasses), on: day)
            }
        }
    }

    func start() {
        guard timer == nil else { return }
        schedule.lastTick = Date()
        timer = Timer.scheduledTimer(withTimeInterval: Self.tickSeconds, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func drink() {
        log.add(1, on: Date())
        save()
        schedule.reset()
        isDue = false
    }

    /// Takes back the last glass, for a tap too many.
    func undoGlass() {
        guard glassesToday > 0 else { return }
        log.add(-1, on: Date())
        save()
    }

    func history(_ days: Int) -> [(day: Date, glasses: Int)] { log.history(days, endingOn: Date()) }

    func streak(goal: Int) -> Int { log.streak(goal: goal, on: Date()) }

    func snooze() {
        schedule.snooze(Self.snoozeSeconds, interval: interval())
        isDue = false
    }

    private func save() {
        defaults.set(log.days, forKey: Key.log)
    }

    private func tick() {
        guard isEnabled() else {
            schedule = WaterSchedule(lastTick: Date())
            isDue = false
            return
        }
        let idle = Self.idleSeconds
        schedule.advance(to: Date(), idle: idle)
        isDue = schedule.isDue(interval: interval())
        if isDue && idle < WaterSchedule.idleThreshold { onDue?() }
    }

    /// Seconds since the last keyboard, mouse or trackpad input.
    private static var idleSeconds: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    #if DEBUG
    func showPreview(glasses: Int) {
        var log = WaterLog()
        // A week that reached the goal on most days, for the history bars.
        for (offset, count) in [8, 9, 5, 8, 10, 8].enumerated() {
            log.add(count, on: Date().addingTimeInterval(-Double(6 - offset) * 86_400))
        }
        log.add(glasses, on: Date())
        self.log = log
        isDue = true
    }
    #endif
}
