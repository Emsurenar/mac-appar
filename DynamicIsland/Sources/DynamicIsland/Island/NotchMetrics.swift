import AppKit

/// Where the hardware notch is, or where a virtual one would be on displays without one.
struct NotchMetrics: Equatable {
    var notchSize: CGSize
    var hasNotch: Bool
    var screenFrame: CGRect
    /// Horizontal center of the notch in screen coordinates.
    var centerX: CGFloat

    static let fallback = NotchMetrics(notchSize: CGSize(width: 180, height: 32), hasNotch: false,
                                       screenFrame: .zero, centerX: 0)

    init(notchSize: CGSize, hasNotch: Bool, screenFrame: CGRect, centerX: CGFloat) {
        self.notchSize = notchSize
        self.hasNotch = hasNotch
        self.screenFrame = screenFrame
        self.centerX = centerX
    }

    init(screen: NSScreen) {
        screenFrame = screen.frame
        if screen.safeAreaInsets.top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            hasNotch = true
            notchSize = CGSize(width: right.minX - left.maxX, height: screen.safeAreaInsets.top)
            centerX = (left.maxX + right.minX) / 2
        } else {
            hasNotch = false
            let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
            notchSize = CGSize(width: 180, height: menuBar > 0 ? menuBar : 24)
            centerX = screen.frame.midX
        }
    }

    /// The built-in display with a notch if there is one, otherwise the menu bar display.
    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens.first
    }
}
