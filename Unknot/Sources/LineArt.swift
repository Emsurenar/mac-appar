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
    /// Colour printed along a line, as wide as `width`: tails, toes, inner ears.
    func tintLine(_ p: Path, width: CGFloat, _ color: Color) {
        var m = c
        m.blendMode = .multiply
        m.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
    /// An outlined tube along a path, like the cat's tail.
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
        let x = center.x + f.look * 0.5, y = center.y + f.lookUp * 0.5
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

extension View {
    /// The crew always stands on paper. In dark mode the paper is printed a little dimmer, so it doesn't glare.
    func paperTone(_ scheme: ColorScheme) -> some View {
        colorMultiply(scheme == .dark ? Color(hex: 0xE3DCCF) : .white)
    }
}

// MARK: - Frame

/// What the drawing needs to know about the current moment.
struct CrewFrame {
    let pose: Pose
    let t: Double

    var fx: CGFloat { CGFloat(pose.faceShiftX) }
    var look: CGFloat { CGFloat(pose.lookX) }
    var lookUp: CGFloat { CGFloat(pose.lookY) }
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
}

extension ArmStyle {
    /// How long the arm is at rest, for arms that reach with a hand.
    var baseLength: CGFloat? {
        switch self {
        case .noodle(let length, _), .bold(let length): return length
        case .flap: return nil
        }
    }
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

/// Where a hand target is for this member of the crew, in the space the arms are drawn in.
func targetPoint(_ target: HandTarget, side: CGFloat, art: CrewArt, shoulders: [CGPoint], frame f: CrewFrame) -> CGPoint {
    let head = art.headBox
    let chestY = (shoulders[0].y + shoulders[1].y) / 2
    let half = abs(shoulders[1].x - shoulders[0].x) / 2
    var p: CGPoint
    switch target {
    case .overhead: p = pt(head.midX + side * 2.5, head.minY - 7)
    case .farEar: p = pt(head.midX - side * head.width * 0.4, head.minY + head.height * 0.3)
    case .farShoulder: p = pt(100 - side * (half - 3), chestY + 3)
    case .chest: p = pt(100 + side * 12, chestY + 9)
    case .acrossChest: p = pt(100 - side * (half + 12), chestY + 7)
    case .elbow: p = pt(100 - side * 8, chestY + 10)
    case .farHip: p = pt(100 - side * (half - 2), chestY + 28)
    }
    // A hand on the head goes where the head has tilted to
    if case .farEar = target, let pivot = art.headPivot, f.pose.headTilt != 0 {
        let a = f.pose.headTilt * .pi / 180
        let d = pt(p.x - pivot.x, p.y - pivot.y)
        p = pt(pivot.x + d.x * CGFloat(cos(a)) - d.y * CGFloat(sin(a)), pivot.y + d.x * CGFloat(sin(a)) + d.y * CGFloat(cos(a)))
    }
    return p
}

/// Where a hand ends up: from the arm's angle, drawn towards its target and the brow, never further than the
/// arm can stretch.
func handEnd(side: CGFloat, shoulder: CGPoint, shoulders: [CGPoint], angle: Double, base: CGFloat,
                     art: CrewArt, frame f: CrewFrame) -> CGPoint {
    var end = handPoint(from: shoulder, side: side, angle: angle, length: armReach(base, angle, extra: art.reachExtra))
    let target = side < 0 ? f.pose.leftTarget : f.pose.rightTarget
    let reach = CGFloat(side < 0 ? f.pose.leftReach : f.pose.rightReach)
    if let target, reach > 0 {
        var goal = targetPoint(target, side: side, art: art, shoulders: shoulders, frame: f)
        let d = pt(goal.x - shoulder.x, goal.y - shoulder.y)
        let distance = sqrt(d.x * d.x + d.y * d.y)
        let longest = (base + art.reachExtra) * 1.5
        if distance > longest { goal = pt(shoulder.x + d.x / distance * longest, shoulder.y + d.y / distance * longest) }
        end = pt(end.x + (goal.x - end.x) * reach, end.y + (goal.y - end.y) * reach)
    }
    if side > 0, f.pose.handToBrow > 0, let brow = art.brow {
        let k = CGFloat(f.pose.handToBrow)
        end = pt(end.x + (brow.x - end.x) * k, end.y + (brow.y + CGFloat(sin(f.t * 1.4)) * 1.2 - end.y) * k)
    }
    let orbit = CGFloat(f.pose.handOrbit)
    let phase = f.pose.handPhase + (side < 0 ? 0 : .pi)
    return pt(end.x + CGFloat(cos(phase)) * orbit, end.y + CGFloat(sin(phase)) * orbit)
}

/// The line of an arm. Usually a gentle curve; reaching over the head or onto the far ear, it goes up the outside
/// of the head and over the top, so it never crosses the face.
private func armPath(side: CGFloat, shoulder: CGPoint, mid: CGPoint, end: CGPoint, art: CrewArt, frame f: CrewFrame) -> Path {
    var c1 = pt(shoulder.x + (mid.x - shoulder.x) * 2 / 3, shoulder.y + (mid.y - shoulder.y) * 2 / 3)
    var c2 = pt(end.x + (mid.x - end.x) * 2 / 3, end.y + (mid.y - end.y) * 2 / 3)
    let target = side < 0 ? f.pose.leftTarget : f.pose.rightTarget
    let k = CGFloat(side < 0 ? f.pose.leftReach : f.pose.rightReach)
    if let target, k > 0 {
        let head = art.headBox
        let outside = side < 0 ? head.minX - 8 : head.maxX + 8
        var round: (CGPoint, CGPoint)?
        switch target {
        case .overhead:
            round = (pt(outside, shoulder.y - (shoulder.y - head.minY) * 0.5), pt(outside - side * 2, head.minY - 2))
        case .farEar:
            round = (pt(outside, head.minY + head.height * 0.25), pt(head.midX + side * 6, head.minY - 16))
        default:
            break
        }
        if var (r1, r2) = round {
            if case .farEar = target, let pivot = art.headPivot, f.pose.headTilt != 0 {
                let a = f.pose.headTilt * .pi / 180
                func turn(_ p: CGPoint) -> CGPoint {
                    let d = pt(p.x - pivot.x, p.y - pivot.y)
                    return pt(pivot.x + d.x * CGFloat(cos(a)) - d.y * CGFloat(sin(a)), pivot.y + d.x * CGFloat(sin(a)) + d.y * CGFloat(cos(a)))
                }
                r1 = turn(r1); r2 = turn(r2)
            }
            c1 = pt(c1.x + (r1.x - c1.x) * k, c1.y + (r1.y - c1.y) * k)
            c2 = pt(c2.x + (r2.x - c2.x) * k, c2.y + (r2.y - c2.y) * k)
        }
    }
    return makePath { $0.move(to: shoulder); $0.addCurve(to: end, control1: c1, control2: c2) }
}

/// Comic motion lines: how the shoulders circle or lift, how the wrists turn, how the hands shake.
private func drawMarks(_ pen: Pen, _ f: CrewFrame, shoulders: [CGPoint], hands: [CGPoint]) {
    let k = CGFloat(f.pose.markStrength)
    guard f.pose.marks != .none, k > 0.05 else { return }
    let ink = Pen.ink.opacity(Double(0.75 * k))
    let style = StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round)
    for (i, side) in [CGFloat(-1), 1].enumerated() {
        let s = shoulders[i], h = hands[i]
        var lines = Path()
        switch f.pose.marks {
        case .shoulderRolls:
            // A round arrow above each shoulder, rolling backwards
            let c = pt(s.x + side * 8, s.y - 12)
            lines.addArc(center: c, radius: 6.5, startAngle: .degrees(side < 0 ? 200 : -20), endAngle: .degrees(side < 0 ? 20 : 160), clockwise: side > 0)
            let tip = pt(c.x + side * 6.5 * CGFloat(cos(20 * Double.pi / 180)), c.y + 6.5 * CGFloat(sin(20 * Double.pi / 180)))
            lines.move(to: pt(tip.x - side * 1, tip.y - 3.5)); lines.addLine(to: tip); lines.addLine(to: pt(tip.x - side * 3.8, tip.y + 0.5))
        case .shoulderLift:
            for dx: CGFloat in [4, 9] {
                lines.move(to: pt(s.x + side * dx, s.y - 9 - dx * 0.4)); lines.addLine(to: pt(s.x + side * dx, s.y - 15 - dx * 0.4))
            }
        case .wristCircles:
            lines.addArc(center: h, radius: 7.5, startAngle: .degrees(-60), endAngle: .degrees(200), clockwise: false)
        case .shake:
            for r: CGFloat in [7, 10.5] {
                lines.addArc(center: h, radius: r, startAngle: .degrees(side < 0 ? 140 : -40), endAngle: .degrees(side < 0 ? 220 : 40), clockwise: false)
            }
        case .none:
            break
        }
        pen.c.stroke(lines, with: .color(ink), style: style)
    }
}

func drawArm(_ pen: Pen, side: CGFloat, shoulder: CGPoint, shoulders: [CGPoint], angle: Double, art: CrewArt, frame f: CrewFrame) {
    switch art.arm {
    case .noodle(let base, let hand):
        let end = handEnd(side: side, shoulder: shoulder, shoulders: shoulders, angle: angle, base: base, art: art, frame: f)
        let dx = end.x - shoulder.x, dy = end.y - shoulder.y
        let len = max(1, sqrt(dx * dx + dy * dy))
        var n = pt(-dy / len, dx / len)
        if n.x * side < 0 { n = pt(-n.x, -n.y) }  // bow outwards, like a relaxed elbow
        let mid = pt((shoulder.x + end.x) / 2 + n.x * 4, (shoulder.y + end.y) / 2 + n.y * 4)
        pen.stroke(armPath(side: side, shoulder: shoulder, mid: mid, end: end, art: art, frame: f))
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
        let end = handEnd(side: side, shoulder: shoulder, shoulders: shoulders, angle: angle, base: base, art: art, frame: f)
        let mid = pt((shoulder.x + end.x) / 2 + side * 3, (shoulder.y + end.y) / 2 + 2)
        pen.c.stroke(armPath(side: side, shoulder: shoulder, mid: mid, end: end, art: art, frame: f),
                     with: .color(Pen.ink), style: StrokeStyle(lineWidth: 9, lineCap: .round))
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

    // Up on the toes the feet stay on the ground and stand taller; a jump lifts them too
    var feetSpace = ctx
    feetSpace.translateBy(x: 0, y: -lift)
    if p.tiptoe > 0 {
        feetSpace.translateBy(x: 100, y: 175)
        feetSpace.scaleBy(x: 1 - 0.2 * CGFloat(p.tiptoe), y: 1 + 0.9 * CGFloat(p.tiptoe))
        feetSpace.translateBy(x: -100, y: -175)
    }
    art.feet(Pen(c: feetSpace), f)

    var b = ctx
    let a = art.anchor
    let ownHead = art.headPivot != nil
    b.translateBy(x: a.x, y: a.y - lift - CGFloat(p.tiptoe) * 10)
    b.rotate(by: .degrees(p.tilt + (ownHead ? 0 : p.headTilt)))
    b.scaleBy(x: CGFloat(p.scaleX), y: CGFloat(p.scaleY))
    b.translateBy(x: -a.x, y: -a.y)
    if p.bend != 0 {
        let w = art.waist
        b.translateBy(x: w.x, y: w.y)
        b.rotate(by: .degrees(p.bend))
        b.translateBy(x: -w.x, y: -w.y)
    }
    let pen = Pen(c: b)
    // People turn their head on its own; for everyone else the head is the body
    // and when they pull their shoulders up, the head sinks down between them
    let headPen = art.headPivot.map { pivot in
        pen.moved { $0.translateBy(x: 0, y: CGFloat(max(p.shoulderLift, 0)) * 0.55) }.rotated(p.headTilt, around: pivot)
    } ?? pen

    art.behind(pen, f)

    let shoulders = art.shoulders.map { pt($0.x, $0.y - CGFloat(p.shoulderLift)) }
    // The offset only matters near rest; reaches and hugs keep the pose's own angles.
    let angles = [p.leftArm, p.rightArm].map { $0 + art.armOffset * max(0, 1 - abs($0) / 120) }
    var alwaysInFront = false
    if case .flap(_, _, _, let inFront) = art.arm { alwaysInFront = inFront }
    func isInFront(_ i: Int) -> Bool {
        if alwaysInFront || angles[i] < -6 { return true }
        if i == 1 && p.handToBrow > 0.5 && art.brow != nil { return true }
        // A hand that's gone to a target in front of the body is drawn over it; overhead stays behind
        let target = i == 0 ? p.leftTarget : p.rightTarget
        let reach = i == 0 ? p.leftReach : p.rightReach
        if let target, reach > 0.35 {
            if case .overhead = target { return false }
            if case .flap = art.arm {} else { return true }
        }
        if let below = art.armsInFrontBelow { return angles[i] < below }
        return false
    }
    func arms(inFront: Bool) {
        for i in 0..<2 where isInFront(i) == inFront {
            drawArm(pen, side: i == 0 ? -1 : 1, shoulder: shoulders[i], shoulders: shoulders, angle: angles[i], art: art, frame: f)
        }
    }

    arms(inFront: false)
    pen.shape(art.body)
    for h in art.hatches { pen.hatch(h) }
    art.onBody(pen, f)
    art.headParts(headPen, f)
    art.face(headPen, f)
    art.front(pen, f)

    // Colour is printed over the body before the arms in front, so wings and hugging arms aren't tinted twice
    pen.tint(art.wash, art.accent.opacity(0.6))
    for (path, colour) in art.extras(f) { pen.tint(path, colour) }
    for (path, colour) in art.headTints(f) { headPen.tint(path, colour) }
    pen.tint(art.detail(f), art.detailColor)
    art.overlay(headPen, f)

    arms(inFront: true)

    if p.marks != .none, case let base = (art.arm.baseLength ?? 24) {
        let hands = [CGFloat(-1), 1].enumerated().map { i, side in
            handEnd(side: side, shoulder: shoulders[i], shoulders: shoulders, angle: angles[i], base: base, art: art, frame: f)
        }
        drawMarks(pen, f, shoulders: shoulders, hands: hands)
    }
}

/// A member of the crew, animated. Pass `fixedTime` for a still frame, or `epoch` to start the move from rest
/// (or from `startAt` seconds in). With `previous`, the first half second blends over from the move before,
/// so the figure never jumps when the exercise changes.
struct BuddyView: View {
    let move: Move
    var buddy: Buddy = .mochi
    var fixedTime: Double? = nil
    var epoch: Date? = nil
    var startAt: Double = 0
    /// The move before this one, and how long it had been running when this one began.
    var previous: (move: Move, ranFor: Double)? = nil

    static let blendDuration = 0.5

    var body: some View {
        Group {
            if let t = fixedTime {
                canvas(t)
            } else {
                // Every frame the display shows, up to 120 a second on ProMotion screens; a frame takes well
                // under a millisecond to draw (`Unknot --benchmark`). In Low Power Mode, 30 is plenty.
                TimelineView(.animation(minimumInterval: ProcessInfo.processInfo.isLowPowerModeEnabled ? 1.0 / 30 : nil)) { timeline in
                    canvas(epoch.map { startAt + timeline.date.timeIntervalSince($0) } ?? timeline.date.timeIntervalSinceReferenceDate)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func currentPose(_ t: Double) -> Pose {
        let now = pose(for: move, at: t)
        guard let previous, t < Self.blendDuration else { return now }
        return mix(pose(for: previous.move, at: previous.ranFor + t), now, ease(t / Self.blendDuration))
    }

    private func canvas(_ t: Double) -> some View {
        Canvas { ctx, size in
            // Frame the part of the drawing space where the figure lives
            let view = CGRect(x: 22, y: 30, width: 156, height: 156)
            let k = min(size.width, size.height) / view.width
            ctx.translateBy(x: (size.width - view.width * k) / 2, y: (size.height - view.height * k) / 2)
            ctx.scaleBy(x: k, y: k)
            ctx.translateBy(x: -view.minX, y: -view.minY)
            drawCrew(&ctx, buddy, currentPose(t), t: t)
        }
    }
}
