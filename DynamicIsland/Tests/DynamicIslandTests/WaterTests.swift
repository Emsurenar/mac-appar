import XCTest
@testable import DynamicIsland

final class WaterTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    /// Ticks every 30 seconds for `minutes`, with the given idle time on each tick.
    private func run(_ schedule: inout WaterSchedule, minutes: Int, idle: TimeInterval = 0, from date: Date) -> Date {
        var now = date
        for _ in 0..<(minutes * 2) {
            now += 30
            schedule.advance(to: now, idle: idle)
        }
        return now
    }

    func testDueAfterTheIntervalAtTheMac() {
        var schedule = WaterSchedule(lastTick: start)
        let now = run(&schedule, minutes: 44, from: start)
        XCTAssertFalse(schedule.isDue(interval: 45 * 60))
        _ = run(&schedule, minutes: 1, from: now)
        XCTAssertTrue(schedule.isDue(interval: 45 * 60))
    }

    func testTimeAwayDoesNotCount() {
        var schedule = WaterSchedule(lastTick: start)
        _ = run(&schedule, minutes: 60, idle: WaterSchedule.idleThreshold, from: start)
        XCTAssertEqual(schedule.activeSeconds, 0)
    }

    func testSleepDoesNotCount() {
        var schedule = WaterSchedule(lastTick: start)
        schedule.advance(to: start + 3 * 3600, idle: 0)
        XCTAssertEqual(schedule.activeSeconds, 0)
        schedule.advance(to: start + 3 * 3600 + 30, idle: 0)
        XCTAssertEqual(schedule.activeSeconds, 30)
    }

    func testSnoozeAsksAgainLater() {
        var schedule = WaterSchedule(activeSeconds: 45 * 60, lastTick: start)
        schedule.snooze(10 * 60, interval: 45 * 60)
        XCTAssertFalse(schedule.isDue(interval: 45 * 60))
        _ = run(&schedule, minutes: 10, from: start)
        XCTAssertTrue(schedule.isDue(interval: 45 * 60))
    }

    private let calendar = Calendar(identifier: .gregorian)
    private let day: TimeInterval = 86_400

    func testLogStartsOverTomorrow() {
        var log = WaterLog()
        log.add(1, on: start, calendar: calendar)
        log.add(1, on: start + 60, calendar: calendar)
        XCTAssertEqual(log.count(on: start, calendar: calendar), 2)
        XCTAssertEqual(log.count(on: start + day, calendar: calendar), 0)
        log.add(1, on: start + day, calendar: calendar)
        XCTAssertEqual(log.count(on: start + day, calendar: calendar), 1)
        XCTAssertEqual(log.count(on: start, calendar: calendar), 2, "yesterday is kept for the history")
    }

    func testUndoNeverGoesBelowZero() {
        var log = WaterLog()
        log.add(1, on: start, calendar: calendar)
        log.add(-1, on: start, calendar: calendar)
        log.add(-1, on: start, calendar: calendar)
        XCTAssertEqual(log.count(on: start, calendar: calendar), 0)
        XCTAssertTrue(log.days.isEmpty)
    }

    func testHistoryEndsToday() {
        var log = WaterLog()
        log.add(3, on: start - 2 * day, calendar: calendar)
        log.add(5, on: start, calendar: calendar)
        let history = log.history(7, endingOn: start, calendar: calendar)
        XCTAssertEqual(history.map(\.glasses), [0, 0, 0, 0, 3, 0, 5])
        XCTAssertTrue(calendar.isDate(history.last!.day, inSameDayAs: start))
    }

    func testStreakCountsDaysThatReachedTheGoal() {
        var log = WaterLog()
        for offset in 1...3 { log.add(8, on: start - Double(offset) * day, calendar: calendar) }
        log.add(2, on: start - 5 * day, calendar: calendar)
        XCTAssertEqual(log.streak(goal: 8, on: start, calendar: calendar), 3, "today in progress doesn't break it")
        log.add(8, on: start, calendar: calendar)
        XCTAssertEqual(log.streak(goal: 8, on: start, calendar: calendar), 4)
        XCTAssertEqual(log.streak(goal: 8, on: start + 2 * day, calendar: calendar), 0)
    }

    func testOldDaysAreDropped() {
        var log = WaterLog()
        log.add(4, on: start - Double(WaterLog.keptDays + 1) * day, calendar: calendar)
        log.add(1, on: start, calendar: calendar)
        XCTAssertEqual(log.days.count, 1)
    }

    @MainActor func testOldTallyIsCarriedOver() {
        let name = "DynamicIslandTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(3, forKey: "waterGlasses")
        defaults.set(Date(), forKey: "waterDay")
        let water = WaterService(defaults: defaults)
        XCTAssertEqual(water.glassesToday, 3)
        water.drink()
        XCTAssertEqual(WaterService(defaults: defaults).glassesToday, 4)
    }
}
