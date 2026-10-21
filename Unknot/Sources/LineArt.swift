import SwiftUI

// The Stretch Crew is drawn like an engraving: one ink line, finer lines for detail, hatching for shadow,
// and a soft tint of colour printed on top. Everything lives in a 200×200 space with the ground at y = 176.

// MARK: - Geometry

func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h))
}

func makePath(_ build: (inout Path) -> Void) -> Path {
    var p = Path()
    build(&p)
    return p
}

func line(_ a: CGPoint, _ b: CGPoint) -> Path {
    makePath { $0.move(to: a); $0.addLine(to: b) }
}

func bend(_ a: CGPoint, _ control: CGPoint, _ b: CGPoint) -> Path {
    makePath { $0.move(to: a); $0.addQuadCurve(to: b, control: control) }
}

func superellipse(cx: CGFloat, cy: CGFloat, a: CGFloat, b: CGFloat, n: Double = 2.6) -> Path {
    makePath { p in
        for i in 0...140 {
            let t = Double(i) / 140 * 2 * .pi
            let c = cos(t), s = sin(t)
            let q = pt(cx + a * CGFloat(copysign(pow(abs(c), 2 / n), c)), cy + b * CGFloat(copysign(pow(abs(s), 2 / n), s)))
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
    }
}

/// A small deterministic random generator, so textures look the same every frame.
struct SeededRandom {
    var state: UInt64
    mutating func next() -> CGFloat {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((state >> 33) & 0xFFFFFF) / CGFloat(0xFFFFFF)
    }
}

/// Engraved shading: parallel lines clipped to a region. Built once, drawn every frame.
struct Hatch {
    let clip: Path
    let lines: Path

    init(_ region: Path, spacing: CGFloat = 2.9, angle: Double = 50) {
        clip = region
        let r = region.boundingRect.insetBy(dx: -4, dy: -4)
        let a = angle * .pi / 180
        let dir = pt(CGFloat(cos(a)), CGFloat(sin(a)))
        let normal = pt(-dir.y, dir.x)
        let reach = (r.width + r.height)
        var p = Path()
        var d = -reach / 2
        while d < reach / 2 {
            let o = pt(r.midX + normal.x * d, r.midY + normal.y * d)
            p.move(to: pt(o.x - dir.x * reach, o.y - dir.y * reach))
            p.addLine(to: pt(o.x + dir.x * reach, o.y + dir.y * reach))
            d += spacing
        }
        lines = p
    }

    /// The shadow side of a form: the shape minus a copy shifted towards the light, which comes from the top left.
    static func shadow(of shape: Path, shift: CGFloat = 13, spacing: CGFloat = 2.9) -> Hatch {
        Hatch(shape.subtracting(shape.applying(CGAffineTransform(translationX: -shift, y: -shift * 0.45))), spacing: spacing)
    }
}

// MARK: - Pen

/// Drawing tools that keep the line consistent.
struct Pen {
    static let paper = Color(hex: 0xF7F5F0)
    static let ink = Color(hex: 0x262626)
    static let weight: CGFloat = 2.2

    var c: GraphicsContext

    func stroke(_ p: Path, _ width: CGFloat = Pen.weight, color: Color = Pen.ink) {
        c.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
    func fine(_ p: Path) { stroke(p, 1.25) }
    /// A closed shape that hides what's behind it.
    func shape(_ p: Path, _ width: CGFloat = Pen.weight) {
        c.fill(p, with: .color(Pen.paper))
        stroke(p, width)
    }
    func solid(_ p: Path, color: Color = Pen.ink) { c.fill(p, with: .color(color)) }
    func paper(_ p: Path) { c.fill(p, with: .color(Pen.paper)) }
    /// Colour printed over the drawing; the ink stays black underneath.
    func tint(_ p: Path, _ color: Color) {
        var m = c
        m.blendMode = .multiply
        m.fill(p, with: .color(color))
    }
    /// An outlined tube along a path: tails, cactus branches.
    func tube(_ p: Path, width: CGFloat) {
        c.stroke(p, with: .color(Pen.ink), style: StrokeStyle(lineWidth: width + Pen.weight * 2, lineCap: .round, lineJoin: .round))
        c.stroke(p, with: .color(Pen.paper), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
    func hatch(_ h: Hatch, color: Color = Pen.ink) {
        var x = c
        x.clip(to: h.clip)
        x.stroke(h.lines, with: .color(color), lineWidth: 0.75)
    }
    /// A copy of the pen with an extra transform, e.g. to swing an ear or a tail.
    func moved(_ change: (inout GraphicsContext) -> Void) -> Pen {
        var copy = c
        change(&copy)
        return Pen(c: copy)
    }
    /// Rotates around a point.
    func rotated(_ degrees: Double, around p: CGPoint) -> Pen {
        moved { $0.translateBy(x: p.x, y: p.y); $0.rotate(by: .degrees(degrees)); $0.translateBy(x: -p.x, y: -p.y) }
    }

    // MARK: Faces

    func eye(_ center: CGPoint, _ f: CrewFrame, r: CGFloat = 2.6, color: Color = Pen.ink) {
        let x = center.x + f.look * 0.5, y = center.y
        switch f.eyes {
        case .open:
            solid(oval(x, y, r * 1.8, r * 2.1), color: color)
        case .happy:
            stroke(bend(pt(x - r * 1.4, y + r * 0.5), pt(x, y - r * 1.3), pt(x + r * 1.4, y + r * 0.5)), 2, color: color)
        case .closed:
            stroke(line(pt(x - r * 1.3, y), pt(x + r * 1.3, y)), 2, color: color)
        }
    }

    func mouth(_ center: CGPoint, _ f: CrewFrame, width w: CGFloat = 4.5, depth: CGFloat = 3.4) {
        let x = center.x, y = center.y
        switch f.pose.mouth {
        case .smile:
            stroke(bend(pt(x - w, y), pt(x, y + depth), pt(x + w, y)))
        case .open:
            solid(makePath { p in
                p.move(to: pt(x - w * 0.9, y - 0.5))
                p.addLine(to: pt(x + w * 0.9, y - 0.5))
                p.addQuadCurve(to: pt(x - w * 0.9, y - 0.5), control: pt(x, y + depth * 2.5))
            })
        case .o:
            stroke(oval(x, y + 1.5, 4.4, 5), 1.6)
        }
    }

    /// A small beak that opens when the bird cheers.
    func beak(_ center: CGPoint, _ f: CrewFrame, colour: Color) {
        let x = center.x, y = center.y
        let open: CGFloat = f.pose.mouth == .open ? 2.6 : (f.pose.mouth == .o ? 1.2 : 0)
        let upper = makePath { p in
            p.move(to: pt(x - 6, y)); p.addLine(to: pt(x + 6, y)); p.addLine(to: pt(x, y + 5.5)); p.closeSubpath()
        }
        let lower = makePath { p in
            p.move(to: pt(x - 4.4, y + 2.6 + open)); p.addLine(to: pt(x + 4.4, y + 2.6 + open)); p.addLine(to: pt(x, y + 7 + open)); p.closeSubpath()
        }
        if open > 0 {
            shape(lower, 1.5)
            tint(lower, colour)
        }
        shape(upper, 1.7)
        tint(upper, colour)
        if open == 0 { fine(line(pt(x - 4.4, y + 2.2), pt(x + 4.4, y + 2.2))) }
    }
}

// MARK: - Frame

/// What the drawing needs to know about the current moment.
struct CrewFrame {
    let pose: Pose
    let t: Double

    var fx: CGFloat { CGFloat(pose.faceShiftX) }
    var look: CGFloat { CGFloat(pose.lookX) }
    var sway: Double { pose.sproutSway }
    var eyes: Eyes {
        if pose.eyes == .open && fmod(max(t, 0), 3.8) > 3.66 { return .closed }  // an idle blink every few seconds
        return pose.eyes
    }
}

// MARK: - Arms

enum HandStyle { case loop, frog }

enum ArmStyle {
    /// A thin, slightly bent arm with a small hand.
    case noodle(length: CGFloat, hand: HandStyle)
    /// A thick ink arm, like a panda's.
    case bold(length: CGFloat)
    /// A closed shape (flipper, wing) drawn for the left side with the shoulder at the origin.
    case flap(Path, hatch: Hatch?, rest: Double, inFront: Bool)
    /// A cactus branch: out to an elbow, then a segment that tilts with the pose.
    case branch
}

/// Arms grow when raised, so hands clear the head.
func armReach(_ base: CGFloat, _ angle: Double, extra: CGFloat = 22) -> CGFloat {
    let x = min(max((abs(angle) - 60) / 100, 0), 1)
    return base + CGFloat(x * x * (3 - 2 * x)) * extra
}

/// Where a hand ends up: 0° hangs down, positive raises outwards, negative crosses in front.
func handPoint(from shoulder: CGPoint, side: CGFloat, angle: Double, length: CGFloat) -> CGPoint {
    let theta = (side < 0 ? angle : -angle) * .pi / 180
    return pt(shoulder.x - length * CGFloat(sin(theta)), shoulder.y + length * CGFloat(cos(theta)))
}

func drawArm(_ pen: Pen, side: CGFloat, shoulder: CGPoint, angle: Double, art: CrewArt, frame f: CrewFrame) {
    let orbit = CGFloat(f.pose.handOrbit)
    let phase = f.pose.handPhase + (side < 0 ? 0 : .pi)
    let wobble = pt(CGFloat(cos(phase)) * orbit, CGFloat(sin(phase)) * orbit)
    switch art.arm {
    case .noodle(let base, let hand):
        let length = armReach(base, angle, extra: art.reachExtra)
        var end = handPoint(from: shoulder, side: side, angle: angle, length: length)
        if side > 0, f.pose.handToBrow, let brow = art.brow { end = pt(brow.x, brow.y + CGFloat(sin(f.t * 1.4)) * 1.2) }
        end = pt(end.x + wobble.x, end.y + wobble.y)
        let dx = end.x - shoulder.x, dy = end.y - shoulder.y
        let len = max(1, sqrt(dx * dx + dy * dy))
        var n = pt(-dy / len, dx / len)
        if n.x * side < 0 { n = pt(-n.x, -n.y) }  // bow outwards, like a relaxed elbow
        let mid = pt((shoulder.x + end.x) / 2 + n.x * 4, (shoulder.y + end.y) / 2 + n.y * 4)
        pen.stroke(bend(shoulder, mid, end))
        switch hand {
        case .loop:
            pen.shape(oval(end.x, end.y, 6.4, 6.4), 1.8)
        case .frog:
            let d = pt(dx / len, dy / len)
            for spread in [-28.0, 0.0, 28.0] {
                let r = spread * .pi / 180
                let v = pt(d.x * CGFloat(cos(r)) - d.y * CGFloat(sin(r)), d.x * CGFloat(sin(r)) + d.y * CGFloat(cos(r)))
                let tip = pt(end.x + v.x * 5.5, end.y + v.y * 5.5)
                pen.fine(line(end, tip))
                pen.solid(oval(tip.x, tip.y, 2.3, 2.3))
            }
        }
    case .bold(let base):
        let length = armReach(base, angle, extra: art.reachExtra)
        var end = handPoint(from: shoulder, side: side, angle: angle, length: length)
        if side > 0, f.pose.handToBrow, let brow = art.brow { end = brow }
        let mid = pt((shoulder.x + end.x) / 2 + side * 3, (shoulder.y + end.y) / 2 + 2)
        pen.c.stroke(bend(shoulder, mid, end), with: .color(Pen.ink), style: StrokeStyle(lineWidth: 9, lineCap: .round))
    case .flap(let shapePath, let hatch, let rest, _):
        let p = pen.moved { ctx in
            ctx.translateBy(x: shoulder.x, y: shoulder.y)
            if side > 0 { ctx.scaleBy(x: -1, y: 1) }
            // Wings and flippers fold in over the belly at most, never across the face
            ctx.rotate(by: .degrees(max(angle - rest, -40)))
        }
        p.shape(shapePath)
        if let hatch { p.hatch(hatch) }
        p.tint(shapePath, art.accent.opacity(0.6))
    case .branch:
        let elbow = pt(shoulder.x + side * 12, shoulder.y)
        let segment = 170 + (angle - 30) * 0.2
        let tip = handPoint(from: elbow, side: side, angle: segment, length: 18)
        let branch = makePath { $0.move(to: shoulder); $0.addLine(to: elbow); $0.addLine(to: tip) }
        pen.tube(branch, width: 11)
        pen.tint(branch.strokedPath(StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round)), art.accent.opacity(0.6))
        let areole = pt((elbow.x + tip.x) / 2, (elbow.y + tip.y) / 2)
        pen.c.stroke(oval(areole.x, areole.y, 2.2, 2.2), with: .color(Pen.ink), lineWidth: 1)
    }
}

// MARK: - Drawing a member of the crew

/// Draws one frame. The figure is drawn in ink first, then its colour is printed over it.
func drawCrew(_ ctx: inout GraphicsContext, _ buddy: Buddy, _ p: Pose, t: Double) {
    let art = buddy.art
    let f = CrewFrame(pose: p, t: t)
    let lift = CGFloat(p.lift)

    // Engraved ground lines that shorten as the figure leaves the ground
    for (i, k) in [1.0, 0.72, 0.42].enumerated() {
        let half = art.groundWidth * CGFloat(k) / 2 * max(0.55, 1 - lift / 30)
        let y = 176 + CGFloat(i) * 3.2
        ctx.stroke(line(pt(100 - half, y), pt(100 + half, y)), with: .color(Pen.ink.opacity(0.7)), lineWidth: 0.9)
    }

    var feetSpace = ctx
    feetSpace.translateBy(x: 0, y: -lift)
    art.feet(Pen(c: feetSpace), f)

    var b = ctx
    let a = art.anchor
    b.translateBy(x: a.x, y: a.y - lift)
    b.rotate(by: .degrees(p.tilt))
    b.scaleBy(x: CGFloat(p.scaleX), y: CGFloat(p.scaleY))
    b.translateBy(x: -a.x, y: -a.y)
    let pen = Pen(c: b)

    art.behind(pen, f)

    let shoulders = art.shoulders.map { pt($0.x, $0.y - CGFloat(p.shoulderLift)) }
    // The offset only matters near rest; reaches and hugs keep the pose's own angles.
    let angles = [p.leftArm, p.rightArm].map { $0 + art.armOffset * max(0, 1 - abs($0) / 120) }
    var alwaysInFront = false
    if case .flap(_, _, _, let inFront) = art.arm { alwaysInFront = inFront }
    func isInFront(_ i: Int) -> Bool {
        if alwaysInFront || angles[i] < -6 { return true }
        if i == 1 && p.handToBrow && art.brow != nil { return true }
        if let below = art.armsInFrontBelow { return angles[i] < below }
        return false
    }
    func arms(inFront: Bool) {
        for i in 0..<2 where isInFront(i) == inFront {
            drawArm(pen, side: i == 0 ? -1 : 1, shoulder: shoulders[i], angle: angles[i], art: art, frame: f)
        }
    }

    arms(inFront: false)
    pen.shape(art.body)
    for h in art.hatches { pen.hatch(h) }
    art.onBody(pen, f)
    art.face(pen, f)
    art.front(pen, f)

    // Colour is printed over the body before the arms in front, so wings and hugging arms aren't tinted twice
    pen.tint(art.wash, art.accent.opacity(0.6))
    for (path, colour) in art.extras(f) { pen.tint(path, colour) }
    pen.tint(art.detail(f), art.detailColor)

    arms(inFront: true)
}

/// A member of the crew, animated. Pass `fixedTime` for a still frame, or `epoch` to start the move from rest.
struct BuddyView: View {
    let move: Move
    var buddy: Buddy = .mochi
    var fixedTime: Double? = nil
    var epoch: Date? = nil

    var body: some View {
        Group {
            if let t = fixedTime {
                canvas(t)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    canvas(epoch.map { timeline.date.timeIntervalSince($0) } ?? timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func canvas(_ t: Double) -> some View {
        Canvas { ctx, size in
            // Frame the part of the drawing space where the figure lives
            let view = CGRect(x: 22, y: 30, width: 156, height: 156)
            let k = min(size.width, size.height) / view.width
            ctx.translateBy(x: (size.width - view.width * k) / 2, y: (size.height - view.height * k) / 2)
            ctx.scaleBy(x: k, y: k)
            ctx.translateBy(x: -view.minX, y: -view.minY)
            drawCrew(&ctx, buddy, pose(for: move, at: t), t: t)
        }
    }
}
