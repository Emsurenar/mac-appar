import CoreGraphics
import Foundation

/// A break growing out of the camera notch, the way Dynamic Island opens: the black of the notch springs out
/// into the island, its ears curving into the top of the screen, and the contents arrive through a blur.
/// Coordinates have y pointing down, with 0 at the top of the screen. Shared by the real window and the
/// README animation, so both move the same way.
struct NotchDrop {
    /// Where it starts: the notch itself, or a sliver at the top of a screen without one.
    let start: CGRect
    /// Where it ends: the open island, hanging from the top of the screen.
    let island: CGRect

    /// Long enough for the springs to settle.
    static let openDuration = 0.7
    static let closeDuration = 0.42

    /// Everything that changes during the animation.
    struct Frame {
        let outline: CGPath
        let reveal: CGFloat    // how far the contents have come into view
        let shadow: CGFloat
    }

    /// The island `t` seconds after it began to open, or to close when `closing` is set.
    func frame(at t: Double, closing: Bool = false) -> Frame {
        let p: CGFloat
        let reveal: CGFloat
        if closing {
            p = CGFloat(1 - Island.spring(t, response: Island.closeResponse, damping: Island.closeDamping))
            reveal = 1 - smooth(CGFloat(t / 0.14))
        } else {
            p = CGFloat(Island.spring(t, response: Island.openResponse, damping: Island.openDamping))
            reveal = smooth(CGFloat((t - 0.1) / 0.3))
        }
        // The size springs, and may overshoot a little; the corners follow without going past their mark
        let rect = mix(start, island, p)
        let k = min(max(p, 0), 1)
        let outline = Island.outline(rect, ear: Island.earRadius * k, bottom: 8 + (Island.bottomRadius - 8) * k)
        return Frame(outline: outline, reveal: reveal, shadow: k)
    }

    private func smooth(_ x: CGFloat) -> CGFloat {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    private func mix(_ a: CGRect, _ b: CGRect, _ k: CGFloat) -> CGRect {
        func m(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * k }
        // Centred on the island, and always hanging from the top edge
        let width = max(0, m(a.width, b.width)), height = max(0, m(a.height, b.height))
        return CGRect(x: m(a.midX, b.midX) - width / 2, y: b.minY, width: width, height: height)
    }
}
