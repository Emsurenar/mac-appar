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

/// Glasses drunk today; starts over at midnight.
struct WaterTally: Equatable {
    var day: Date
    var count: Int

    func count(on date: Date, calendar: Calendar = .current) -> Int {
        calendar.isDate(day, inSameDayAs: date) ? count : 0
    }

    mutating func addGlass(on date: Date, calendar: Calendar = .current) {
        count = count(on: date, calendar: calendar) + 1
        day = date
    }
}

@MainActor @Observable
final class WaterService {
    private(set) var isDue = false
    private(set) var tally: WaterTally

    var glassesToday: Int { tally.count(on: Date()) }

    /// Called on every tick while a glass is due and the user is at the Mac.
    @ObservationIgnored var onDue: (() -> Void)?
    @ObservationIgnored var isEnabled: () -> Bool = { true }
    @ObservationIgnored var interval: () -> TimeInterval = { 45 * 60 }

    static let snoozeSeconds: TimeInterval = 10 * 60
    private static let tickSeconds: TimeInterval = 30

    private enum Key {
        static let glasses = "waterGlasses"
        static let day = "waterDay"
    }

    @ObservationIgnored private var schedule = WaterSchedule()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let day = defaults.object(forKey: Key.day) as? Date ?? .distantPast
        tally = WaterTally(day: day, count: defaults.integer(forKey: Key.glasses))
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
        tally.addGlass(on: Date())
        defaults.set(tally.count, forKey: Key.glasses)
        defaults.set(tally.day, forKey: Key.day)
        schedule.reset()
        isDue = false
    }

    func snooze() {
        schedule.snooze(Self.snoozeSeconds, interval: interval())
        isDue = false
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
        tally = WaterTally(day: Date(), count: glasses)
        isDue = true
    }
    #endif
}
