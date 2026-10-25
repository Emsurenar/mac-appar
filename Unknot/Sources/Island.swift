import SwiftUI

/// The look Unknot shares with Dynamic Island in mac-appar: a black island that grows out of the notch, with
/// concave ears where it meets the top of the screen, white type, an orange accent and capsule buttons.
enum Island {
    static let accent = Color(hex: 0xFF9F0A)            // the orange of Dynamic Island and Posture
    static let secondary = Color.white.opacity(0.55)
    static let tertiary = Color.white.opacity(0.45)

    /// The ears that blend the island into the top edge, and the round bottom corners, when it's open.
    static let earRadius: CGFloat = 14
    static let bottomRadius: CGFloat = 32
    /// In a corner of the screen there's no notch to grow from: a black rounded panel instead.
    static let panelRadius: CGFloat = 26

    /// The same springs as Dynamic Island.
    static let openResponse = 0.42, openDamping = 0.74
    static let closeResponse = 0.38, closeDamping = 0.9

    /// The island outline, y pointing down, with concave ears of radius `ear` where it meets the top edge and
    /// round bottom corners. The same curve as Dynamic Island's NotchShape, so the two apps match.
    static func outline(_ rect: CGRect, ear: CGFloat, bottom: CGFloat) -> CGPath {
        let top = max(0, min(ear, rect.width / 4, rect.height / 2))
        let bottom = max(0, min(bottom, (rect.width - top * 2) / 2, rect.height - top))
        let k: CGFloat = 0.45
        let p = CGMutablePath()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addCurve(to: CGPoint(x: rect.minX + top, y: rect.minY + top),
                   control1: CGPoint(x: rect.minX + top * (1 - k), y: rect.minY),
                   control2: CGPoint(x: rect.minX + top, y: rect.minY + top * k))
        p.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        p.addCurve(to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
                   control1: CGPoint(x: rect.minX + top, y: rect.maxY - bottom * k),
                   control2: CGPoint(x: rect.minX + top + bottom * k, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        p.addCurve(to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
                   control1: CGPoint(x: rect.maxX - top - bottom * k, y: rect.maxY),
                   control2: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom * k))
        p.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        p.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                   control1: CGPoint(x: rect.maxX - top, y: rect.minY + top * k),
                   control2: CGPoint(x: rect.maxX - top * (1 - k), y: rect.minY))
        p.closeSubpath()
        return p
    }

    /// A damped spring from 0 to 1, as SwiftUI's `.spring(response:dampingFraction:)` moves, at `t` seconds.
    static func spring(_ t: Double, response: Double, damping: Double) -> Double {
        guard t > 0 else { return 0 }
        let omega = 2 * .pi / response
        let decay = exp(-damping * omega * t)
        guard damping < 1 else { return 1 - decay * (1 + omega * t) }
        let wd = omega * sqrt(1 - damping * damping)
        return 1 - decay * (cos(wd * t) + damping * omega / wd * sin(wd * t))
    }

    /// The desktop behind Dynamic Island's screenshots, for Unknot's: blue to purple to pink.
    static let wallpaper = LinearGradient(colors: [Color(hex: 0x3048B0), Color(hex: 0x8C6BD6), Color(hex: 0xE59BBE)],
                                          startPoint: .leading, endPoint: .trailing)
}

/// The island's outline as a SwiftUI shape, for drawings of it.
struct IslandShape: Shape {
    var ear: CGFloat = Island.earRadius
    var bottom: CGFloat = Island.bottomRadius
    func path(in rect: CGRect) -> Path { Path(Island.outline(rect, ear: ear, bottom: bottom)) }
}

/// Dynamic Island's capsule buttons: white with black type for the main action, a soft white plate otherwise.
struct IslandCapsuleStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        Styled(configuration: configuration, prominent: prominent)
    }

    private struct Styled: View {
        let configuration: Configuration
        let prominent: Bool
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(prominent ? Color.black : Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Capsule().fill(prominent ? Color.white.opacity(hovering ? 1 : 0.9)
                                                     : Color.white.opacity(hovering ? 0.22 : 0.14)))
                .contentShape(Capsule())
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
                .animation(.easeOut(duration: 0.15), value: hovering)
                .onHover { hovering = $0 }
        }
    }
}

extension AnyTransition {
    /// Content dissolves through a blur while it scales from the notch, like in Dynamic Island.
    static func islandContent(scale: CGFloat) -> AnyTransition {
        .modifier(active: IslandReveal(progress: 0, scale: scale), identity: IslandReveal(progress: 1, scale: scale))
    }
}

/// How far the island's content has come into view: blurred, smaller and transparent at 0.
struct IslandReveal: ViewModifier {
    var progress: CGFloat
    var scale: CGFloat = 0.9

    func body(content: Content) -> some View {
        content
            .blur(radius: (1 - progress) * 10)
            .scaleEffect(scale + (1 - scale) * progress, anchor: .top)
            .opacity(Double(progress))
    }
}
