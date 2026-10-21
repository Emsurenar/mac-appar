import SwiftUI

/// The Stretch Crew. Every member shares the face, arms and moves, but has its own body and details.
/// The style is flat and quiet: no outlines, one soft form shadow, small features, a muted palette.
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
        case .mochi: return CGSize(width: 86, height: 86)
        case .bunny: return CGSize(width: 86, height: 76)
        case .toast: return CGSize(width: 84, height: 84)
        case .onigiri: return CGSize(width: 100, height: 92)
        case .cactus: return CGSize(width: 58, height: 92)
        default: return CGSize(width: 88, height: 80)
        }
    }

    var look: Look {
        switch self {
        case .mochi:
            return Look(body: Color(hex: 0xEDB892), limb: Color(hex: 0xD49A73), belly: Color(hex: 0xF5D2B6))
        case .cat:
            return Look(body: Color(hex: 0x9198A6), limb: Color(hex: 0x767D8B), belly: Color(hex: 0xB7BCC6),
                        eyeHeight: 0.52, mouthOffset: 10)
        case .panda:
            return Look(body: Color(hex: 0xF2EEE7), limb: Color(hex: 0x3B3B40), edge: Color(hex: 0xD9D3C8),
                        eye: Color(hex: 0xF2EEE7), eyeHeight: 0.52)
        case .bunny:
            return Look(body: Color(hex: 0xE9D3C8), limb: Color(hex: 0xD3B9AC), belly: Color(hex: 0xF3E6DF),
                        eyeHeight: 0.52)
        case .frog:
            return Look(body: Color(hex: 0x8DB57F), limb: Color(hex: 0x739D66), belly: Color(hex: 0xB9D4AA),
                        eyeHeight: 0.97, eyeSpacing: 18, mouthOffset: 26)
        case .penguin:
            return Look(body: Color(hex: 0x3F4B62), limb: Color(hex: 0x323D52), belly: Color(hex: 0xF2EEE7),
                        foot: Color(hex: 0xE5A03C), eyeHeight: 0.55, beak: Color(hex: 0xE5A03C))
        case .chick:
            return Look(body: Color(hex: 0xF0C153), limb: Color(hex: 0xDCA83A), belly: Color(hex: 0xF6D688),
                        foot: Color(hex: 0xDE7D43), eyeHeight: 0.52, beak: Color(hex: 0xDE7D43))
        case .toast:
            return Look(body: Color(hex: 0xCF8A50), limb: Color(hex: 0xBB7642), eyeHeight: 0.50, shoulderY: 0.45)
        case .onigiri:
            return Look(body: Color(hex: 0xF3F0E9), limb: Color(hex: 0xCFC6B6), edge: Color(hex: 0xD6CEC0),
                        eyeHeight: 0.42, eyeSpacing: 11, shoulderX: 0.31, shoulderY: 0.30)
        case .cactus:
            return Look(body: Color(hex: 0x82AF80), limb: Color(hex: 0x6C9A6B),
                        eyeHeight: 0.62, eyeSpacing: 11, shoulderX: 0.46, shoulderY: 0.48)
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
            stem.addQuadCurve(to: CGPoint(x: 1, y: -14), control: CGPoint(x: -3, y: -7))
            s.stroke(stem, with: .color(Color(hex: 0x6E9468)), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            for (dir, color) in [(-1.0, 0x86AE7E), (1.0, 0x9CC093)] as [(Double, UInt32)] {
                var l = s
                l.translateBy(x: 1, y: -14)
                l.rotate(by: .degrees(dir * 55))
                var leaf = Path()
                leaf.move(to: .zero)
                leaf.addQuadCurve(to: CGPoint(x: 0, y: -13), control: CGPoint(x: 6.5, y: -6.5))
                leaf.addQuadCurve(to: .zero, control: CGPoint(x: -6.5, y: -6.5))
                l.fill(leaf, with: .color(Color(hex: color)))
            }
        case .cat:
            for side: CGFloat in [-1, 1] {
                var ear = Path()
                ear.move(to: CGPoint(x: side * 8, y: -h + 6))
                ear.addLine(to: CGPoint(x: side * 32, y: -h - 14))
                ear.addLine(to: CGPoint(x: side * 40, y: -h + 20))
                ear.closeSubpath()
                b.fill(ear, with: .color(look.body))
                var inner = Path()
                inner.move(to: CGPoint(x: side * 16, y: -h + 4))
                inner.addLine(to: CGPoint(x: side * 30, y: -h - 6))
                inner.addLine(to: CGPoint(x: side * 35, y: -h + 12))
                inner.closeSubpath()
                b.fill(inner, with: .color(Color(hex: 0xD6A596)))
            }
        case .panda:
            for side: CGFloat in [-1, 1] {
                b.fill(Path(ellipseIn: CGRect(x: side * 29 - 11.5, y: -h - 3, width: 23, height: 23)), with: .color(look.limb))
            }
        case .bunny:
            for side: CGFloat in [-1, 1] {
                var e = b
                e.translateBy(x: side * 15, y: -h + 8)
                e.rotate(by: .degrees(Double(side) * 9 + f.pose.sproutSway * 0.6))
                e.fill(Path(roundedRect: CGRect(x: -8, y: -36, width: 16, height: 40), cornerRadius: 8), with: .color(look.body))
                e.fill(Path(roundedRect: CGRect(x: -3.5, y: -30, width: 7, height: 26), cornerRadius: 3.5),
                       with: .color(Color(hex: 0xD7A493)))
            }
        case .frog:
            for side: CGFloat in [-1, 1] {
                b.fill(Path(ellipseIn: CGRect(x: side * look.eyeSpacing - 13, y: f.eyeY - 12, width: 26, height: 24)),
                       with: .color(look.body))
            }
        default:
            break
        }
    }

    /// Drawn on the body and clipped to it: bellies, patches, crumb, nori.
    func drawOnBody(_ b: inout GraphicsContext, _ f: BuddyFrame) {
        let w = f.w, h = f.h, look = f.look
        let fx = CGFloat(f.pose.faceShiftX)
        if let belly = look.belly, self != .penguin {
            b.fill(Path(ellipseIn: CGRect(x: -w * 0.27, y: -h * 0.36, width: w * 0.54, height: h * 0.30)), with: .color(belly))
        }
        switch self {
        case .cat:
            for x: CGFloat in [-7, 0, 7] {
                var stripe = Path()
                stripe.move(to: CGPoint(x: x + fx * 0.5, y: -h + 1))
                stripe.addLine(to: CGPoint(x: x + fx * 0.5, y: -h + (x == 0 ? 12 : 9)))
                b.stroke(stripe, with: .color(look.limb), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }
        case .panda:
            for side: CGFloat in [-1, 1] {
                var patch = b
                patch.translateBy(x: side * look.eyeSpacing + fx, y: f.eyeY + 1)
                patch.rotate(by: .degrees(Double(side) * -22))
                patch.fill(Path(ellipseIn: CGRect(x: -8, y: -10.5, width: 16, height: 21)), with: .color(look.limb))
            }
        case .penguin:
            b.fill(Path(ellipseIn: CGRect(x: -30 + fx * 0.5, y: -h * 0.80, width: 60, height: h * 0.80 - 3)),
                   with: .color(look.belly ?? .white))
        case .toast:
            let crumb = bodyPath(w: w, h: h).applying(
                CGAffineTransform(translationX: 0, y: -h / 2).scaledBy(x: 0.8, y: 0.8).translatedBy(x: 0, y: h / 2))
            b.fill(crumb, with: .color(Color(hex: 0xF3D6A5)))
        case .onigiri:
            b.fill(Path(roundedRect: CGRect(x: -18, y: -20, width: 36, height: 23), cornerRadius: 2.5), with: .color(Color(hex: 0x2F3532)))
        case .cactus:
            for x: CGFloat in [-11, 11] {
                var rib = Path()
                rib.move(to: CGPoint(x: x, y: -h + 20))
                rib.addLine(to: CGPoint(x: x, y: -8))
                b.stroke(rib, with: .color(look.limb.opacity(0.55)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        default:
            break
        }
        // One soft form shadow on the right-hand side gives the flat shapes some volume.
        var shade = b
        shade.addFilter(.blur(radius: 9))
        shade.fill(Path(ellipseIn: CGRect(x: w * 0.18, y: -h * 1.1, width: w * 0.9, height: h * 1.3)), with: .color(.black.opacity(0.08)))
    }

    /// Drawn on top of the body, not clipped: noses, tufts, flowers, spikes.
    func drawFront(_ b: inout GraphicsContext, _ f: BuddyFrame) {
        let h = f.h, look = f.look
        let fx = CGFloat(f.pose.faceShiftX)
        switch self {
        case .cat:
            b.fill(Path(ellipseIn: CGRect(x: fx - 2.5, y: f.eyeY + 5, width: 5, height: 3.5)), with: .color(Color(hex: 0xC98E80)))
        case .chick:
            for (x0, x1, y1) in [(-3.0, -6.0, -8.0), (0.0, 1.0, -11.0), (3.0, 7.0, -7.0)] {
                var tuft = Path()
                tuft.move(to: CGPoint(x: x0, y: -h + 2))
                tuft.addQuadCurve(to: CGPoint(x: x1, y: -h + y1), control: CGPoint(x: (x0 + x1) / 2 + 3, y: -h + y1 / 2))
                b.stroke(tuft, with: .color(look.limb), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }
        case .cactus:
            for (x, y) in [(-16.0, -70.0), (15.0, -60.0), (-17.0, -34.0), (18.0, -24.0), (-2.0, -14.0)] {
                b.fill(Path(ellipseIn: CGRect(x: x - 1.3, y: y - 1.3, width: 2.6, height: 2.6)), with: .color(Color(hex: 0xC7DFC2)))
            }
            var flower = b
            flower.translateBy(x: 4, y: -h + 1)
            flower.rotate(by: .degrees(f.pose.sproutSway * 1.5))
            for k in 0..<5 {
                let angle = Double(k) / 5 * 2 * .pi
                flower.fill(Path(ellipseIn: CGRect(x: cos(angle) * 5 - 4.2, y: sin(angle) * 5 - 4.2, width: 8.4, height: 8.4)),
                            with: .color(Color(hex: 0xDE7B5E)))
            }
            flower.fill(Path(ellipseIn: CGRect(x: -3, y: -3, width: 6, height: 6)), with: .color(Color(hex: 0xF0C153)))
        default:
            break
        }
    }
}

/// Colours and face layout for one member of the crew.
struct Look {
    var body: Color
    var limb: Color                 // arms, feet and ears: a shade darker than the body
    var belly: Color? = nil
    var foot: Color? = nil
    var edge: Color? = nil          // a hairline in the body's own tone, for pale bodies on pale backgrounds
    var ink = Color(hex: 0x2A2A2E)
    var eye: Color? = nil
    var eyeHeight: CGFloat = 0.56   // fraction of the body height, from the bottom
    var eyeSpacing: CGFloat = 13
    var shoulderX: CGFloat = 0.42   // fraction of the body width
    var shoulderY: CGFloat = 0.50   // fraction of the body height
    var mouthOffset: CGFloat = 9
    var beak: Color? = nil
}

/// Everything the detail drawers need to know about the current frame.
struct BuddyFrame {
    let w: CGFloat
    let h: CGFloat
    let pose: Pose
    let look: Look
    var eyeY: CGFloat { -h * look.eyeHeight }
}
