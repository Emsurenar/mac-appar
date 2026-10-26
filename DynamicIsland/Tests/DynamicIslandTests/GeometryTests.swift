import XCTest
@testable import DynamicIsland

final class GeometryTests: XCTestCase {
    private let notched = NotchMetrics(notchSize: CGSize(width: 200, height: 32), hasNotch: true,
                                       screenFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), centerX: 756)
    private let flat = NotchMetrics(notchSize: CGSize(width: 180, height: 24), hasNotch: false,
                                    screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080), centerX: 960)

    private func geometry(_ presentation: IslandPresentation, _ metrics: NotchMetrics? = nil,
                          hovering: Bool = false, content: CGFloat = 0) -> IslandGeometry {
        IslandGeometry(presentation: presentation, metrics: metrics ?? notched, isHovering: hovering,
                       openContentHeight: content)
    }

    func testClosedIslandIsExactlyTheNotch() {
        let closed = geometry(.closed)
        XCTAssertEqual(closed.size, notched.notchSize)
        XCTAssertEqual(closed.earRadius, 0)
    }

    func testClosedIslandGrowsOnHover() {
        let hovered = geometry(.closed, hovering: true)
        XCTAssertGreaterThan(hovered.size.width, notched.notchSize.width)
        XCTAssertGreaterThan(hovered.earRadius, 0)
    }

    func testNoNotchHidesTheClosedIsland() {
        XCTAssertEqual(geometry(.closed, flat).size.height, 0)
        XCTAssertEqual(geometry(.closed, flat, hovering: true).size.height, 8)
    }

    func testOpenIslandAddsItsContentBelowTheNotch() {
        let open = geometry(.open, content: 162)
        XCTAssertEqual(open.size.height, 32 + 162)
        XCTAssertGreaterThanOrEqual(open.size.width, 500)
    }

    func testLiveActivitiesKeepTheNotchHeight() {
        for presentation: IslandPresentation in [.compact, .postureCompact, .hud(.volume), .hud(.brightness)] {
            XCTAssertEqual(geometry(presentation).size.height, 32, "\(presentation)")
        }
    }

    func testHoverZoneIsCenteredOnTheNotchAndTouchesTheTop() {
        for presentation: IslandPresentation in [.closed, .compact, .peek, .open] {
            let zone = geometry(presentation, content: 162).hoverZone
            XCTAssertEqual(zone.midX, notched.centerX, accuracy: 0.5, "\(presentation)")
            XCTAssertGreaterThanOrEqual(zone.maxY, notched.screenFrame.maxY, "\(presentation)")
            XCTAssertTrue(zone.contains(CGPoint(x: notched.centerX, y: notched.screenFrame.maxY - 1)), "\(presentation)")
        }
    }

    func testHoverZoneCoversTheWholeOpenIsland() {
        let open = geometry(.open, content: 162)
        XCTAssertGreaterThan(open.hoverZone.width, open.size.width)
        XCTAssertGreaterThan(open.hoverZone.height, open.size.height)
    }
}
