import SwiftUI

/// The island outline: concave "ears" where it meets the top edge of the screen
/// and rounded bottom corners, both animatable so the shape morphs between states.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = max(0, min(topRadius, rect.width / 4, rect.height / 2))
        let bottom = max(0, min(bottomRadius, (rect.width - top * 2) / 2, rect.height - top))
        // Control-point factor for near-circular, continuous-looking corners.
        let k: CGFloat = 0.45

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.minX + top, y: rect.minY + top),
                      control1: CGPoint(x: rect.minX + top * (1 - k), y: rect.minY),
                      control2: CGPoint(x: rect.minX + top, y: rect.minY + top * k))
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        path.addCurve(to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
                      control1: CGPoint(x: rect.minX + top, y: rect.maxY - bottom * k),
                      control2: CGPoint(x: rect.minX + top + bottom * k, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
                      control1: CGPoint(x: rect.maxX - top - bottom * k, y: rect.maxY),
                      control2: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom * k))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                      control1: CGPoint(x: rect.maxX - top, y: rect.minY + top * k),
                      control2: CGPoint(x: rect.maxX - top * (1 - k), y: rect.minY))
        path.closeSubpath()
        return path
    }
}
