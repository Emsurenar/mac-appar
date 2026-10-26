import XCTest
@testable import DynamicIsland

final class PresentationTests: XCTestCase {
    func testNothingGoingOnIsClosed() {
        XCTAssertEqual(IslandPresentation(PresentationState()), .closed)
    }

    func testOpenWinsOverEverything() {
        let state = PresentationState(isOpen: true, hud: .volume, showsCalendarReminder: true,
                                      showsPostureAlert: true, showsTrackPeek: true,
                                      showsMediaActivity: true, showsPostureActivity: true)
        XCTAssertEqual(IslandPresentation(state), .open)
    }

    func testHUDWinsOverReminders() {
        let state = PresentationState(hud: .brightness, showsCalendarReminder: true, showsPostureAlert: true)
        XCTAssertEqual(IslandPresentation(state), .hud(.brightness))
    }

    func testCalendarReminderWinsOverPostureAlert() {
        let state = PresentationState(showsCalendarReminder: true, showsPostureAlert: true)
        XCTAssertEqual(IslandPresentation(state), .calendarReminder)
    }

    func testTrackPeekWinsOverLiveActivities() {
        let state = PresentationState(showsTrackPeek: true, showsMediaActivity: true, showsPostureActivity: true)
        XCTAssertEqual(IslandPresentation(state), .peek)
    }

    func testMusicTakesTheSpotFromPosture() {
        let state = PresentationState(showsMediaActivity: true, showsPostureActivity: true)
        XCTAssertEqual(IslandPresentation(state), .compact)
        XCTAssertEqual(IslandPresentation(PresentationState(showsPostureActivity: true)), .postureCompact)
    }
}
