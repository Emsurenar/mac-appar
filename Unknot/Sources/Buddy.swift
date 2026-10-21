import SwiftUI

// The little mochi buddy, drawn with Canvas so every pose can be animated freely.

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum Palette {
    static let bodyTop = Color(hex: 0xFFEBDA)
    static let bodyBottom = Color(hex: 0xFFC4A2)
    static let limb = Color(hex: 0xFFD2B8)
    static let outline = Color(hex: 0x7A4B37)
    static let ink = Color(hex: 0x3B2620)
    static let blush = Color(hex: 0xFF8C9E)
    static let leaf = Color(hex: 0x8FD072)
    static let leafDark = Color(hex: 0x4E8C3A)
}

enum Eyes { case open, happy }
enum Mouth { case smile, open, o }

struct Pose {
    var tilt = 0.0          // degrees; the whole body leans around the feet
    var lift = 0.0          // jump height in points
    var scaleX = 1.0
    var scaleY = 1.0
    var leftArm = 30.0      // degrees: 0 hangs down, positive raises outwards, negative crosses in front
    var rightArm = 30.0
    var shoulderLift = 0.0
    var faceShiftX = 0.0
    var lookX = 0.0
    var eyes = Eyes.open
    var mouth = Mouth.smile
    var blush = 0.55
    var sproutSway = 0.0
}

func pose(for move: Move, at t: Double) -> Pose {
    var p = Pose()
    p.sproutSway = sin(t * 2.2) * 7
    func wave(_ speed: Double) -> Double { (sin(t * speed) + 1) / 2 }

    switch move {
    case .armsUp:
        let s = wave(1.6)
        p.leftArm = 158 + s * 12; p.rightArm = p.leftArm
        p.scaleY = 1 + 0.08 * s; p.scaleX = 1 - 0.04 * s
        p.eyes = .happy; p.mouth = s > 0.6 ? .open : .smile
    case .sideBend:
        let s = sin(t * 1.2)
        p.tilt = s * 13
        p.leftArm = 30 + max(0, s) * 135
        p.rightArm = 30 + max(0, -s) * 135
        p.eyes = .happy
    case .neckTilt:
        p.tilt = sin(t * 0.9) * 9
        p.faceShiftX = sin(t * 0.9) * 3
        p.leftArm = 24; p.rightArm = 24
        p.eyes = .happy
    case .shoulderRoll:
        let a = t * 3.4
        p.shoulderLift = (sin(a) + 1) * 3.5
        p.leftArm = 30 + cos(a) * 9; p.rightArm = p.leftArm
        p.scaleY = 1 + sin(a) * 0.015
    case .twist:
        let s = sin(t * 1.5)
        p.faceShiftX = s * 11
        p.scaleX = 1 - abs(s) * 0.05
        p.leftArm = 42 - s * 24; p.rightArm = 42 + s * 24
    case .breathe:
        let s = wave(2 * .pi / 8)
        p.scaleX = 1 + 0.07 * s; p.scaleY = 1 + 0.05 * s
        p.leftArm = 26 + s * 26; p.rightArm = p.leftArm
        p.eyes = .happy; p.mouth = .o
    case .lookAway:
        let look = max(-1, min(1, sin(t * 0.8) * 2.5)) * 3.2
        p.lookX = look; p.faceShiftX = look * 0.8
        p.rightArm = -150 + sin(t * 2) * 3
        p.leftArm = 26
    case .armsWide:
        let s = wave(1.8)
        p.leftArm = 92 + s * 18; p.rightArm = p.leftArm
        p.scaleY = 1 + 0.03 * s; p.mouth = .open
    case .calfRaise:
        let h = abs(sin(t * 3))
        p.lift = h * 12; p.scaleY = 1 + h * 0.04
        p.leftArm = 24 + h * 16; p.rightArm = p.leftArm
        p.mouth = h > 0.5 ? .open : .smile
    case .wristCircles:
        p.leftArm = 68 + sin(t * 7) * 12; p.rightArm = 68 + cos(t * 7) * 12
    case .wiggle:
        p.tilt = sin(t * 9) * 5
        p.leftArm = 55 + sin(t * 11) * 28; p.rightArm = 55 + cos(t * 11) * 28
        p.eyes = .happy; p.mouth = .open
    case .hug:
        p.leftArm = -58 + sin(t * 2) * 4; p.rightArm = p.leftArm
        p.scaleX = 0.97 + sin(t * 2) * 0.01
        p.tilt = sin(t * 1.3) * 4
        p.eyes = .happy; p.blush = 0.95
    case .celebrate:
        let h = abs(sin(t * 5))
        p.lift = h * 14
        p.leftArm = 148 + sin(t * 10) * 16; p.rightArm = 148 - sin(t * 10) * 16
        p.eyes = .happy; p.mouth = .open
    case .wave:
        p.rightArm = 145 + sin(t * 7) * 20
        p.leftArm = 26
        p.tilt = sin(t * 1.6) * 3
        p.mouth = .open
    }
    return p
}

/// Draws the buddy in a 150×150 coordinate space.
func drawBuddy(_ ctx: inout GraphicsContext, _ p: Pose, t: Double) {
    let ground: CGFloat = 141
    let cx: CGFloat = 75
    let lift = CGFloat(p.lift)
    let line = StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)

    // Shadow
    let sw = 74 - lift * 1.8
    ctx.fill(Path(ellipseIn: CGRect(x: cx - sw / 2, y: ground - 3, width: sw, height: 7)),
             with: .color(.black.opacity(0.12)))

    // Feet
    for dx: CGFloat in [-16, 16] {
        let foot = Path(ellipseIn: CGRect(x: cx + dx - 11, y: ground - 10 - lift, width: 22, height: 12))
        ctx.fill(foot, with: .color(Palette.limb))
        ctx.stroke(foot, with: .color(Palette.outline), style: line)
    }

    // Body space: origin at the bottom centre of the body
    var b = ctx
    b.translateBy(x: cx, y: ground - 6 - lift)
    b.rotate(by: .degrees(p.tilt))
    b.scaleBy(x: CGFloat(p.scaleX), y: CGFloat(p.scaleY))

    let w: CGFloat = 88, h: CGFloat = 86

    // Sprout
    var s = b
    s.translateBy(x: 0, y: -h + 3)
    s.rotate(by: .degrees(p.sproutSway - p.tilt * 0.6))
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

    // Arms: outward arms go behind the body, inward ones (hug, salute) in front
    let shoulderY = -h * 0.50 - CGFloat(p.shoulderLift)
    let shoulderX = w * 0.42
    func arm(x: CGFloat, angle: Double) {
        var a = b
        a.translateBy(x: x, y: shoulderY)
        a.rotate(by: .degrees(angle))
        // Raised arms get longer so they reach above the head
        let outward = (x < 0) == (angle > 0)
        let reach = outward ? min(max((abs(angle) - 90) / 70, 0), 1) * 20 : 0
        let path = Path(roundedRect: CGRect(x: -6.5, y: -5, width: 13, height: 33 + reach), cornerRadius: 6.5)
        a.fill(path, with: .color(Palette.limb))
        a.stroke(path, with: .color(Palette.outline), style: line)
    }
    if p.leftArm >= 0 { arm(x: -shoulderX, angle: p.leftArm) }
    if p.rightArm >= 0 { arm(x: shoulderX, angle: -p.rightArm) }

    // Body
    var body = Path()
    body.move(to: CGPoint(x: 0, y: -h))
    body.addCurve(to: CGPoint(x: w / 2, y: -h * 0.38), control1: CGPoint(x: w * 0.30, y: -h), control2: CGPoint(x: w / 2, y: -h * 0.72))
    body.addCurve(to: CGPoint(x: 0, y: 0), control1: CGPoint(x: w / 2, y: -h * 0.06), control2: CGPoint(x: w * 0.30, y: 0))
    body.addCurve(to: CGPoint(x: -w / 2, y: -h * 0.38), control1: CGPoint(x: -w * 0.30, y: 0), control2: CGPoint(x: -w / 2, y: -h * 0.06))
    body.addCurve(to: CGPoint(x: 0, y: -h), control1: CGPoint(x: -w / 2, y: -h * 0.72), control2: CGPoint(x: -w * 0.30, y: -h))
    body.closeSubpath()
    b.fill(body, with: .linearGradient(Gradient(colors: [Palette.bodyTop, Palette.bodyBottom]),
                                       startPoint: CGPoint(x: 0, y: -h), endPoint: .zero))
    b.stroke(body, with: .color(Palette.outline), style: StrokeStyle(lineWidth: 2.6, lineJoin: .round))
    b.fill(Path(ellipseIn: CGRect(x: -22, y: -30, width: 44, height: 24)), with: .color(.white.opacity(0.28)))
    var shine = b
    shine.translateBy(x: -22, y: -h * 0.78)
    shine.rotate(by: .degrees(-32))
    shine.fill(Path(ellipseIn: CGRect(x: -7, y: -4, width: 14, height: 8)), with: .color(.white.opacity(0.65)))

    // Face
    let fx = CGFloat(p.faceShiftX)
    let eyeY = -h * 0.56
    let blink = p.eyes == .open && fmod(t, 3.8) < 0.14
    for side: CGFloat in [-1, 1] {
        let ex = fx + side * 15 + CGFloat(p.lookX)
        if p.eyes == .happy || blink {
            var e = Path()
            if blink {
                e.move(to: CGPoint(x: ex - 4.5, y: eyeY))
                e.addLine(to: CGPoint(x: ex + 4.5, y: eyeY))
            } else {
                e.move(to: CGPoint(x: ex - 5, y: eyeY + 2))
                e.addQuadCurve(to: CGPoint(x: ex + 5, y: eyeY + 2), control: CGPoint(x: ex, y: eyeY - 5))
            }
            b.stroke(e, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
        } else {
            b.fill(Path(ellipseIn: CGRect(x: ex - 4.6, y: eyeY - 5.6, width: 9.2, height: 11.2)), with: .color(Palette.ink))
            b.fill(Path(ellipseIn: CGRect(x: ex - 2.6 + CGFloat(p.lookX) * 0.3, y: eyeY - 4.4, width: 3.6, height: 3.6)),
                   with: .color(.white))
        }
        b.fill(Path(ellipseIn: CGRect(x: fx * 0.85 + side * 27 - 7, y: eyeY + 8, width: 14, height: 8)),
               with: .color(Palette.blush.opacity(p.blush)))
    }

    let my = eyeY + 9
    switch p.mouth {
    case .smile:
        var m = Path()
        m.move(to: CGPoint(x: fx - 5, y: my))
        m.addQuadCurve(to: CGPoint(x: fx + 5, y: my), control: CGPoint(x: fx, y: my + 6))
        b.stroke(m, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
    case .open:
        var m = Path()
        m.move(to: CGPoint(x: fx - 6, y: my - 1))
        m.addLine(to: CGPoint(x: fx + 6, y: my - 1))
        m.addQuadCurve(to: CGPoint(x: fx - 6, y: my - 1), control: CGPoint(x: fx, y: my + 11))
        m.closeSubpath()
        b.fill(m, with: .color(Palette.ink))
        b.fill(Path(ellipseIn: CGRect(x: fx - 3, y: my + 2.2, width: 6, height: 3.4)), with: .color(Palette.blush))
    case .o:
        b.fill(Path(ellipseIn: CGRect(x: fx - 3, y: my - 1, width: 6, height: 7)), with: .color(Palette.ink))
    }

    if p.leftArm < 0 { arm(x: -shoulderX, angle: p.leftArm) }
    if p.rightArm < 0 { arm(x: shoulderX, angle: -p.rightArm) }
}

/// Animated buddy. Pass `fixedTime` to draw a single still frame (previews, lists).
struct BuddyView: View {
    let move: Move
    var fixedTime: Double? = nil

    var body: some View {
        Group {
            if let t = fixedTime {
                canvas(t)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { tl in canvas(tl.date.timeIntervalSinceReferenceDate) }
            }
        }
        .accessibilityHidden(true)
    }

    private func canvas(_ t: Double) -> some View {
        Canvas { ctx, size in
            let k = min(size.width, size.height) / 150
            ctx.translateBy(x: (size.width - 150 * k) / 2, y: (size.height - 150 * k) / 2)
            ctx.scaleBy(x: k, y: k)
            drawBuddy(&ctx, pose(for: move, at: t), t: t)
        }
    }
}
