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

    func testTallyStartsOverTomorrow() {
        let calendar = Calendar(identifier: .gregorian)
        var tally = WaterTally(day: start, count: 0)
        tally.addGlass(on: start, calendar: calendar)
        tally.addGlass(on: start + 60, calendar: calendar)
        XCTAssertEqual(tally.count(on: start, calendar: calendar), 2)
        XCTAssertEqual(tally.count(on: start + 86_400, calendar: calendar), 0)
        tally.addGlass(on: start + 86_400, calendar: calendar)
        XCTAssertEqual(tally.count(on: start + 86_400, calendar: calendar), 1)
    }
}
