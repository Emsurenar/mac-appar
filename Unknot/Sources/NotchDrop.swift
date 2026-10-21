import CoreGraphics

/// The shape of a break coming out of the camera notch: a drop of black falls out of the notch, stretches,
/// and opens into the glass panel. Coordinates have y pointing down, with 0 at the top of the screen.
/// Shared by the real window and the README animation, so both move the same way.
struct NotchDrop {
    /// Where it starts: the notch itself, or a sliver under the menu bar on screens without one.
    let start: CGRect
    /// Where it ends: the panel.
    let panel: CGRect
    /// With a real notch the drop starts out black, like the notch, and turns into glass.
    let fromNotch: Bool
    var cornerRadius: CGFloat = 22

    static let openDuration = 0.75
    static let closeDuration = 0.45

    /// Everything that changes during the animation, at `t` from 0 (inside the notch) to 1 (open).
    struct Frame {
        let outline: CGPath
        let ink: CGFloat       // how black the drop still is
        let content: CGFloat   // how visible the panel's contents are
        let shadow: CGFloat
        let contentOffset: CGFloat
    }

    func frame(at t: CGFloat) -> Frame {
        let t = min(max(t, 0), 1)
        // First the drop falls out of the notch…
        let fall = easeOut(t / 0.3)
        let dropped = CGRect(x: start.midX - (start.width + 6) / 2, y: start.minY,
                             width: start.width + 6, height: start.height + 34)
        let drop = mix(start, dropped, fall)
        // …then it opens into the panel, with a little overshoot, like something soft
        let open = backOut((t - 0.18) / 0.82)
        let rect = mix(drop, panel, open)
        let top = mixValue(0, cornerRadius, min(open * 1.6, 1))
        let bottom = mixValue(min(10, drop.height / 2), cornerRadius, min(open, 1))

        // Black only while it's small and close to the notch; glass by the time it's half open
        let ink = fromNotch ? 1 - smooth(open / 0.5) : 0
        let content = smooth((t - 0.42) / 0.36)
        return Frame(outline: Self.outline(rect, top: top, bottom: bottom),
                     ink: ink,
                     content: content,
                     shadow: fromNotch ? 1 - ink : smooth(t / 0.6),
                     contentOffset: (1 - content) * -8)
    }

    /// The black drains back up into the notch: solid down to a point, then a soft edge, then glass.
    /// Returns gradient stops from the top of the shape (0) to the bottom (1).
    static func inkStops(_ ink: CGFloat) -> (solid: CGFloat, clear: CGFloat) {
        let edge = ink * 1.35
        return (max(0, edge - 0.35), max(0.001, edge))
    }

    /// A rectangle with its own radius for the top and bottom corners.
    static func outline(_ r: CGRect, top: CGFloat, bottom: CGFloat) -> CGPath {
        let top = max(0, min(top, r.width / 2, r.height / 2))
        let bottom = max(0, min(bottom, r.width / 2, r.height / 2))
        let p = CGMutablePath()
        p.move(to: CGPoint(x: r.minX + top, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - top, y: r.minY))
        p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.maxY), radius: top)
        p.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY), radius: bottom)
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.minY), radius: bottom)
        p.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.maxX, y: r.minY), radius: top)
        p.closeSubpath()
        return p
    }

    // MARK: Easing

    private func smooth(_ x: CGFloat) -> CGFloat {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }

    private func easeOut(_ x: CGFloat) -> CGFloat {
        let c = min(max(x, 0), 1)
        return 1 - (1 - c) * (1 - c) * (1 - c)
    }

    /// Overshoots by about 4 % before settling.
    private func backOut(_ x: CGFloat) -> CGFloat {
        let c = min(max(x, 0), 1)
        let s: CGFloat = 1.2
        return 1 + (s + 1) * pow(c - 1, 3) + s * pow(c - 1, 2)
    }

    private func mixValue(_ a: CGFloat, _ b: CGFloat, _ k: CGFloat) -> CGFloat { a + (b - a) * k }

    private func mix(_ a: CGRect, _ b: CGRect, _ k: CGFloat) -> CGRect {
        CGRect(x: mixValue(a.minX, b.minX, k), y: mixValue(a.minY, b.minY, k),
               width: max(0, mixValue(a.width, b.width, k)), height: max(0, mixValue(a.height, b.height, k)))
    }
}
