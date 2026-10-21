import SwiftUI

// Poses and the drawing every member of the Stretch Crew shares, done with Canvas so any pose can be animated.

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
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
        p.eyes = .happy
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

/// Draws a member of the crew in a 150×150 coordinate space.
func drawBuddy(_ ctx: inout GraphicsContext, _ p: Pose, t: Double, buddy: Buddy = .mochi) {
    let look = buddy.look
    let ground: CGFloat = 141
    let cx: CGFloat = 75
    let lift = CGFloat(p.lift)

    // Ground shadow
    let sw = 64 - lift * 1.6
    ctx.fill(Path(ellipseIn: CGRect(x: cx - sw / 2, y: ground - 2.5, width: sw, height: 6)),
             with: .color(.black.opacity(0.09)))

    // Feet
    for dx: CGFloat in [-15, 15] {
        ctx.fill(Path(ellipseIn: CGRect(x: cx + dx - 9.5, y: ground - 9 - lift, width: 19, height: 10)),
                 with: .color(look.foot ?? look.limb))
    }

    // Body space: origin at the bottom centre of the body
    var b = ctx
    b.translateBy(x: cx, y: ground - 6 - lift)
    b.rotate(by: .degrees(p.tilt))
    b.scaleBy(x: CGFloat(p.scaleX), y: CGFloat(p.scaleY))

    let w = buddy.size.width, h = buddy.size.height
    let frame = BuddyFrame(w: w, h: h, pose: p, look: look)
    buddy.drawBehind(&b, frame)

    // Arms: outward arms go behind the body, inward ones (hug, salute) in front
    let shoulderY = -h * look.shoulderY - CGFloat(p.shoulderLift)
    let shoulderX = w * look.shoulderX
    func arm(x: CGFloat, angle: Double) {
        var a = b
        a.translateBy(x: x, y: shoulderY)
        a.rotate(by: .degrees(angle))
        // Raised arms get longer so they reach above the head
        let outward = (x < 0) == (angle > 0)
        let reach = outward ? min(max((abs(angle) - 90) / 70, 0), 1) * 20 : 0
        a.fill(Path(roundedRect: CGRect(x: -5.5, y: -5, width: 11, height: 32 + reach), cornerRadius: 5.5),
               with: .color(look.limb))
    }
    if p.leftArm >= 0 { arm(x: -shoulderX, angle: p.leftArm) }
    if p.rightArm >= 0 { arm(x: shoulderX, angle: -p.rightArm) }

    // Body
    let body = buddy.bodyPath(w: w, h: h)
    b.fill(body, with: .color(look.body))
    var onBody = b
    onBody.clip(to: body)
    buddy.drawOnBody(&onBody, frame)
    if let edge = look.edge {
        b.stroke(body, with: .color(edge), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
    }
    buddy.drawFront(&b, frame)

    // Face: small, simple features
    let fx = CGFloat(p.faceShiftX)
    let eyeY = frame.eyeY
    let eyeColor = look.eye ?? look.ink
    let blink = p.eyes == .open && fmod(t, 3.8) < 0.14
    for side: CGFloat in [-1, 1] {
        let ex = fx + side * look.eyeSpacing + CGFloat(p.lookX)
        if p.eyes == .happy || blink {
            var e = Path()
            if blink {
                e.move(to: CGPoint(x: ex - 3.5, y: eyeY))
                e.addLine(to: CGPoint(x: ex + 3.5, y: eyeY))
            } else {
                e.move(to: CGPoint(x: ex - 4, y: eyeY + 1.5))
                e.addQuadCurve(to: CGPoint(x: ex + 4, y: eyeY + 1.5), control: CGPoint(x: ex, y: eyeY - 3.5))
            }
            b.stroke(e, with: .color(eyeColor), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        } else {
            b.fill(Path(ellipseIn: CGRect(x: ex - 3.2, y: eyeY - 4, width: 6.4, height: 8)), with: .color(eyeColor))
        }
    }

    let my = eyeY + look.mouthOffset
    if let beak = look.beak {
        // A small beak instead of a mouth; it opens when the buddy cheers
        let open: CGFloat = p.mouth == .open ? 2.5 : 0
        var upper = Path()
        upper.move(to: CGPoint(x: fx - 5, y: my - 2))
        upper.addLine(to: CGPoint(x: fx + 5, y: my - 2))
        upper.addLine(to: CGPoint(x: fx, y: my + 2.5))
        upper.closeSubpath()
        var lower = Path()
        lower.move(to: CGPoint(x: fx - 3.5, y: my + 1 + open))
        lower.addLine(to: CGPoint(x: fx + 3.5, y: my + 1 + open))
        lower.addLine(to: CGPoint(x: fx, y: my + 5 + open))
        lower.closeSubpath()
        b.fill(lower, with: .color(beak.opacity(0.85)))
        b.fill(upper, with: .color(beak))
    } else {
        switch p.mouth {
        case .smile:
            var m = Path()
            m.move(to: CGPoint(x: fx - 4, y: my))
            m.addQuadCurve(to: CGPoint(x: fx + 4, y: my), control: CGPoint(x: fx, y: my + 4.5))
            b.stroke(m, with: .color(look.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        case .open:
            var m = Path()
            m.move(to: CGPoint(x: fx - 4.5, y: my - 0.5))
            m.addLine(to: CGPoint(x: fx + 4.5, y: my - 0.5))
            m.addQuadCurve(to: CGPoint(x: fx - 4.5, y: my - 0.5), control: CGPoint(x: fx, y: my + 8))
            m.closeSubpath()
            b.fill(m, with: .color(look.ink))
        case .o:
            b.fill(Path(ellipseIn: CGRect(x: fx - 2.3, y: my - 0.5, width: 4.6, height: 5.5)), with: .color(look.ink))
        }
    }

    if p.leftArm < 0 { arm(x: -shoulderX, angle: p.leftArm) }
    if p.rightArm < 0 { arm(x: shoulderX, angle: -p.rightArm) }
}

/// Animated buddy. Pass `fixedTime` to draw a single still frame (previews, lists).
struct BuddyView: View {
    let move: Move
    var buddy: Buddy = .mochi
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
            drawBuddy(&ctx, pose(for: move, at: t), t: t, buddy: buddy)
        }
    }
}
