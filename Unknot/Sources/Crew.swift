import SwiftUI

/// How one member of the crew is drawn. Shapes are built once; the frame decides eyes, mouth and moving parts.
protocol CrewArt: Sendable {
    var accent: Color { get }        // the soft tint printed over the figure
    var detailColor: Color { get }   // the one stronger detail
    var anchor: CGPoint { get }      // the point the body leans and stretches around
    var body: Path { get }           // the main contour, which hides what's behind it
    var wash: Path { get }           // where the tint goes
    var hatches: [Hatch] { get }     // shading on the body
    var shoulders: [CGPoint] { get } // left, right
    var arm: ArmStyle { get }
    var armOffset: Double { get }    // added to the pose's arm angles near rest, for figures whose arms rest differently
    var armsInFrontBelow: Double? { get }  // arms lower than this angle are drawn over the body, like a frog's front legs
    var brow: CGPoint? { get }       // where the right hand goes to shade the eyes
    var reachExtra: CGFloat { get }  // how much longer arms get when raised, so hands clear the head
    var groundWidth: CGFloat { get }
    func feet(_ pen: Pen, _ f: CrewFrame)
    func behind(_ pen: Pen, _ f: CrewFrame)
    func onBody(_ pen: Pen, _ f: CrewFrame)
    func face(_ pen: Pen, _ f: CrewFrame)
    func front(_ pen: Pen, _ f: CrewFrame)
    func detail(_ f: CrewFrame) -> Path
    func extras(_ f: CrewFrame) -> [(Path, Color)]
}

extension CrewArt {
    var anchor: CGPoint { pt(100, 168) }
    var armOffset: Double { 0 }
    var armsInFrontBelow: Double? { nil }
    var brow: CGPoint? { nil }
    var reachExtra: CGFloat { 22 }
    var groundWidth: CGFloat { 92 }
    func feet(_ pen: Pen, _ f: CrewFrame) {}
    func behind(_ pen: Pen, _ f: CrewFrame) {}
    func onBody(_ pen: Pen, _ f: CrewFrame) {}
    func front(_ pen: Pen, _ f: CrewFrame) {}
    func extras(_ f: CrewFrame) -> [(Path, Color)] { [] }
}

extension Buddy {
    var art: CrewArt { CrewArtwork.all[self] ?? CrewArtwork.mochi }
}

enum CrewArtwork {
    static let mochi = MochiArt()
    static let all: [Buddy: CrewArt] = [
        .mochi: mochi, .cat: CatArt(), .panda: PandaArt(), .bunny: BunnyArt(), .frog: FrogArt(),
        .semla: SemlaArt(), .chick: ChickArt(), .toast: ToastArt(), .onigiri: OnigiriArt(), .stefan: StefanArt(),
        .jesus: JesusArt(), .gandhi: GandhiArt(), .obama: ObamaArt(), .descartes: DescartesArt(),
    ]
}

private func ovalFeet(_ pen: Pen, _ xs: [CGFloat], width: CGFloat = 16, height: CGFloat = 8) {
    for x in xs { pen.shape(oval(x, 171, width, height), 1.9) }
}

// MARK: - Frog

struct FrogArt: CrewArt {
    let accent = Color(hex: 0xAFCDA0)
    let detailColor = Color(hex: 0xA3C792)
    let body: Path
    let wash: Path
    let hatches: [Hatch]
    let legs: [Path]
    let legHatches: [Hatch]
    let shoulders = [pt(71, 134), pt(129, 134)]
    let arm = ArmStyle.noodle(length: 29, hand: .frog)
    let armOffset = -22.0
    let armsInFrontBelow: Double? = 55
    let brow: CGPoint? = pt(125, 70)
    let reachExtra: CGFloat = 44
    let belly = oval(100, 150, 52, 30)

    init() {
        let body = makePath { p in
            p.move(to: pt(54, 120))
            p.addCurve(to: pt(66, 78), control1: pt(50, 99), control2: pt(55, 86))
            p.addCurve(to: pt(91, 80), control1: pt(72, 63), control2: pt(89, 65))
            p.addQuadCurve(to: pt(109, 80), control: pt(100, 84))
            p.addCurve(to: pt(134, 78), control1: pt(111, 65), control2: pt(128, 63))
            p.addCurve(to: pt(146, 120), control1: pt(145, 86), control2: pt(150, 99))
            p.addCurve(to: pt(100, 166), control1: pt(144, 148), control2: pt(124, 166))
            p.addCurve(to: pt(54, 120), control1: pt(76, 166), control2: pt(56, 148))
        }
        let legs: [Path] = [CGFloat(-1), 1].map { s in
            makePath { p in
                p.move(to: pt(100 + s * 32, 128))
                p.addCurve(to: pt(100 + s * 57, 160), control1: pt(100 + s * 52, 126), control2: pt(100 + s * 62, 146))
                p.addCurve(to: pt(100 + s * 30, 170), control1: pt(100 + s * 53, 171), control2: pt(100 + s * 38, 171))
                p.addCurve(to: pt(100 + s * 32, 128), control1: pt(100 + s * 30, 155), control2: pt(100 + s * 26, 140))
            }
        }
        self.body = body
        self.legs = legs
        wash = legs.reduce(body) { $0.union($1) }
        hatches = [Hatch.shadow(of: body)]
        legHatches = legs.map { Hatch.shadow(of: $0, shift: 8) }
    }

    func behind(_ pen: Pen, _ f: CrewFrame) {
        for (i, leg) in legs.enumerated() {
            let s: CGFloat = i == 0 ? -1 : 1
            pen.shape(leg)
            pen.hatch(legHatches[i])
            for k: CGFloat in [0, 1, 2] {
                let tip = pt(100 + s * (23 - k * 3.5), 167 + k * 3)
                pen.fine(line(pt(100 + s * 31, 169), tip))
                pen.solid(oval(tip.x, tip.y, 2.4, 2.4))
            }
        }
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.fine(bend(pt(74, 133), pt(100, 146), pt(126, 133)))
        for (x, y, r) in [(68.0, 104.0, 3.6), (131.0, 99.0, 3.0), (136.0, 117.0, 2.4), (64.0, 124.0, 2.2)] {
            pen.fine(oval(x, y, r * 2, r * 2))
        }
    }

    private func eyeX(_ s: CGFloat, _ f: CrewFrame) -> CGFloat { 100 + s * 21 + f.fx * 0.3 }

    func face(_ pen: Pen, _ f: CrewFrame) {
        for s: CGFloat in [-1, 1] {
            let x = eyeX(s, f)
            pen.fine(bend(pt(x - 7, 70.5), pt(x, 67), pt(x + 7, 70.5)))
            pen.stroke(oval(x, 79, 13, 13))
            let px = x + 0.8 + f.look * 0.6
            switch f.eyes {
            case .open: pen.solid(oval(px, 80.5, 5, 5.4))
            case .happy: pen.stroke(bend(pt(x - 3.6, 81), pt(x, 76.5), pt(x + 3.6, 81)), 1.8)
            case .closed: pen.stroke(line(pt(x - 3.6, 80), pt(x + 3.6, 80)), 1.8)
            }
            pen.solid(oval(100 + s * 4.5 + f.fx * 0.5, 96, 1.6, 1.6))
        }
        let mx = 100 + f.fx * 0.6
        switch f.pose.mouth {
        case .smile:
            pen.stroke(bend(pt(mx - 22, 106), pt(mx, 117), pt(mx + 22, 106)))
        case .open:
            pen.solid(makePath { p in
                p.move(to: pt(mx - 18, 106))
                p.addQuadCurve(to: pt(mx + 18, 106), control: pt(mx, 124))
                p.addQuadCurve(to: pt(mx - 18, 106), control: pt(mx, 110))
            })
        case .o:
            pen.stroke(oval(mx, 110, 7, 8), 1.8)
        }
    }

    func detail(_ f: CrewFrame) -> Path { belly }

    func extras(_ f: CrewFrame) -> [(Path, Color)] {
        var irises = Path()
        for s: CGFloat in [-1, 1] {
            let x = eyeX(s, f)
            let ring = oval(x, 79, 11, 11)
            irises.addPath(f.eyes == .open ? ring.subtracting(oval(x + 0.8 + f.look * 0.6, 80.5, 5, 5.4)) : ring)
        }
        return [(irises, Color(hex: 0xE6BC5C))]
    }
}

// MARK: - Mochi

struct MochiArt: CrewArt {
    let accent = Color(hex: 0xF0C3A2)
    let detailColor = Color(hex: 0x9FC48F)
    let body: Path
    let wash: Path
    let hatches: [Hatch]
    let shoulders = [pt(59, 126), pt(141, 126)]
    let brow: CGPoint? = pt(117, 110)
    let arm = ArmStyle.noodle(length: 25.6, hand: .loop)
    let armOffset = -10.0
    let groundWidth: CGFloat = 84
    private let sproutBase = pt(100, 78)

    init() {
        let w: CGFloat = 92, h: CGFloat = 92, bx: CGFloat = 100, by: CGFloat = 168
        body = makePath { p in
            p.move(to: pt(bx, by - h))
            p.addCurve(to: pt(bx + w / 2, by - h * 0.38), control1: pt(bx + w * 0.30, by - h), control2: pt(bx + w / 2, by - h * 0.72))
            p.addCurve(to: pt(bx, by), control1: pt(bx + w / 2, by - h * 0.06), control2: pt(bx + w * 0.30, by))
            p.addCurve(to: pt(bx - w / 2, by - h * 0.38), control1: pt(bx - w * 0.30, by), control2: pt(bx - w / 2, by - h * 0.06))
            p.addCurve(to: pt(bx, by - h), control1: pt(bx - w / 2, by - h * 0.72), control2: pt(bx - w * 0.30, by - h))
        }
        wash = body
        hatches = [Hatch.shadow(of: body)]
    }

    private func leaves() -> [Path] {
        let base = pt(101, 61)
        return [(-125.0, 15.0), (-45.0, 18.0)].map { angle, len in
            let a = angle * .pi / 180
            let tip = pt(base.x + CGFloat(cos(a)) * len, base.y + CGFloat(sin(a)) * len)
            let n = pt(-CGFloat(sin(a)), CGFloat(cos(a)))
            let mid = pt((base.x + tip.x) / 2, (base.y + tip.y) / 2)
            return makePath { p in
                p.move(to: base)
                p.addQuadCurve(to: tip, control: pt(mid.x + n.x * 7, mid.y + n.y * 7))
                p.addQuadCurve(to: base, control: pt(mid.x - n.x * 7, mid.y - n.y * 7))
            }
        }
    }

    private func sproutPen(_ pen: Pen, _ f: CrewFrame) -> Pen { pen.rotated(f.sway - f.pose.tilt * 0.5, around: sproutBase) }

    func behind(_ pen: Pen, _ f: CrewFrame) {
        let p = sproutPen(pen, f)
        p.stroke(bend(sproutBase, pt(97, 70), pt(101, 60)))
        for leaf in leaves() {
            p.shape(leaf, 1.9)
            p.tint(leaf, detailColor)
        }
        p.fine(line(pt(101, 61), pt(92.1, 50.3)))
        p.fine(line(pt(101, 61), pt(111.2, 50.8)))
    }

    func feet(_ pen: Pen, _ f: CrewFrame) { ovalFeet(pen, [84, 116]) }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.fine(bend(pt(84, 151), pt(100, 157), pt(116, 151)))
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        pen.eye(pt(88 + f.fx, 119), f)
        pen.eye(pt(112 + f.fx, 119), f)
        pen.mouth(pt(100 + f.fx, 127), f)
    }

    func detail(_ f: CrewFrame) -> Path { Path() }
}

// MARK: - Cat

struct CatArt: CrewArt {
    let accent = Color(hex: 0xB7C2CE)
    let detailColor = Color(hex: 0xE6B3A6)
    let body = superellipse(cx: 100, cy: 128, a: 44, b: 42)
    let wash: Path
    let hatches: [Hatch]
    let ears: [Path]
    let innerEars: [Path]
    let innerEarTint: Path
    let shoulders = [pt(62, 136), pt(138, 136)]
    let brow: CGPoint? = pt(118, 112)
    let arm = ArmStyle.noodle(length: 24.7, hand: .loop)
    let armOffset = -14.0

    init() {
        ears = [CGFloat(-1), 1].map { s in
            makePath { p in
                p.move(to: pt(100 + s * 12, 92)); p.addLine(to: pt(100 + s * 34, 70)); p.addLine(to: pt(100 + s * 42, 106)); p.closeSubpath()
            }
        }
        innerEars = [CGFloat(-1), 1].map { s in
            makePath { p in p.move(to: pt(100 + s * 19, 93)); p.addLine(to: pt(100 + s * 32, 79)); p.addLine(to: pt(100 + s * 36, 98)) }
        }
        wash = ears.reduce(body) { $0.union($1) }
        hatches = [Hatch.shadow(of: body)]
        innerEarTint = innerEars.reduce(Path()) { $0.union($1.strokedPath(StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))) }
    }

    func behind(_ pen: Pen, _ f: CrewFrame) {
        // The tail swings a beat behind the body
        let swing = sin(f.t * 2.0 - 0.8) * 8 - f.pose.tilt * 0.6
        let tail = pen.rotated(swing, around: pt(132, 160))
        let path = makePath { p in
            p.move(to: pt(132, 160))
            p.addCurve(to: pt(160, 128), control1: pt(160, 162), control2: pt(166, 142))
            p.addCurve(to: pt(150, 104), control1: pt(156, 116), control2: pt(148, 112))
        }
        tail.tube(path, width: 6)
        tail.tintLine(path, width: 6, accent.opacity(0.6))
        tail.fine(line(pt(161, 134), pt(166, 136)))
        tail.fine(line(pt(158, 119), pt(163, 117)))
        for (ear, inner) in zip(ears, innerEars) {
            pen.shape(ear)
            pen.fine(inner)
        }
    }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        ovalFeet(pen, [86, 114], width: 17)
        for x: CGFloat in [83, 89, 111, 117] { pen.fine(line(pt(x, 168), pt(x, 172))) }
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        for (x, top) in [(93.0, 91.0), (100.0, 89.0), (107.0, 91.0)] {
            pen.stroke(line(pt(x + f.fx * 0.4, top), pt(x + f.fx * 0.4, top + (x == 100 ? 10 : 7))), 2)
        }
        for s: CGFloat in [-1, 1] {
            pen.fine(bend(pt(100 + s * 43, 118), pt(100 + s * 36, 121), pt(100 + s * 41, 126)))
            pen.fine(bend(pt(100 + s * 44, 132), pt(100 + s * 37, 135), pt(100 + s * 42, 140)))
        }
    }

    private func nose(_ f: CrewFrame) -> Path {
        makePath { p in
            p.move(to: pt(96.5 + f.fx, 128)); p.addLine(to: pt(103.5 + f.fx, 128)); p.addLine(to: pt(100 + f.fx, 131.5)); p.closeSubpath()
        }
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        let x = 100 + f.fx
        pen.eye(pt(87 + f.fx, 121), f, r: 2.7)
        pen.eye(pt(113 + f.fx, 121), f, r: 2.7)
        pen.solid(nose(f))
        pen.fine(bend(pt(x, 131.5), pt(x - 3, 136), pt(x - 6.5, 133.5)))
        pen.fine(bend(pt(x, 131.5), pt(x + 3, 136), pt(x + 6.5, 133.5)))
        if f.pose.mouth != .smile {
            pen.solid(makePath { p in
                p.move(to: pt(x - 3, 135.5)); p.addLine(to: pt(x + 3, 135.5)); p.addQuadCurve(to: pt(x - 3, 135.5), control: pt(x, 141))
            })
        }
        for s: CGFloat in [-1, 1] {
            pen.fine(line(pt(x + s * 15, 130), pt(x + s * 34, 127)))
            pen.fine(line(pt(x + s * 15, 133.5), pt(x + s * 34, 135)))
        }
    }

    func detail(_ f: CrewFrame) -> Path { innerEarTint }

    // One fill paints overlapping shapes once, so there's no need for a boolean union every frame
    func extras(_ f: CrewFrame) -> [(Path, Color)] {
        [(makePath { $0.addPath(nose(f)); $0.addPath(oval(100 + f.fx, 129.5, 9, 5)) }, Color(hex: 0xE09C90))]
    }
}

// MARK: - Panda

struct PandaArt: CrewArt {
    let accent = Color(hex: 0xDCD6CA)
    let detailColor = Color(hex: 0xA9C98F)
    let body = superellipse(cx: 100, cy: 128, a: 44, b: 42)
    let wash: Path
    let hatches: [Hatch]
    let shoulders = [pt(60, 134), pt(140, 134)]
    let brow: CGPoint? = pt(119, 109)
    let arm = ArmStyle.bold(length: 26)
    let armOffset = -18.0

    init() {
        wash = body
        hatches = [Hatch.shadow(of: body)]
    }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        // A bamboo sprig leaning beside the panda, on the ground
        let stem = line(pt(150, 174), pt(160, 98))
        pen.stroke(stem, 2)
        pen.tintLine(stem, width: 5, Color(hex: 0xCADB9C))
        func x(at y: CGFloat) -> CGFloat { 150 + (174 - y) / 76 * 10 }
        for y: CGFloat in [150, 124] { pen.fine(line(pt(x(at: y) - 2.5, y), pt(x(at: y) + 2.5, y))) }
        let sway = sin(f.t * 1.6) * 4
        for (y, dir) in [(110.0, 1.0), (101.0, -1.0), (118.0, -1.0)] {
            let base = pt(x(at: y), y)
            let leafPen = pen.rotated(sway * dir, around: base)
            let leaf = makePath { p in
                p.move(to: base)
                p.addQuadCurve(to: pt(base.x + dir * 20, y - 7), control: pt(base.x + dir * 9, y - 10))
                p.addQuadCurve(to: base, control: pt(base.x + dir * 11, y + 1))
            }
            leafPen.shape(leaf, 1.6)
            leafPen.tint(leaf, detailColor)
        }
        for x in [84.0, 116.0] { pen.solid(oval(x, 171, 18, 9)) }
    }

    func behind(_ pen: Pen, _ f: CrewFrame) {
        for s: CGFloat in [-1, 1] { pen.solid(oval(100 + s * 31, 92, 24, 24)) }
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        for s: CGFloat in [-1, 1] {
            let cx = 100 + s * 15 + f.fx
            pen.moved { $0.translateBy(x: cx, y: 121); $0.rotate(by: .degrees(Double(s) * -26)) }.solid(oval(0, 0, 15, 20))
            let ex = 100 + s * 14.5 + f.fx + f.look * 0.4
            switch f.eyes {
            case .open:
                pen.paper(oval(ex, 120, 6.4, 6.8))
                pen.solid(oval(ex - 0.3, 120.6, 3, 3.2))
            case .happy:
                pen.stroke(bend(pt(ex - 3.4, 121.5), pt(ex, 117), pt(ex + 3.4, 121.5)), 1.8, color: Pen.paper)
            case .closed:
                pen.stroke(line(pt(ex - 3.2, 120.5), pt(ex + 3.2, 120.5)), 1.8, color: Pen.paper)
            }
        }
        let x = 100 + f.fx
        pen.solid(oval(x, 131, 7, 4.6))
        pen.fine(line(pt(x, 133), pt(x, 136)))
        if f.pose.mouth == .smile {
            pen.fine(bend(pt(x, 136), pt(x - 3, 139), pt(x - 6, 137)))
            pen.fine(bend(pt(x, 136), pt(x + 3, 139), pt(x + 6, 137)))
        } else {
            pen.mouth(pt(x, 137), f, width: 4, depth: 2.6)
        }
    }

    func detail(_ f: CrewFrame) -> Path { Path() }
}

// MARK: - Bunny

struct BunnyArt: CrewArt {
    let accent = Color(hex: 0xEBC6BB)
    let detailColor = Color(hex: 0xE2A496)
    let body = superellipse(cx: 100, cy: 132, a: 42, b: 38)
    let wash: Path
    let hatches: [Hatch]
    let tail = oval(140, 158, 13, 12).union(oval(146, 152, 11, 11)).union(oval(147, 162, 11, 10))
    let shoulders = [pt(63, 138), pt(137, 138)]
    let brow: CGPoint? = pt(117, 118)
    let arm = ArmStyle.noodle(length: 22.8, hand: .loop)
    let armOffset = -15.0
    private let pink = Color(hex: 0xE5A99B)

    init() {
        wash = body.union(tail)
        hatches = [Hatch.shadow(of: body)]
    }

    func behind(_ pen: Pen, _ f: CrewFrame) {
        pen.shape(tail, 1.9)
        // Each ear swings on its own, a little behind the body
        let leftPen = pen.rotated(sin(f.t * 1.9) * 4 - f.pose.tilt * 0.4, around: pt(90, 99))
        let left = makePath { p in
            p.move(to: pt(84, 100))
            p.addCurve(to: pt(82, 50), control1: pt(76, 82), control2: pt(74, 56))
            p.addCurve(to: pt(96, 98), control1: pt(92, 46), control2: pt(98, 76))
        }
        leftPen.shape(left)
        leftPen.tint(left, accent.opacity(0.6))
        let leftInner = bend(pt(86, 92), pt(82, 70), pt(85, 58))
        leftPen.tintLine(leftInner, width: 5, pink)
        leftPen.fine(leftInner)

        let rightPen = pen.rotated(sin(f.t * 1.9 - 0.7) * 6 - f.pose.tilt * 0.4, around: pt(110, 99))
        let right = makePath { p in
            p.move(to: pt(104, 98))
            p.addCurve(to: pt(116, 66), control1: pt(104, 84), control2: pt(108, 70))
            p.addCurve(to: pt(140, 74), control1: pt(124, 62), control2: pt(138, 66))
            p.addCurve(to: pt(118, 80), control1: pt(140, 80), control2: pt(126, 78))
            p.addCurve(to: pt(116, 100), control1: pt(116, 86), control2: pt(117, 94))
        }
        rightPen.shape(right)
        rightPen.tint(right, accent.opacity(0.6))
        let rightInner = bend(pt(109, 92), pt(110, 76), pt(118, 71))
        rightPen.tintLine(rightInner, width: 5, pink)
        rightPen.fine(rightInner)
    }

    func feet(_ pen: Pen, _ f: CrewFrame) { ovalFeet(pen, [84, 116], width: 21) }

    private func nose(_ f: CrewFrame) -> Path {
        makePath { p in
            p.move(to: pt(96.8 + f.fx, 133)); p.addLine(to: pt(103.2 + f.fx, 133)); p.addLine(to: pt(100 + f.fx, 136.2)); p.closeSubpath()
        }
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        let x = 100 + f.fx
        pen.eye(pt(88 + f.fx, 127), f)
        pen.eye(pt(112 + f.fx, 127), f)
        pen.solid(nose(f))
        pen.fine(line(pt(x, 136.2), pt(x, 139)))
        pen.fine(bend(pt(x, 139), pt(x - 3, 141.5), pt(x - 5.5, 139.5)))
        pen.fine(bend(pt(x, 139), pt(x + 3, 141.5), pt(x + 5.5, 139.5)))
        let open: CGFloat = f.pose.mouth == .smile ? 0 : 1.6
        if open > 0 {
            pen.solid(makePath { p in
                p.move(to: pt(x - 4, 140)); p.addLine(to: pt(x + 4, 140)); p.addQuadCurve(to: pt(x - 4, 140), control: pt(x, 147))
            })
        }
        pen.shape(Path(roundedRect: CGRect(x: x - 2.6, y: 140.2, width: 5.2, height: 4.6 + open), cornerRadius: 1), 1.1)
        pen.fine(line(pt(x, 140.2), pt(x, 144.8 + open)))
        for s: CGFloat in [-1, 1] {
            pen.fine(line(pt(x + s * 13, 135), pt(x + s * 30, 132)))
            pen.fine(line(pt(x + s * 13, 138), pt(x + s * 30, 140)))
        }
    }

    func detail(_ f: CrewFrame) -> Path { makePath { $0.addPath(nose(f)); $0.addPath(oval(100 + f.fx, 134.5, 9, 6)) } }
}

// MARK: - Semla

/// A Swedish cream bun: the bottom of a cardamom bun, a layer of almond paste, piped whipped cream and the
/// bun's top put back on as a lid, dusted with icing sugar.
struct SemlaArt: CrewArt {
    let accent = Color(hex: 0xE4AA66)           // golden crust
    let detailColor = Color(hex: 0xD6AA72)      // almond paste
    let body: Path                              // the bottom half of the bun
    let wash: Path
    let hatches: [Hatch]
    let paste: Path
    let pasteGrain: Path
    let rosettes: [(shape: Path, shadow: Hatch)] // back row first, so the front row overlaps it
    let ridges: Path
    let lid: Path
    let lidCut: Path                            // the cut face under the lid, pale crumb
    let lidHatch: Hatch
    let sugar: Path
    let powder: Path
    let shine: Path
    // The arms start just inside the bun's widest point, so a wave still fits in the frame
    let shoulders = [pt(56, 140), pt(144, 140)]
    let arm = ArmStyle.noodle(length: 22, hand: .loop)
    let armOffset = -10.0
    let brow: CGPoint? = pt(116, 137)
    let reachExtra: CGFloat = 26
    let groundWidth: CGFloat = 96
    private let lip = bend(pt(52, 123), pt(100, 131), pt(148, 123))

    init() {
        let base = makePath { p in
            p.move(to: pt(52, 123))
            p.addCurve(to: pt(66, 165), control1: pt(45, 136), control2: pt(49, 159))
            p.addQuadCurve(to: pt(134, 165), control: pt(100, 170))
            p.addCurve(to: pt(148, 123), control1: pt(151, 159), control2: pt(155, 136))
            p.addQuadCurve(to: pt(52, 123), control: pt(100, 131))
        }
        body = base
        // A glazed highlight on the shoulder of the bun stays unprinted
        shine = bend(pt(57, 133), pt(57, 146), pt(65, 155)).strokedPath(StrokeStyle(lineWidth: 2.4, lineCap: .round))
        wash = base.subtracting(shine)
        hatches = [Hatch.shadow(of: base, shift: 14)]

        paste = makePath { p in
            p.move(to: pt(52, 123))
            p.addQuadCurve(to: pt(148, 123), control: pt(100, 131))
            p.addLine(to: pt(149, 119))
            p.addQuadCurve(to: pt(51, 119), control: pt(100, 127))
            p.closeSubpath()
        }
        var grain = Path()
        var r = SeededRandom(state: 91)
        for _ in 0..<38 {
            let x = 55 + r.next() * 90
            let y = 121 + (1 - pow((x - 100) / 48, 2)) * 6 + (r.next() - 0.5) * 2
            grain.addEllipse(in: CGRect(x: x - 0.45, y: y - 0.45, width: 0.9, height: 0.9))
        }
        pasteGrain = grain

        // Whipped cream piped in soft, round swirls; the back row peeks out between the front ones
        func swirl(_ x: CGFloat, _ baseY: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
            makePath { p in
                p.move(to: pt(x - w / 2, baseY))
                p.addCurve(to: pt(x + 1, baseY - h), control1: pt(x - w / 2 - 2, baseY - h * 0.8), control2: pt(x - w * 0.32, baseY - h))
                p.addCurve(to: pt(x + w / 2, baseY), control1: pt(x + w * 0.3, baseY - h), control2: pt(x + w / 2 + 2, baseY - h * 0.75))
                p.closeSubpath()
            }
        }
        let back: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(66, 114, 28, 30), (88, 112, 30, 36), (111, 111, 30, 37), (134, 114, 28, 30)]
        let front: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(55, 124, 26, 19), (73, 125, 28, 26), (92, 126, 29, 30),
                                                             (110, 126, 28, 27), (128, 125, 28, 25), (146, 124, 25, 18)]
        var ridges = Path()
        rosettes = (back + front).map { x, y, w, h in
            let shape = swirl(x, y, w, h)
            // One curl where the nozzle turned
            ridges.addPath(bend(pt(x - w * 0.28, y - h * 0.5), pt(x - w * 0.1, y - h * 0.9), pt(x + w * 0.16, y - h * 0.78)))
            return (shape, Hatch.shadow(of: shape, shift: 9, spacing: 4.2))
        }
        self.ridges = ridges

        let top = makePath { p in
            p.move(to: pt(62, 86))
            p.addCurve(to: pt(140, 86), control1: pt(64, 55), control2: pt(138, 55))
            p.addQuadCurve(to: pt(62, 86), control: pt(101, 93))
        }
        lid = top
        lidCut = makePath { p in
            p.move(to: pt(62, 86))
            p.addQuadCurve(to: pt(140, 86), control: pt(101, 93))
            p.addQuadCurve(to: pt(62, 86), control: pt(101, 98))
            p.closeSubpath()
        }
        lidHatch = Hatch.shadow(of: top, shift: 11, spacing: 2.5)
        // Icing sugar: fine dots, thickest on top of the lid, thinning out towards its edge
        var dots = Path()
        var placed = 0
        var s = SeededRandom(state: 57)
        while placed < 170 {
            let q = pt(63 + s.next() * 76, 57 + s.next() * 26)
            let fromTop = hypot((q.x - 101) / 40, (q.y - 63) / 20)
            if top.contains(q) && s.next() > fromTop * 0.75 {
                let radius = 0.35 + s.next() * 0.5
                dots.addEllipse(in: CGRect(x: q.x - radius, y: q.y - radius, width: radius * 2, height: radius * 2))
                placed += 1
            }
        }
        sugar = dots
        powder = oval(100, 66, 46, 13).intersection(top)
    }

    func feet(_ pen: Pen, _ f: CrewFrame) { ovalFeet(pen, [83, 117]) }

    func behind(_ pen: Pen, _ f: CrewFrame) {
        for rosette in rosettes {
            pen.shape(rosette.shape, 1.7)
            pen.hatch(rosette.shadow)
        }
        pen.fine(ridges)
        // The almond paste lies in front of the cream, on the cut face of the bun
        pen.paper(paste)
        pen.fine(paste)
        pen.solid(pasteGrain, color: Pen.ink.opacity(0.55))
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.stroke(lip, 1.8)
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        pen.eye(pt(89 + f.fx, 143), f)
        pen.eye(pt(111 + f.fx, 143), f)
        pen.mouth(pt(100 + f.fx, 151), f)
    }

    func front(_ pen: Pen, _ f: CrewFrame) {
        // The lid rests on the cream and wobbles a little as the bun moves
        let wobble = sin(f.t * 2.4) * 2.2 - f.pose.tilt * 0.4 - 5
        let p = pen.rotated(wobble, around: pt(101, 90))
        p.paper(lidCut)
        p.fine(lidCut)
        p.shape(lid)
        p.hatch(lidHatch)
        p.tint(lid, Color(hex: 0xD9984F).opacity(0.85))
        p.tint(lidCut, Color(hex: 0xF0D9B0))
        p.c.fill(powder, with: .color(Pen.paper.opacity(0.45)))
        p.solid(sugar, color: Pen.paper)
    }

    func detail(_ f: CrewFrame) -> Path { paste }
}

// MARK: - Chick

struct ChickArt: CrewArt {
    let accent = Color(hex: 0xF2D27C)
    let detailColor = Color(hex: 0xE58E4A)
    let body = superellipse(cx: 100, cy: 130, a: 42, b: 40)
    let wash: Path
    let hatches: [Hatch]
    let shoulders = [pt(66, 116), pt(134, 116)]
    let arm: ArmStyle
    let armOffset = -5.0

    init() {
        wash = body
        hatches = [Hatch.shadow(of: body)]
        let wing = makePath { p in
            p.move(to: pt(0, 0))
            p.addCurve(to: pt(-12, 34), control1: pt(-14, 4), control2: pt(-18, 22))
            p.addQuadCurve(to: pt(-5, 30), control: pt(-9, 36))
            p.addQuadCurve(to: pt(1, 25), control: pt(-2, 31))
            p.addQuadCurve(to: pt(4, 18), control: pt(5, 23))
            p.addQuadCurve(to: pt(0, 0), control: pt(6, 8))
        }
        arm = .flap(wing, hatch: nil, rest: 25, inFront: true)
    }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        for s: CGFloat in [-1, 1] {
            let base = pt(100 + s * 15, 168)
            for k: CGFloat in [-1, 0, 1] {
                let toe = line(base, pt(base.x + k * 6, 175))
                pen.tintLine(toe, width: 4, detailColor)
                pen.stroke(toe, 2)
            }
        }
    }

    func behind(_ pen: Pen, _ f: CrewFrame) {
        let tuft = pen.rotated(f.sway * 0.8, around: pt(100, 91))
        for (x0, x1, y1) in [(-3.0, -9.0, -12.0), (0.0, 1.0, -15.0), (3.0, 10.0, -11.0)] {
            tuft.stroke(bend(pt(100 + x0, 91), pt(100 + (x0 + x1) / 2 + 4, 91 + y1 / 2), pt(100 + x1, 91 + y1)), 2)
        }
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        for (x, y) in [(92.0, 147.0), (100.0, 151.0), (108.0, 147.0), (96.0, 156.0), (104.0, 156.0)] {
            pen.fine(bend(pt(x - 3.5, y), pt(x, y + 3), pt(x + 3.5, y)))
        }
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        pen.eye(pt(89 + f.fx, 123), f)
        pen.eye(pt(111 + f.fx, 123), f)
        pen.beak(pt(100 + f.fx, 129.5), f, colour: detailColor)
    }

    func detail(_ f: CrewFrame) -> Path { Path() }
}

// MARK: - Toast

struct ToastArt: CrewArt {
    let accent = Color(hex: 0xEBCB95)
    let detailColor = Color(hex: 0xF4D77E)
    let body: Path
    let crumb: Path
    let crust: Path
    let wash: Path
    let hatches: [Hatch]
    let pores: Path
    let shoulders = [pt(59, 128), pt(141, 128)]
    let brow: CGPoint? = pt(115, 115)
    let arm = ArmStyle.noodle(length: 23.3, hand: .loop)
    let groundWidth: CGFloat = 76
    private let butterTransform = CGAffineTransform(rotationAngle: -8 * .pi / 180).concatenating(CGAffineTransform(translationX: 112, y: 96))
    private let pat = Path(roundedRect: CGRect(x: -12, y: -7, width: 24, height: 14), cornerRadius: 3.5)

    init() {
        func bread(_ s: CGFloat) -> Path {
            let w: CGFloat = 88, h: CGFloat = 86, bx: CGFloat = 100, by: CGFloat = 160
            let r = w / 2 * s, hh = h * s, oy = by - h / 2 + hh / 2
            return makePath { p in
                p.move(to: pt(bx, oy))
                p.addLine(to: pt(bx + r - 10 * s, oy))
                p.addQuadCurve(to: pt(bx + r - 3 * s, oy - 10 * s), control: pt(bx + r - 3 * s, oy))
                p.addLine(to: pt(bx + r - 3 * s, oy - hh * 0.58))
                p.addCurve(to: pt(bx + r * 0.42, oy - hh), control1: pt(bx + r + 9 * s, oy - hh * 0.66), control2: pt(bx + r + 3 * s, oy - hh))
                p.addCurve(to: pt(bx, oy - hh * 0.95), control1: pt(bx + r * 0.22, oy - hh), control2: pt(bx + r * 0.1, oy - hh * 0.95))
                p.addCurve(to: pt(bx - r * 0.42, oy - hh), control1: pt(bx - r * 0.1, oy - hh * 0.95), control2: pt(bx - r * 0.22, oy - hh))
                p.addCurve(to: pt(bx - r + 3 * s, oy - hh * 0.58), control1: pt(bx - r - 3 * s, oy - hh), control2: pt(bx - r - 9 * s, oy - hh * 0.66))
                p.addLine(to: pt(bx - r + 3 * s, oy - 10 * s))
                p.addQuadCurve(to: pt(bx - r + 10 * s, oy), control: pt(bx - r + 3 * s, oy))
                p.closeSubpath()
            }
        }
        body = bread(1)
        crumb = bread(0.82)
        crust = body.subtracting(crumb)
        wash = crumb
        hatches = [Hatch.shadow(of: crust, shift: 6, spacing: 2.3)]
        var r = SeededRandom(state: 21)
        var p = Path()
        var placed = 0
        while placed < 16 {
            let q = pt(70 + r.next() * 60, 92 + r.next() * 58)
            if crumb.contains(q) && !(abs(q.y - 126) < 13 && abs(q.x - 100) < 20) && !(q.y < 108 && q.x > 96) {
                p.addPath(oval(q.x, q.y, 1.6 + r.next() * 1.8, 1.4 + r.next() * 1.2))
                placed += 1
            }
        }
        pores = p
    }

    var anchor: CGPoint { pt(100, 162) }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        for s: CGFloat in [-1, 1] {
            pen.stroke(line(pt(100 + s * 14, 158), pt(100 + s * 15, 168)))
            pen.shape(oval(100 + s * 17, 171, 13, 7), 1.9)
        }
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.stroke(crumb, 1.6)
        pen.fine(pores)
        let butter = pen.moved { $0.concatenate(butterTransform) }
        butter.shape(pat, 1.9)
        butter.fine(line(pt(-7, -3), pt(3, -3)))
        butter.shape(makePath { p in p.move(to: pt(4, 7)); p.addQuadCurve(to: pt(7, 13), control: pt(4.5, 12)); p.addQuadCurve(to: pt(9.5, 7), control: pt(9.5, 12)) }, 1.6)
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        pen.eye(pt(90 + f.fx, 124), f)
        pen.eye(pt(110 + f.fx, 124), f)
        pen.mouth(pt(100 + f.fx, 132), f)
    }

    func detail(_ f: CrewFrame) -> Path { pat.applying(butterTransform) }

    func extras(_ f: CrewFrame) -> [(Path, Color)] { [(crust, Color(hex: 0xE2A76B))] }
}

// MARK: - Onigiri

struct OnigiriArt: CrewArt {
    let accent = Color(hex: 0xE6D6B6)
    let detailColor = Color(hex: 0xDC8473)
    let body: Path
    let wash: Path
    let hatches: [Hatch]
    let grains: Path
    let sesame: Path
    let nori: Path
    let noriGrain: Path
    let plum = oval(100, 95, 10, 9)
    let shoulders = [pt(70, 140), pt(130, 140)]
    let brow: CGPoint? = pt(114, 118)
    let arm = ArmStyle.noodle(length: 24, hand: .loop)
    let armOffset = 12.0
    let groundWidth: CGFloat = 96

    init() {
        let w: CGFloat = 104, h: CGFloat = 96, by: CGFloat = 168
        let body = makePath { p in
            let top = pt(100, by - h), left = pt(100 - w / 2, by), right = pt(100 + w / 2, by)
            p.move(to: pt(100, by))
            p.addArc(tangent1End: right, tangent2End: top, radius: 17)
            p.addArc(tangent1End: top, tangent2End: left, radius: 25)
            p.addArc(tangent1End: left, tangent2End: right, radius: 17)
            p.closeSubpath()
        }
        self.body = body
        wash = body
        hatches = [Hatch.shadow(of: body, shift: 12)]
        var r = SeededRandom(state: 33)
        var g = Path()
        var placed = 0
        while placed < 11 {
            let q = pt(60 + r.next() * 80, 92 + r.next() * 50)
            let inside = body.contains(q) && body.contains(pt(q.x - 6, q.y)) && body.contains(pt(q.x + 6, q.y - 4))
            if inside && !(q.y > 118 && q.y < 140 && abs(q.x - 100) < 18) && q.y < 142 && !(abs(q.x - 100) < 8 && q.y < 101) {
                let angle = r.next() * .pi
                g.addPath(oval(0, 0, 6, 2.8).applying(CGAffineTransform(rotationAngle: angle).concatenating(CGAffineTransform(translationX: q.x, y: q.y))))
                placed += 1
            }
        }
        grains = g
        var s = Path()
        for (x, y, a) in [(91.0, 101.0, 20.0), (110.0, 104.0, -30.0), (104.0, 112.0, 70.0)] {
            s.addPath(oval(0, 0, 3.6, 2).applying(CGAffineTransform(rotationAngle: a * .pi / 180).concatenating(CGAffineTransform(translationX: x, y: y))))
        }
        sesame = s
        nori = Path(roundedRect: CGRect(x: 81, y: 143, width: 38, height: 27), cornerRadius: 2).intersection(body)
        var lines = Path()
        for x in stride(from: 86.0, through: 115.0, by: 6.0) { lines.move(to: pt(x, 147)); lines.addLine(to: pt(x + 1, 166)) }
        noriGrain = lines
    }

    func feet(_ pen: Pen, _ f: CrewFrame) { ovalFeet(pen, [86, 114], width: 15) }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.c.stroke(grains, with: .color(Pen.ink.opacity(0.55)), lineWidth: 0.95)
        pen.solid(sesame)
        pen.solid(nori)
        var n = pen.c
        n.clip(to: nori)
        n.stroke(noriGrain, with: .color(Pen.paper.opacity(0.28)), lineWidth: 0.8)
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        pen.eye(pt(91 + f.fx, 127), f)
        pen.eye(pt(109 + f.fx, 127), f)
        pen.mouth(pt(100 + f.fx, 135), f, width: 4, depth: 3)
    }

    func front(_ pen: Pen, _ f: CrewFrame) {
        pen.shape(plum, 1.6)
        pen.fine(bend(pt(100, 90.5), pt(104, 87), pt(108, 89)))
    }

    func detail(_ f: CrewFrame) -> Path { plum }
}
