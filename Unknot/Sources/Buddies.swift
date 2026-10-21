import SwiftUI

/// The cast. Every buddy shares the same face, arms and moves, but has its own body and details.
enum Buddy: String, CaseIterable, Identifiable {
    case mochi, cat, panda, bunny, frog, penguin, chick, toast, onigiri, cactus

    var id: String { rawValue }

    var name: String {
        switch self {
        case .mochi: return L("Mochi")
        case .cat: return L("Cat")
        case .panda: return L("Panda")
        case .bunny: return L("Bunny")
        case .frog: return L("Frog")
        case .penguin: return L("Penguin")
        case .chick: return L("Chick")
        case .toast: return L("Toast")
        case .onigiri: return L("Onigiri")
        case .cactus: return L("Cactus")
        }
    }

    /// Body width and height in the 150×150 drawing space.
    var size: CGSize {
        switch self {
        case .mochi: return CGSize(width: 88, height: 86)
        case .bunny: return CGSize(width: 88, height: 76)
        case .toast: return CGSize(width: 86, height: 84)
        case .onigiri: return CGSize(width: 102, height: 94)
        case .cactus: return CGSize(width: 60, height: 92)
        default: return CGSize(width: 90, height: 80)
        }
    }

    var look: Look {
        switch self {
        case .mochi:
            return Look(top: Palette.bodyTop, bottom: Palette.bodyBottom, limb: Palette.limb, outline: Palette.outline)
        case .cat:
            return Look(top: Color(hex: 0xF2F1F6), bottom: Color(hex: 0xCDCCDA), limb: Color(hex: 0xDEDDE8),
                        outline: Color(hex: 0x54506A), ink: Color(hex: 0x2C2938), eyeHeight: 0.52, mouthOffset: 11)
        case .panda:
            return Look(top: .white, bottom: Color(hex: 0xE9E9EE), limb: Color(hex: 0x3A3A44),
                        outline: Color(hex: 0x3A3A44), ink: Color(hex: 0x26262C), eye: .white,
                        eyeHighlight: Color(hex: 0x3A3A44), eyeHeight: 0.52)
        case .bunny:
            return Look(top: Color(hex: 0xFFF8FA), bottom: Color(hex: 0xFFD6E0), limb: Color(hex: 0xFFE4EB),
                        outline: Color(hex: 0x8A5866), ink: Color(hex: 0x3A2229), eyeHeight: 0.52)
        case .frog:
            return Look(top: Color(hex: 0xC8EC9E), bottom: Color(hex: 0x8FCC66), limb: Color(hex: 0xA9DB80),
                        outline: Color(hex: 0x3E6A2D), ink: Color(hex: 0x22351A),
                        eyeHeight: 0.97, eyeSpacing: 19, blushSpacing: 28, mouthOffset: 27, blushOffset: 22)
        case .penguin:
            return Look(top: Color(hex: 0x4E5C7E), bottom: Color(hex: 0x33405C), limb: Color(hex: 0x3A4766),
                        foot: Color(hex: 0xFFA94D), outline: Color(hex: 0x1F2536), ink: Color(hex: 0x1F2433),
                        eyeHeight: 0.55, beak: Color(hex: 0xFFA94D))
        case .chick:
            return Look(top: Color(hex: 0xFFF2A6), bottom: Color(hex: 0xFFD65A), limb: Color(hex: 0xFFE07C),
                        foot: Color(hex: 0xFFA34D), outline: Color(hex: 0x9C6B1F), ink: Color(hex: 0x3B2A12),
                        eyeHeight: 0.52, beak: Color(hex: 0xFF9F43))
        case .toast:
            return Look(top: Color(hex: 0xF3B56E), bottom: Color(hex: 0xDE904B), limb: Color(hex: 0xF6D29A),
                        outline: Color(hex: 0x7A4A26), ink: Color(hex: 0x3B2416), shine: false,
                        eyeHeight: 0.50, shoulderY: 0.45)
        case .onigiri:
            return Look(top: .white, bottom: Color(hex: 0xF1ECE2), limb: Color(hex: 0xFFFDF8),
                        outline: Color(hex: 0x5B5348), ink: Color(hex: 0x2E2A25), shine: false,
                        eyeHeight: 0.42, eyeSpacing: 12, blushSpacing: 21, shoulderX: 0.31, shoulderY: 0.30)
        case .cactus:
            return Look(top: Color(hex: 0xADE29B), bottom: Color(hex: 0x6DBD72), limb: Color(hex: 0x8CD18A),
                        outline: Color(hex: 0x2E6A3A), ink: Color(hex: 0x1F3A22),
                        eyeHeight: 0.62, eyeSpacing: 12, blushSpacing: 20, shoulderX: 0.46, shoulderY: 0.48)
        }
    }

    // MARK: Body

    func bodyPath(w: CGFloat, h: CGFloat) -> Path {
        switch self {
        case .mochi:
            var p = Path()
            p.move(to: CGPoint(x: 0, y: -h))
            p.addCurve(to: CGPoint(x: w / 2, y: -h * 0.38), control1: CGPoint(x: w * 0.30, y: -h), control2: CGPoint(x: w / 2, y: -h * 0.72))
            p.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: w / 2, y: -h * 0.06), control2: CGPoint(x: w * 0.30, y: 0))
            p.addCurve(to: CGPoint(x: -w / 2, y: -h * 0.38), control1: CGPoint(x: -w * 0.30, y: 0), control2: CGPoint(x: -w / 2, y: -h * 0.06))
            p.addCurve(to: CGPoint(x: 0, y: -h), control1: CGPoint(x: -w / 2, y: -h * 0.72), control2: CGPoint(x: -w * 0.30, y: -h))
            p.closeSubpath()
            return p
        case .toast:
            return Self.bread(w: w, h: h)
        case .onigiri:
            var p = Path()
            let top = CGPoint(x: 0, y: -h), left = CGPoint(x: -w / 2, y: 0), right = CGPoint(x: w / 2, y: 0)
            p.move(to: CGPoint(x: 0, y: 0))
            p.addArc(tangent1End: right, tangent2End: top, radius: 16)
            p.addArc(tangent1End: top, tangent2End: left, radius: 24)
            p.addArc(tangent1End: left, tangent2End: right, radius: 16)
            p.closeSubpath()
            return p
        case .cactus:
            return Path(roundedRect: CGRect(x: -w / 2, y: -h, width: w, height: h), cornerRadius: w / 2 - 2)
        default:
            return Self.superellipse(a: w / 2, b: h / 2, n: 2.5, centerY: -h / 2)
        }
    }

    private static func superellipse(a: CGFloat, b: CGFloat, n: Double, centerY: CGFloat) -> Path {
        var p = Path()
        let steps = 120
        for i in 0...steps {
            let t = Double(i) / Double(steps) * 2 * .pi
            let c = cos(t), s = sin(t)
            let point = CGPoint(x: a * CGFloat(copysign(pow(abs(c), 2 / n), c)),
                                y: centerY + b * CGFloat(copysign(pow(abs(s), 2 / n), s)))
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }

    /// A slice of bread: straight sides and a wide, two-lobed top that overhangs a little.
    private static func bread(w: CGFloat, h: CGFloat) -> Path {
        var p = Path()
        let r = w / 2
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: r - 10, y: 0))
        p.addQuadCurve(to: CGPoint(x: r - 3, y: -10), control: CGPoint(x: r - 3, y: 0))
        p.addLine(to: CGPoint(x: r - 3, y: -h * 0.58))
        p.addCurve(to: CGPoint(x: r * 0.42, y: -h), control1: CGPoint(x: r + 9, y: -h * 0.66), control2: CGPoint(x: r + 3, y: -h))
        p.addCurve(to: CGPoint(x: 0, y: -h * 0.95), control1: CGPoint(x: r * 0.22, y: -h), control2: CGPoint(x: r * 0.1, y: -h * 0.95))
        p.addCurve(to: CGPoint(x: -r * 0.42, y: -h), control1: CGPoint(x: -r * 0.1, y: -h * 0.95), control2: CGPoint(x: -r * 0.22, y: -h))
        p.addCurve(to: CGPoint(x: -r + 3, y: -h * 0.58), control1: CGPoint(x: -r - 3, y: -h), control2: CGPoint(x: -r - 9, y: -h * 0.66))
        p.addLine(to: CGPoint(x: -r + 3, y: -10))
        p.addQuadCurve(to: CGPoint(x: -r + 10, y: 0), control: CGPoint(x: -r + 3, y: 0))
        p.closeSubpath()
        return p
    }

    // MARK: Details

    /// Drawn before the body, so the body overlaps them: ears, sprouts, eye bumps.
    func drawBehind(_ b: inout GraphicsContext, _ f: BuddyFrame) {
        let h = f.h, look = f.look
        switch self {
        case .mochi:
            var s = b
            s.translateBy(x: 0, y: -h + 3)
            s.rotate(by: .degrees(f.pose.sproutSway - f.pose.tilt * 0.6))
            var stem = Path()
            stem.move(to: .zero)
            stem.addQuadCurve(to: CGPoint(x: 1, y: -15), control: CGPoint(x: -3, y: -8))
            s.stroke(stem, with: .color(Palette.leafDark), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            for dir in [-1.0, 1.0] {
                var l = s
                l.translateBy(x: 1, y: -15)
                l.rotate(by: .degrees(dir * 52))
                var leaf = Path()
                leaf.move(to: .zero)
                leaf.addQuadCurve(to: CGPoint(x: 0, y: -14), control: CGPoint(x: 7, y: -7))
                leaf.addQuadCurve(to: .zero, control: CGPoint(x: -7, y: -7))
                l.fill(leaf, with: .color(Palette.leaf))
                l.stroke(leaf, with: .color(Palette.leafDark), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))
            }
        case .cat:
            for side: CGFloat in [-1, 1] {
                var ear = Path()
                ear.move(to: CGPoint(x: side * 8, y: -h + 6))
                ear.addLine(to: CGPoint(x: side * 33, y: -h - 15))
                ear.addLine(to: CGPoint(x: side * 41, y: -h + 20))
                ear.closeSubpath()
                b.fill(ear, with: .color(look.top))
                b.stroke(ear, with: .color(look.outline), style: f.line)
                var inner = Path()
                inner.move(to: CGPoint(x: side * 15, y: -h + 4))
                inner.addLine(to: CGPoint(x: side * 31, y: -h - 7))
                inner.addLine(to: CGPoint(x: side * 36, y: -h + 13))
                inner.closeSubpath()
                b.fill(inner, with: .color(Color(hex: 0xFFB8C8)))
            }
        case .panda:
            for side: CGFloat in [-1, 1] {
                let ear = Path(ellipseIn: CGRect(x: side * 30 - 12, y: -h - 4, width: 24, height: 24))
                b.fill(ear, with: .color(look.limb))
            }
        case .bunny:
            for side: CGFloat in [-1, 1] {
                var e = b
                e.translateBy(x: side * 15, y: -h + 8)
                e.rotate(by: .degrees(Double(side) * 9 + f.pose.sproutSway * 0.6))
                let outer = Path(roundedRect: CGRect(x: -8, y: -36, width: 16, height: 40), cornerRadius: 8)
                e.fill(outer, with: .color(look.top))
                e.stroke(outer, with: .color(look.outline), style: f.line)
                e.fill(Path(roundedRect: CGRect(x: -4, y: -30, width: 8, height: 26), cornerRadius: 4),
                       with: .color(Color(hex: 0xFFB3C7)))
            }
        case .frog:
            for side: CGFloat in [-1, 1] {
                let bump = Path(ellipseIn: CGRect(x: side * look.eyeSpacing - 14, y: -h * look.eyeHeight - 13, width: 28, height: 26))
                b.fill(bump, with: .color(look.top))
                b.stroke(bump, with: .color(look.outline), style: f.line)
            }
        default:
            break
        }
    }

    /// Drawn on the body and clipped to it: bellies, patches, crumb, nori.
    func drawOnBody(_ b: inout GraphicsContext, _ f: BuddyFrame) {
        let w = f.w, h = f.h, look = f.look
        let fx = CGFloat(f.pose.faceShiftX)
        switch self {
        case .mochi:
            b.fill(Path(ellipseIn: CGRect(x: -22, y: -30, width: 44, height: 24)), with: .color(.white.opacity(0.28)))
        case .cat, .bunny, .chick:
            b.fill(Path(ellipseIn: CGRect(x: -21, y: -28, width: 42, height: 22)), with: .color(.white.opacity(0.4)))
            if self == .cat {
                for x: CGFloat in [-7, 0, 7] {
                    var stripe = Path()
                    stripe.move(to: CGPoint(x: x + fx * 0.5, y: -h + 2))
                    stripe.addLine(to: CGPoint(x: x + fx * 0.5, y: -h + (x == 0 ? 13 : 10)))
                    b.stroke(stripe, with: .color(look.outline.opacity(0.45)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                }
            }
        case .panda:
            for side: CGFloat in [-1, 1] {
                var patch = b
                patch.translateBy(x: side * look.eyeSpacing + fx, y: f.eyeY + 1)
                patch.rotate(by: .degrees(Double(side) * -24))
                patch.fill(Path(ellipseIn: CGRect(x: -8.5, y: -11, width: 17, height: 22)), with: .color(look.limb))
            }
        case .frog:
            b.fill(Path(ellipseIn: CGRect(x: -25, y: -30, width: 50, height: 26)), with: .color(Color(hex: 0xF1FAD9).opacity(0.75)))
        case .penguin:
            b.fill(Path(ellipseIn: CGRect(x: -31 + fx * 0.5, y: -h * 0.80, width: 62, height: h * 0.80 - 3)), with: .color(.white))
        case .toast:
            let crumb = bodyPath(w: w, h: h).applying(
                CGAffineTransform(translationX: 0, y: -h / 2).scaledBy(x: 0.8, y: 0.8).translatedBy(x: 0, y: h / 2))
            b.fill(crumb, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFEDC8), Color(hex: 0xFFDDA2)]),
                                                startPoint: CGPoint(x: 0, y: -h), endPoint: .zero))
        case .onigiri:
            b.fill(Path(roundedRect: CGRect(x: -19, y: -21, width: 38, height: 24), cornerRadius: 3), with: .color(Color(hex: 0x2C3A33)))
            b.fill(Path(roundedRect: CGRect(x: -14, y: -17, width: 9, height: 2), cornerRadius: 1), with: .color(.white.opacity(0.18)))
        case .cactus:
            for x: CGFloat in [-12, 12] {
                var rib = Path()
                rib.move(to: CGPoint(x: x, y: -h + 20))
                rib.addLine(to: CGPoint(x: x, y: -8))
                b.stroke(rib, with: .color(look.outline.opacity(0.16)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        }
    }

    /// Drawn on top of the body, not clipped: whiskers, tufts, flowers, spikes.
    func drawFront(_ b: inout GraphicsContext, _ f: BuddyFrame) {
        let h = f.h, look = f.look
        let fx = CGFloat(f.pose.faceShiftX)
        switch self {
        case .cat:
            for side: CGFloat in [-1, 1] {
                for (dy0, dy1) in [(11.0, 8.0), (14.0, 16.0)] {
                    var whisker = Path()
                    whisker.move(to: CGPoint(x: side * 23 + fx, y: f.eyeY + dy0))
                    whisker.addLine(to: CGPoint(x: side * 41 + fx, y: f.eyeY + dy1))
                    b.stroke(whisker, with: .color(look.outline.opacity(0.7)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                }
            }
            b.fill(Path(ellipseIn: CGRect(x: fx - 3, y: f.eyeY + 5, width: 6, height: 4)), with: .color(Color(hex: 0xFF9AAE)))
        case .chick:
            for (x0, x1, y1) in [(-3.0, -7.0, -9.0), (0.0, 1.0, -12.0), (3.0, 8.0, -8.0)] {
                var tuft = Path()
                tuft.move(to: CGPoint(x: x0, y: -h + 2))
                tuft.addQuadCurve(to: CGPoint(x: x1, y: -h + y1), control: CGPoint(x: (x0 + x1) / 2 + 3, y: -h + y1 / 2))
                b.stroke(tuft, with: .color(look.outline), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }
        case .cactus:
            for (x, y) in [(-17.0, -72.0), (16.0, -62.0), (-18.0, -34.0), (19.0, -24.0), (-4.0, -14.0)] {
                var spike = Path()
                spike.move(to: CGPoint(x: x - 2.5, y: y + 2))
                spike.addLine(to: CGPoint(x: x, y: y - 1.5))
                spike.addLine(to: CGPoint(x: x + 2.5, y: y + 2))
                b.stroke(spike, with: .color(look.outline.opacity(0.55)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            }
            var flower = b
            flower.translateBy(x: 4, y: -h + 1)
            flower.rotate(by: .degrees(f.pose.sproutSway * 1.5))
            for k in 0..<5 {
                let angle = Double(k) / 5 * 2 * .pi
                let petal = Path(ellipseIn: CGRect(x: cos(angle) * 5.5 - 4.5, y: sin(angle) * 5.5 - 4.5, width: 9, height: 9))
                flower.fill(petal, with: .color(Color(hex: 0xFF8FB1)))
                flower.stroke(petal, with: .color(Color(hex: 0xC2557A)), style: StrokeStyle(lineWidth: 1.2))
            }
            flower.fill(Path(ellipseIn: CGRect(x: -3.5, y: -3.5, width: 7, height: 7)), with: .color(Color(hex: 0xFFD54F)))
        default:
            break
        }
    }
}

/// Colours and face layout for one buddy.
struct Look {
    var top: Color
    var bottom: Color
    var limb: Color
    var foot: Color? = nil
    var outline: Color
    var ink = Palette.ink
    var eye: Color? = nil
    var eyeHighlight = Color.white
    var blush = 1.0
    var shine = true
    var eyeHeight: CGFloat = 0.56   // fraction of the body height, from the bottom
    var eyeSpacing: CGFloat = 15
    var blushSpacing: CGFloat = 27
    var shoulderX: CGFloat = 0.42   // fraction of the body width
    var shoulderY: CGFloat = 0.50   // fraction of the body height
    var mouthOffset: CGFloat = 9
    var blushOffset: CGFloat = 8
    var beak: Color? = nil
}

/// Everything the detail drawers need to know about the current frame.
struct BuddyFrame {
    let w: CGFloat
    let h: CGFloat
    let pose: Pose
    let look: Look
    let line: StrokeStyle
    var eyeY: CGFloat { -h * look.eyeHeight }
}
