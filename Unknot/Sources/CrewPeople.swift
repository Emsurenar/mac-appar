import SwiftUI

// The people in the Stretch Crew. They share the crew's build: a big head on a small body, noodle arms and
// the same moves, drawn with more detail: hair strand by strand, folds in the cloth, buttons and glasses.

// MARK: - Shared parts

/// A lock of long hair falling from the temple to the shoulder, for the left side (mirror with `side` 1).
/// `waves` sets how much it ripples.
private func lock(side: CGFloat, outer: CGFloat, inner: CGFloat, top: CGFloat, bottom: CGFloat, waves: CGFloat) -> Path {
    func x(_ v: CGFloat) -> CGFloat { 100 + side * (v - 100) }
    let mid = (top + bottom) / 2
    return makePath { p in
        p.move(to: pt(x(inner + 2), top))
        p.addCurve(to: pt(x(outer), mid), control1: pt(x(outer + 2), top + 6), control2: pt(x(outer - waves), mid - 10))
        p.addCurve(to: pt(x(outer + 4), bottom), control1: pt(x(outer + waves), mid + 8), control2: pt(x(outer), bottom - 6))
        p.addQuadCurve(to: pt(x(inner + 3), bottom - 4), control: pt(x((outer + inner) / 2 + 2), bottom + 3))
        p.addCurve(to: pt(x(inner), top + 14), control1: pt(x(inner + 4), bottom - 16), control2: pt(x(inner - 1), mid - 4))
        p.closeSubpath()
    }
}

/// Fine wavy strands down a lock of hair, so it reads as hair rather than a solid shape.
private func strands(side: CGFloat, from: CGFloat, to: CGFloat, top: CGFloat, bottom: CGFloat, count: Int, waves: CGFloat) -> Path {
    makePath { p in
        for i in 0..<count {
            let k = CGFloat(i) / CGFloat(max(count - 1, 1))
            let x0 = 100 + side * (from + (to - from) * k - 100)
            let mid = (top + bottom) / 2
            p.move(to: pt(x0, top + 4 + k * 3))
            p.addCurve(to: pt(x0 + side * 1.5, bottom - 3 - k * 2),
                       control1: pt(x0 - side * waves, mid - 6), control2: pt(x0 + side * waves, mid + 6))
        }
    }
}

/// Short strokes scattered over a region: beard, stubble-free cropped hair, cloth texture.
private func texture(in region: Path, count: Int, seed: UInt64, length: CGFloat, angle: Double) -> Path {
    var r = SeededRandom(state: seed)
    let box = region.boundingRect
    let dx = CGFloat(cos(angle * .pi / 180)) * length, dy = CGFloat(sin(angle * .pi / 180)) * length
    return makePath { p in
        var placed = 0
        var tries = 0
        while placed < count && tries < count * 20 {
            tries += 1
            let q = pt(box.minX + r.next() * box.width, box.minY + r.next() * box.height)
            guard region.contains(q) else { continue }
            let wobble = (r.next() - 0.5) * 0.6
            p.move(to: q)
            p.addLine(to: pt(q.x + dx + wobble, q.y + dy))
            placed += 1
        }
    }
}

/// Ears with a fine inner curve, drawn before the head so it overlaps them.
private func drawEars(_ pen: Pen, at xs: [CGFloat], y: CGFloat, w: CGFloat, h: CGFloat) {
    for x in xs {
        pen.shape(oval(x, y, w, h), 1.8)
        let s: CGFloat = x < 100 ? -1 : 1
        pen.fine(bend(pt(x - s * 1.5, y - h * 0.3), pt(x + s * 1.5, y), pt(x - s * 1, y + h * 0.3)))
    }
}

/// A jacket: shoulders, slightly flared sides and a straight hem.
private func jacket(left: CGFloat = 70, right: CGFloat = 130, top: CGFloat = 116, hem: CGFloat = 166) -> Path {
    makePath { p in
        p.move(to: pt(left, top + 8))
        p.addCurve(to: pt(left + 14, top), control1: pt(left + 1, top + 3), control2: pt(left + 7, top))
        p.addLine(to: pt(right - 14, top))
        p.addCurve(to: pt(right, top + 8), control1: pt(right - 7, top), control2: pt(right - 1, top + 3))
        p.addCurve(to: pt(right + 4, hem - 6), control1: pt(right + 3, top + 20), control2: pt(right + 5, hem - 16))
        p.addQuadCurve(to: pt(right - 6, hem), control: pt(right + 4, hem))
        p.addLine(to: pt(left + 6, hem))
        p.addQuadCurve(to: pt(left - 4, hem - 6), control: pt(left - 4, hem))
        p.addCurve(to: pt(left, top + 8), control1: pt(left - 5, hem - 16), control2: pt(left - 3, top + 20))
    }
}

// MARK: - Stefan

/// Stefan Löfven, drawn the same way as the rest of the crew: a dark suit, a red tie, a shiny crown with grey
/// hair at the sides, and noodle arms like everyone else.
struct StefanArt: CrewArt {
    let accent = Color(hex: 0x46536C)            // the suit, dark navy
    let detailColor = Color(hex: 0xD45A4C)       // the tie
    let body: Path                               // the suit
    let wash: Path
    let hatches: [Hatch]
    let shirt: Path
    let lapels: Path
    let tie: Path
    let head: Path
    let headHatch: Hatch
    let ears: [Path]
    let hair: Path
    let hairStrands: Path
    let skin: Path
    let shoulders = [pt(71, 128), pt(129, 128)]
    let arm = ArmStyle.noodle(length: 26, hand: .loop)
    let armOffset = -12.0
    let brow: CGPoint? = pt(113, 88)
    let reachExtra: CGFloat = 30
    let groundWidth: CGFloat = 84

    init() {
        let suit = makePath { p in
            p.move(to: pt(70, 124))
            p.addCurve(to: pt(84, 116), control1: pt(71, 119), control2: pt(77, 116))
            p.addLine(to: pt(116, 116))
            p.addCurve(to: pt(130, 124), control1: pt(123, 116), control2: pt(129, 119))
            p.addCurve(to: pt(134, 160), control1: pt(133, 136), control2: pt(135, 150))
            p.addQuadCurve(to: pt(124, 166), control: pt(134, 166))
            p.addLine(to: pt(76, 166))
            p.addQuadCurve(to: pt(66, 160), control: pt(66, 166))
            p.addCurve(to: pt(70, 124), control1: pt(65, 150), control2: pt(67, 136))
        }
        body = suit
        shirt = makePath { p in
            p.move(to: pt(91, 116)); p.addLine(to: pt(109, 116)); p.addLine(to: pt(100, 139)); p.closeSubpath()
        }
        lapels = makePath { p in
            p.move(to: pt(87, 117)); p.addLine(to: pt(99, 148))
            p.move(to: pt(113, 117)); p.addLine(to: pt(101, 148))
            p.move(to: pt(87, 117)); p.addLine(to: pt(84, 127)); p.addLine(to: pt(91, 131))
            p.move(to: pt(113, 117)); p.addLine(to: pt(116, 127)); p.addLine(to: pt(109, 131))
        }
        tie = makePath { p in
            p.move(to: pt(97.5, 117)); p.addLine(to: pt(102.5, 117)); p.addLine(to: pt(101.6, 121.5))
            p.addLine(to: pt(103.6, 137)); p.addLine(to: pt(100, 141.5)); p.addLine(to: pt(96.4, 137))
            p.addLine(to: pt(98.4, 121.5)); p.closeSubpath()
        }
        wash = suit.subtracting(shirt)
        hatches = [Hatch.shadow(of: suit, shift: 12)]

        let face = superellipse(cx: 100, cy: 90, a: 25, b: 28, n: 2.3)
        head = face
        // A narrow shadow along the edge only; any wider and it reads as stubble
        headHatch = Hatch.shadow(of: face, shift: 5, spacing: 2.9)
        ears = [oval(73, 95, 9, 13), oval(127, 95, 9, 13)]
        // Short grey hair only at the sides and round the back; the crown is bare and shiny
        let sides = makePath { p in
            p.move(to: pt(74, 80)); p.addQuadCurve(to: pt(77, 103), control: pt(72, 92))
            p.addLine(to: pt(82, 101)); p.addQuadCurve(to: pt(80, 80), control: pt(79.5, 90)); p.closeSubpath()
            p.move(to: pt(126, 80)); p.addQuadCurve(to: pt(123, 103), control: pt(128, 92))
            p.addLine(to: pt(118, 101)); p.addQuadCurve(to: pt(120, 80), control: pt(120.5, 90)); p.closeSubpath()
        }
        let hairShape = sides.intersection(face)
        hair = hairShape
        // Drawn as short strokes, without an outline, so it reads as hair and not as headphones
        hairStrands = makePath { p in
            var r = SeededRandom(state: 12)
            for side: CGFloat in [-1, 1] {
                for i in 0..<9 {
                    let y = 81 + CGFloat(i) * 2.4 + r.next()
                    let x = 100 + side * (23.5 - r.next() * 3 - abs(CGFloat(i) - 4) * 0.25)
                    p.move(to: pt(x, y)); p.addLine(to: pt(x - side * (1.8 + r.next() * 1.5), y + 2.2))
                }
            }
        }
        let shine = bend(pt(85, 71), pt(91, 66.5), pt(99, 65.5)).strokedPath(StrokeStyle(lineWidth: 2.4, lineCap: .round))
        skin = face.subtracting(hairShape).subtracting(shine)
    }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        // Polished black shoes
        for x: CGFloat in [86, 114] { pen.solid(oval(x, 171, 18, 8)) }
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.paper(shirt)
        pen.fine(shirt)
        pen.fine(lapels)
        pen.shape(tie, 1.3)
        for y: CGFloat in [152, 159] { pen.c.stroke(oval(100, y, 2.6, 2.6), with: .color(Pen.ink), lineWidth: 1) }
        for ear in ears {
            pen.shape(ear, 1.8)
        }
        pen.fine(bend(pt(71.5, 91), pt(74.5, 95), pt(72, 99)))
        pen.fine(bend(pt(128.5, 91), pt(125.5, 95), pt(128, 99)))
        pen.shape(head)
        pen.hatch(headHatch)
        pen.paper(hair)
        pen.c.stroke(hairStrands, with: .color(Pen.ink.opacity(0.7)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        let x = f.fx
        // Thick, level brows give him his calm look
        pen.stroke(bend(pt(84.5 + x, 86), pt(90 + x, 84), pt(95.5 + x, 86)), 1.9)
        pen.stroke(bend(pt(104.5 + x, 86), pt(110 + x, 84), pt(115.5 + x, 86)), 1.9)
        pen.eye(pt(90 + x, 93), f, r: 2.3)
        pen.eye(pt(110 + x, 93), f, r: 2.3)
        pen.fine(bend(pt(100 + x, 96), pt(97 + x, 102.5), pt(101.5 + x, 103)))
        pen.mouth(pt(100 + x, 109), f, width: 5.5, depth: 2.6)
    }

    func detail(_ f: CrewFrame) -> Path { tie }

    func extras(_ f: CrewFrame) -> [(Path, Color)] {
        [(skin, Color(hex: 0xF0CDB4)), (hair, Color(hex: 0xDAD6D0)), (ears.reduce(Path()) { $0.union($1) }.subtracting(head), Color(hex: 0xEBC0A4))]
    }
}


// MARK: - Jesus

/// Jesus of Nazareth: long hair parted in the middle, a beard, a white tunic with a red mantle over one shoulder,
/// sandals and a fine halo.
struct JesusArt: CrewArt {
    let accent = Color(hex: 0xEDE3CF)            // the tunic, undyed linen
    let detailColor = Color(hex: 0xBF5E4E)       // the mantle
    let body: Path
    let wash: Path
    let hatches: [Hatch]
    let mantle: Path
    let mantleTint: Path                         // the mantle where hair and beard don't fall over it
    let mantleHatch: Hatch
    let folds: Path
    let mantleFolds: Path
    let hairBack: Path
    let hairCap: Path
    let hairLines: Path
    let face: Path
    let faceHatch: Hatch
    let beard: Path
    let beardLines: Path
    let skin: Path
    let shoulders = [pt(75, 128), pt(125, 128)]
    let arm = ArmStyle.noodle(length: 26, hand: .loop)
    let armOffset = -12.0
    let brow: CGPoint? = pt(112, 88)
    let reachExtra: CGFloat = 30
    let groundWidth: CGFloat = 92

    init() {
        let tunic = makePath { p in
            p.move(to: pt(74, 124))
            p.addCurve(to: pt(86, 116), control1: pt(75, 119), control2: pt(80, 116))
            p.addLine(to: pt(114, 116))
            p.addCurve(to: pt(126, 124), control1: pt(120, 116), control2: pt(125, 119))
            p.addCurve(to: pt(137, 164), control1: pt(130, 140), control2: pt(137, 153))
            p.addQuadCurve(to: pt(63, 164), control: pt(100, 170))
            p.addCurve(to: pt(74, 124), control1: pt(63, 153), control2: pt(70, 140))
        }
        body = tunic
        let sash = makePath { p in
            p.move(to: pt(69, 131))
            p.addQuadCurve(to: pt(94, 116), control: pt(73, 117))
            p.addQuadCurve(to: pt(137, 146), control: pt(119, 123))
            p.addLine(to: pt(139, 164))
            p.addQuadCurve(to: pt(69, 131), control: pt(103, 143))
            p.closeSubpath()
        }.intersection(tunic)
        mantle = sash
        mantleHatch = Hatch.shadow(of: sash, shift: 8, spacing: 2.6)
        wash = tunic.subtracting(sash)
        hatches = [Hatch.shadow(of: tunic, shift: 12)]
        folds = makePath { p in
            p.move(to: pt(84, 146)); p.addQuadCurve(to: pt(79, 165), control: pt(80, 156))
            p.move(to: pt(96, 150)); p.addQuadCurve(to: pt(95, 167), control: pt(97, 159))
            p.move(to: pt(108, 151)); p.addQuadCurve(to: pt(112, 167), control: pt(109, 160))
            p.move(to: pt(91, 155)); p.addQuadCurve(to: pt(88, 166), control: pt(89, 161))
        }
        mantleFolds = makePath { p in
            p.move(to: pt(86, 124)); p.addQuadCurve(to: pt(128, 150), control: pt(112, 130))
            p.move(to: pt(80, 130)); p.addQuadCurve(to: pt(124, 156), control: pt(104, 139))
            p.move(to: pt(98, 120)); p.addQuadCurve(to: pt(133, 142), control: pt(120, 126))
        }.intersection(sash)

        let head = superellipse(cx: 100, cy: 91, a: 21, b: 26, n: 2.2)
        face = head
        faceHatch = Hatch.shadow(of: head, shift: 5, spacing: 2.9)
        let crown = oval(100, 85, 50, 44)
        hairBack = crown
            .union(lock(side: -1, outer: 72, inner: 85, top: 84, bottom: 134, waves: 3))
            .union(lock(side: 1, outer: 72, inner: 85, top: 84, bottom: 134, waves: 3))
        // Parted in the middle, swept down to both sides
        let above = makePath { p in
            p.move(to: pt(70, 58)); p.addLine(to: pt(130, 58)); p.addLine(to: pt(130, 90))
            p.addCurve(to: pt(100, 73), control1: pt(122, 79), control2: pt(108, 72))
            p.addCurve(to: pt(70, 90), control1: pt(92, 72), control2: pt(78, 79))
            p.closeSubpath()
        }
        hairCap = head.intersection(above)
        hairLines = makePath { p in
            for k: CGFloat in [0, 1, 2, 3] {
                for s: CGFloat in [-1, 1] {
                    p.move(to: pt(100 + s * 1, 66 + k * 0.5))
                    p.addCurve(to: pt(100 + s * (24 + k * 1.5), 90 + k * 3), control1: pt(100 + s * (8 + k * 2), 67 + k * 2), control2: pt(100 + s * (19 + k), 74 + k * 3))
                }
            }
        }
        .union(strands(side: -1, from: 74, to: 84, top: 92, bottom: 132, count: 4, waves: 2.5))
        .union(strands(side: 1, from: 74, to: 84, top: 92, bottom: 132, count: 4, waves: 2.5))
        let full = makePath { p in
            p.move(to: pt(79.5, 96))
            p.addCurve(to: pt(100, 125), control1: pt(78.5, 112), control2: pt(88, 125))
            p.addCurve(to: pt(120.5, 96), control1: pt(112, 125), control2: pt(121.5, 112))
            p.addCurve(to: pt(100, 104), control1: pt(116, 103), control2: pt(108, 101))
            p.addCurve(to: pt(79.5, 96), control1: pt(92, 101), control2: pt(84, 103))
            p.closeSubpath()
        }
        beard = full
        mantleTint = sash.subtracting(hairBack).subtracting(full)
        beardLines = texture(in: full.subtracting(oval(100, 111, 13, 8)), count: 46, seed: 4, length: 2.4, angle: 95)
        skin = head.subtracting(hairCap).subtracting(full)
    }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        // Sandals: a sole, a strap across the toes and one round the ankle
        for x: CGFloat in [86, 114] {
            pen.shape(oval(x, 171.5, 17, 6.5), 1.6)
            pen.fine(line(pt(x - 6, 170), pt(x + 6, 170)))
            pen.fine(bend(pt(x - 3, 168.5), pt(x, 166.5), pt(x + 3, 168.5)))
        }
    }

    func behind(_ pen: Pen, _ f: CrewFrame) {
        // A fine halo, two rings with gold between them
        let ring = oval(100, 83, 66, 66).subtracting(oval(100, 83, 59, 59))
        pen.tint(oval(100, 83, 59, 59), Color(hex: 0xF3E2A6).opacity(0.45))
        pen.tint(ring, Color(hex: 0xE5C25E))
        pen.c.stroke(oval(100, 83, 66, 66), with: .color(Pen.ink), lineWidth: 1.25)
        pen.c.stroke(oval(100, 83, 59, 59), with: .color(Pen.ink), lineWidth: 0.9)
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.fine(folds)
        pen.shape(mantle, 1.6)
        pen.hatch(mantleHatch)
        pen.fine(mantleFolds)
        pen.shape(hairBack, 1.8)
        pen.shape(face)
        pen.hatch(faceHatch)
        pen.shape(hairCap, 1.4)
        pen.c.stroke(hairLines, with: .color(Pen.ink.opacity(0.75)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        let x = f.fx
        let b = pen.moved { $0.translateBy(x: x * 0.5, y: 0) }
        b.shape(beard, 1.5)
        b.c.stroke(beardLines, with: .color(Pen.ink.opacity(0.6)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        pen.stroke(bend(pt(86 + x, 87), pt(91 + x, 85.5), pt(96 + x, 87.5)), 1.5)
        pen.stroke(bend(pt(104 + x, 87.5), pt(109 + x, 85.5), pt(114 + x, 87)), 1.5)
        pen.eye(pt(92 + x, 93), f, r: 2.2)
        pen.eye(pt(108 + x, 93), f, r: 2.2)
        pen.fine(bend(pt(100 + x, 95.5), pt(97.5 + x, 102), pt(101 + x, 102.5)))
        // The moustache sits over the mouth
        pen.mouth(pt(100 + x, 112), f, width: 4.5, depth: 2.6)
        pen.stroke(bend(pt(100 + x, 105.5), pt(95 + x, 105), pt(92.5 + x, 107.5)), 1.5)
        pen.stroke(bend(pt(100 + x, 105.5), pt(105 + x, 105), pt(107.5 + x, 107.5)), 1.5)
    }

    func detail(_ f: CrewFrame) -> Path { mantleTint }

    func extras(_ f: CrewFrame) -> [(Path, Color)] {
        let hair = hairBack.subtracting(face).union(hairCap)
        return [(skin, Color(hex: 0xEBC4A3)), (hair, Color(hex: 0xA77B55)),
                (beard.applying(CGAffineTransform(translationX: f.fx * 0.5, y: 0)), Color(hex: 0xA77B55))]
    }
}

// MARK: - Gandhi

/// Mahatma Gandhi: a bald head, round wire glasses, a white moustache, a khadi shawl over a dhoti, and sandals.
struct GandhiArt: CrewArt {
    let accent = Color(hex: 0xEEE6D6)            // hand-spun khadi
    let detailColor = Color(hex: 0xCDA77E)       // the shawl's border
    let body: Path
    let wash: Path
    let hatches: [Hatch]
    let shawlEdge: Path
    let border: Path
    let folds: Path
    let head: Path
    let headHatch: Hatch
    let fringe: Path
    let skin: Path
    let shoulders = [pt(75, 128), pt(125, 128)]
    let arm = ArmStyle.noodle(length: 26, hand: .loop)
    let armOffset = -12.0
    let brow: CGPoint? = pt(112, 87)
    let reachExtra: CGFloat = 30
    let groundWidth: CGFloat = 84

    init() {
        let cloth = makePath { p in
            p.move(to: pt(74, 126))
            p.addCurve(to: pt(86, 117), control1: pt(75, 120), control2: pt(80, 117))
            p.addLine(to: pt(114, 117))
            p.addCurve(to: pt(126, 126), control1: pt(120, 117), control2: pt(125, 120))
            p.addCurve(to: pt(124, 162), control1: pt(129, 140), control2: pt(126, 153))
            p.addQuadCurve(to: pt(76, 162), control: pt(100, 165))
            p.addCurve(to: pt(74, 126), control1: pt(74, 153), control2: pt(71, 140))
        }
        body = cloth
        // The shawl wraps from the left shoulder down to the right hip; a woven band runs along its edge
        shawlEdge = bend(pt(79, 121), pt(104, 128), pt(126, 148))
        border = bend(pt(79, 121), pt(104, 128), pt(126, 148)).strokedPath(StrokeStyle(lineWidth: 5))
            .applying(CGAffineTransform(translationX: 0, y: 3.5)).intersection(cloth)
        wash = cloth
        hatches = [Hatch.shadow(of: cloth, shift: 11)]
        folds = makePath { p in
            // Drapes in the shawl, the knot of the dhoti at the waist and its folds below
            p.move(to: pt(84, 126)); p.addQuadCurve(to: pt(80, 146), control: pt(84, 136))
            p.move(to: pt(94, 131)); p.addQuadCurve(to: pt(92, 148), control: pt(95, 140))
            p.move(to: pt(112, 136)); p.addQuadCurve(to: pt(118, 146), control: pt(113, 141))
            p.move(to: pt(76, 149)); p.addQuadCurve(to: pt(124, 149), control: pt(100, 153))
            p.move(to: pt(100, 151)); p.addQuadCurve(to: pt(94, 163), control: pt(96, 157))
            p.move(to: pt(100, 151)); p.addQuadCurve(to: pt(106, 163), control: pt(104, 157))
            p.move(to: pt(86, 152)); p.addQuadCurve(to: pt(83, 162), control: pt(84, 157))
            p.move(to: pt(114, 152)); p.addQuadCurve(to: pt(117, 162), control: pt(116, 157))
        }
        let face = superellipse(cx: 100, cy: 90, a: 24, b: 26, n: 2.1)
        head = face
        headHatch = Hatch.shadow(of: face, shift: 5, spacing: 2.9)
        fringe = texture(in: face.intersection(Path(CGRect(x: 75, y: 90, width: 6, height: 13)))
            .union(face.intersection(Path(CGRect(x: 119, y: 90, width: 6, height: 13)))), count: 16, seed: 8, length: 2, angle: 100)
        skin = face
    }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        // Thin bare shins, feet and flat sandals
        for x: CGFloat in [91, 109] {
            let shin = Path(roundedRect: CGRect(x: x - 2.6, y: 160, width: 5.2, height: 9), cornerRadius: 2.6)
            pen.shape(shin, 1.4)
            pen.tint(shin, Color(hex: 0xC69772))
        }
        for x: CGFloat in [89, 111] {
            pen.shape(oval(x, 172, 16, 4.6), 1.5)
            let foot = oval(x, 169.5, 11, 5)
            pen.shape(foot, 1.3)
            pen.tint(foot, Color(hex: 0xC69772))
            pen.fine(line(pt(x - 4, 170), pt(x + 4, 170)))
        }
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.fine(folds)
        pen.stroke(shawlEdge, 1.5)
        pen.fine(bend(pt(79, 127.5), pt(104, 134.5), pt(124, 154)))
        drawEars(pen, at: [74.5, 125.5], y: 94, w: 10, h: 15)
        pen.shape(head)
        pen.hatch(headHatch)
        pen.c.stroke(fringe, with: .color(Pen.ink.opacity(0.6)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        // A few lines on the forehead
        pen.fine(bend(pt(91, 73), pt(100, 71.5), pt(109, 73)))
        pen.fine(bend(pt(93, 77), pt(100, 76), pt(107, 77)))
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        let x = f.fx
        pen.fine(bend(pt(85 + x, 84), pt(90.5 + x, 82), pt(96 + x, 84)))
        pen.fine(bend(pt(104 + x, 84), pt(109.5 + x, 82), pt(115 + x, 84)))
        pen.eye(pt(91 + x, 92), f, r: 2.0)
        pen.eye(pt(109 + x, 92), f, r: 2.0)
        // Round wire glasses
        let glasses = makePath { p in
            p.addEllipse(in: CGRect(x: 84.5 + x, y: 85.5, width: 13, height: 13))
            p.addEllipse(in: CGRect(x: 102.5 + x, y: 85.5, width: 13, height: 13))
            p.move(to: pt(97.5 + x, 91)); p.addQuadCurve(to: pt(102.5 + x, 91), control: pt(100 + x, 88.5))
            p.move(to: pt(84.5 + x, 91)); p.addLine(to: pt(77, 90))
            p.move(to: pt(115.5 + x, 91)); p.addLine(to: pt(123, 90))
        }
        pen.stroke(glasses, 1.3)
        pen.c.stroke(line(pt(87.5 + x, 89), pt(90 + x, 87)), with: .color(Pen.ink.opacity(0.4)), lineWidth: 0.8)
        pen.c.stroke(line(pt(105.5 + x, 89), pt(108 + x, 87)), with: .color(Pen.ink.opacity(0.4)), lineWidth: 0.8)
        pen.fine(bend(pt(100 + x, 96), pt(96.5 + x, 102.5), pt(101 + x, 103)))
        // Smile lines, then a small white moustache over the smile
        pen.fine(bend(pt(87 + x, 102), pt(86.5 + x, 107), pt(89 + x, 111)))
        pen.fine(bend(pt(113 + x, 102), pt(113.5 + x, 107), pt(111 + x, 111)))
        pen.mouth(pt(100 + x, 110), f, width: 6.5, depth: 3)
        let moustache = Path(roundedRect: CGRect(x: 94.5 + x, y: 103.5, width: 11, height: 3.6), cornerRadius: 1.8)
        pen.shape(moustache, 1.1)
        pen.tint(moustache, Color(hex: 0xDCD8D2))
    }

    func detail(_ f: CrewFrame) -> Path { border }

    func extras(_ f: CrewFrame) -> [(Path, Color)] {
        [(skin, Color(hex: 0xC99A73)), (oval(74.5, 94, 10, 15).union(oval(125.5, 94, 10, 15)).subtracting(head), Color(hex: 0xBF8E68))]
    }
}

// MARK: - Obama

/// Barack Obama: close-cropped hair going grey at the temples, a wide smile, a charcoal suit, a blue tie,
/// a flag pin and a pocket square.
struct ObamaArt: CrewArt {
    let accent = Color(hex: 0x4F545C)            // charcoal
    let detailColor = Color(hex: 0x4D74AE)       // the tie
    let body: Path
    let wash: Path
    let hatches: [Hatch]
    let shirt: Path
    let lapels: Path
    let tie: Path
    let pocketSquare: Path
    let head: Path
    let headHatch: Hatch
    let hair: Path
    let hairDots: Path
    let temples: Path
    let skin: Path
    let shoulders = [pt(71, 128), pt(129, 128)]
    let arm = ArmStyle.noodle(length: 26, hand: .loop)
    let armOffset = -12.0
    let brow: CGPoint? = pt(113, 88)
    let reachExtra: CGFloat = 30
    let groundWidth: CGFloat = 84

    init() {
        let suit = jacket(left: 71, right: 129)
        body = suit
        shirt = makePath { p in
            p.move(to: pt(91, 116)); p.addLine(to: pt(109, 116)); p.addLine(to: pt(100, 140)); p.closeSubpath()
        }
        lapels = makePath { p in
            p.move(to: pt(88, 117)); p.addLine(to: pt(99, 149))
            p.move(to: pt(112, 117)); p.addLine(to: pt(101, 149))
            p.move(to: pt(88, 117)); p.addLine(to: pt(84.5, 128)); p.addLine(to: pt(91.5, 132))
            p.move(to: pt(112, 117)); p.addLine(to: pt(115.5, 128)); p.addLine(to: pt(108.5, 132))
            p.move(to: pt(78, 140)); p.addLine(to: pt(90, 140))      // the breast pocket
        }
        tie = makePath { p in
            p.move(to: pt(97.5, 117)); p.addLine(to: pt(102.5, 117)); p.addLine(to: pt(101.5, 121.5))
            p.addLine(to: pt(103.5, 138)); p.addLine(to: pt(100, 142.5)); p.addLine(to: pt(96.5, 138))
            p.addLine(to: pt(98.5, 121.5)); p.closeSubpath()
        }
        pocketSquare = makePath { p in
            p.move(to: pt(80, 140)); p.addLine(to: pt(82.5, 136.5)); p.addLine(to: pt(84.5, 139)); p.addLine(to: pt(86.5, 136)); p.addLine(to: pt(88.5, 140)); p.closeSubpath()
        }
        wash = suit.subtracting(shirt).subtracting(pocketSquare)
        hatches = [Hatch.shadow(of: suit, shift: 12)]
        let face = superellipse(cx: 100, cy: 90, a: 23.5, b: 28, n: 2.4)
        head = face
        headHatch = Hatch.shadow(of: face, shift: 5, spacing: 2.9)
        let above = makePath { p in
            p.move(to: pt(70, 55)); p.addLine(to: pt(130, 55)); p.addLine(to: pt(130, 93)); p.addLine(to: pt(124, 93))
            p.addCurve(to: pt(100, 74.5), control1: pt(123, 80), control2: pt(112, 74))
            p.addCurve(to: pt(76, 93), control1: pt(88, 74), control2: pt(77, 80))
            p.addLine(to: pt(70, 93)); p.closeSubpath()
        }
        hair = face.intersection(above)
        // Grey at the temples; each side clipped on its own, since one path with two shapes clips unreliably
        temples = hair.intersection(oval(78, 87, 10, 16)).union(hair.intersection(oval(122, 87, 10, 16)))
        var r = SeededRandom(state: 31)
        hairDots = makePath { p in
            var placed = 0
            while placed < 150 {
                let q = pt(76 + r.next() * 48, 61 + r.next() * 33)
                if face.intersection(above).contains(q) {
                    let s = 0.35 + r.next() * 0.35
                    p.addEllipse(in: CGRect(x: q.x - s, y: q.y - s, width: s * 2, height: s * 2))
                    placed += 1
                }
            }
        }
        skin = face.subtracting(hair)
    }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        for x: CGFloat in [86, 114] { pen.solid(oval(x, 171, 18, 8)) }
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.paper(shirt)
        pen.fine(shirt)
        pen.fine(lapels)
        pen.paper(pocketSquare)
        pen.fine(pocketSquare)
        pen.shape(tie, 1.3)
        pen.fine(line(pt(98.3, 126), pt(102.6, 129)))
        pen.fine(line(pt(97.8, 132), pt(103.2, 135.5)))
        // A small flag pin on his lapel
        let pin = CGRect(x: 110.5, y: 124, width: 5, height: 3.4)
        pen.paper(Path(pin))
        pen.c.stroke(Path(pin), with: .color(Pen.ink), lineWidth: 0.7)
        pen.tint(Path(CGRect(x: pin.minX, y: pin.minY, width: 2.2, height: 1.8)), Color(hex: 0x3E5C9A))
        for k in 0..<2 { pen.tint(Path(CGRect(x: pin.minX + 2.2, y: pin.minY + CGFloat(k) * 1.4 + 0.3, width: 2.8, height: 0.7)), Color(hex: 0xC54B45)) }
        pen.tint(Path(CGRect(x: pin.minX, y: pin.minY + 2.4, width: 5, height: 0.7)), Color(hex: 0xC54B45))
        for y: CGFloat in [152, 159] { pen.c.stroke(oval(100, y, 2.6, 2.6), with: .color(Pen.ink), lineWidth: 1) }
        drawEars(pen, at: [75, 125], y: 94, w: 8.5, h: 13)
        pen.shape(head)
        pen.hatch(headHatch)
        pen.fine(hair)
        pen.c.fill(hairDots, with: .color(Pen.ink.opacity(0.55)))
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        let x = f.fx
        pen.stroke(bend(pt(84.5 + x, 86.5), pt(90 + x, 84), pt(96 + x, 86)), 1.7)
        pen.stroke(bend(pt(104 + x, 86), pt(110 + x, 84), pt(115.5 + x, 86.5)), 1.7)
        pen.eye(pt(91 + x, 93), f, r: 2.2)
        pen.eye(pt(109 + x, 93), f, r: 2.2)
        pen.fine(bend(pt(100 + x, 96), pt(97.5 + x, 102.5), pt(100.5 + x, 103.5)))
        pen.fine(bend(pt(95.5 + x, 103), pt(96.5 + x, 104.6), pt(98.5 + x, 104.4)))
        pen.fine(bend(pt(104.5 + x, 103), pt(103.5 + x, 104.6), pt(101.5 + x, 104.4)))
        // The wide smile, with the lines that come with it
        pen.fine(bend(pt(87 + x, 100), pt(85.5 + x, 106), pt(88.5 + x, 111.5)))
        pen.fine(bend(pt(113 + x, 100), pt(114.5 + x, 106), pt(111.5 + x, 111.5)))
        pen.mouth(pt(100 + x, 110.5), f, width: 7, depth: 3.6)
    }

    func detail(_ f: CrewFrame) -> Path { tie }

    func extras(_ f: CrewFrame) -> [(Path, Color)] {
        [(skin, Color(hex: 0xB9876A)), (oval(75, 94, 8.5, 13).union(oval(125, 94, 8.5, 13)).subtracting(head), Color(hex: 0xAE7D60)),
         (hair.subtracting(temples), Color(hex: 0x82786F)), (temples, Color(hex: 0xB4AEA8))]
    }
}

// MARK: - Descartes

/// René Descartes as Frans Hals painted him: long dark hair, a thin moustache and a tuft under the lip,
/// a black doublet and a wide white collar.
struct DescartesArt: CrewArt {
    let accent = Color(hex: 0x45454C)            // black cloth
    let detailColor = Color(hex: 0xEDE7DA)       // the linen collar
    let body: Path
    let wash: Path
    let hatches: [Hatch]
    let cloth: Hatch                             // engraved all over, so the doublet reads as black
    let collar: Path
    let collarLines: Path
    let buttons: Path
    let hairBack: Path
    let hairCap: Path
    let hairLines: Path
    let face: Path
    let faceHatch: Hatch
    let skin: Path
    let shoulders = [pt(73, 128), pt(127, 128)]
    let arm = ArmStyle.noodle(length: 26, hand: .loop)
    let armOffset = -12.0
    let brow: CGPoint? = pt(112, 88)
    let reachExtra: CGFloat = 30
    let groundWidth: CGFloat = 84

    init() {
        let doublet = jacket(left: 72, right: 128)
        body = doublet
        let band = makePath { p in
            p.move(to: pt(100, 117))
            p.addQuadCurve(to: pt(79, 120), control: pt(86, 116))
            p.addQuadCurve(to: pt(84, 134), control: pt(77, 129))
            p.addQuadCurve(to: pt(100, 131), control: pt(92, 135))
            p.addQuadCurve(to: pt(116, 134), control: pt(108, 135))
            p.addQuadCurve(to: pt(121, 120), control: pt(123, 129))
            p.addQuadCurve(to: pt(100, 117), control: pt(114, 116))
            p.closeSubpath()
        }
        collar = band
        collarLines = makePath { p in
            p.move(to: pt(100, 118)); p.addLine(to: pt(100, 131))
            p.move(to: pt(88, 124)); p.addQuadCurve(to: pt(90, 132), control: pt(88, 129))
            p.move(to: pt(112, 124)); p.addQuadCurve(to: pt(110, 132), control: pt(112, 129))
        }
        buttons = makePath { p in
            for y in stride(from: 137.0, through: 161.0, by: 5.0) { p.addEllipse(in: CGRect(x: 98.8, y: y - 1.2, width: 2.4, height: 2.4)) }
        }
        wash = doublet.subtracting(band)
        hatches = [Hatch.shadow(of: doublet, shift: 12)]
        cloth = Hatch(doublet.subtracting(band), spacing: 3.2, angle: -40)

        let head = superellipse(cx: 100, cy: 90, a: 22, b: 27, n: 2.2)
        face = head
        faceHatch = Hatch.shadow(of: head, shift: 5, spacing: 2.9)
        hairBack = oval(100, 85, 54, 46)
            .union(lock(side: -1, outer: 69, inner: 84, top: 82, bottom: 128, waves: 5))
            .union(lock(side: 1, outer: 69, inner: 84, top: 82, bottom: 128, waves: 5))
        let above = makePath { p in
            p.move(to: pt(70, 58)); p.addLine(to: pt(130, 58)); p.addLine(to: pt(130, 94))
            p.addCurve(to: pt(100, 72), control1: pt(124, 80), control2: pt(110, 71))
            p.addCurve(to: pt(70, 94), control1: pt(90, 71), control2: pt(76, 80))
            p.closeSubpath()
        }
        hairCap = head.intersection(above)
        hairLines = makePath { p in
            for k: CGFloat in [0, 1, 2, 3, 4] {
                for s: CGFloat in [-1, 1] {
                    p.move(to: pt(100 + s * 1, 66 + k * 0.4))
                    p.addCurve(to: pt(100 + s * (25 + k * 1.6), 92 + k * 3.5),
                               control1: pt(100 + s * (9 + k * 2), 66 + k * 2), control2: pt(100 + s * (21 + k), 75 + k * 3))
                }
            }
        }
        .union(strands(side: -1, from: 71, to: 83, top: 90, bottom: 126, count: 5, waves: 4))
        .union(strands(side: 1, from: 71, to: 83, top: 90, bottom: 126, count: 5, waves: 4))
        skin = head.subtracting(hairCap)
    }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        for x: CGFloat in [86, 114] { pen.solid(oval(x, 171, 17, 7.5)) }
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.hatch(cloth)
        pen.c.fill(buttons, with: .color(Pen.paper))
        pen.c.stroke(buttons, with: .color(Pen.ink), lineWidth: 0.8)
        pen.shape(hairBack, 1.8)
        pen.shape(collar, 1.4)
        pen.fine(collarLines)
        pen.shape(face)
        pen.hatch(faceHatch)
        pen.shape(hairCap, 1.4)
        pen.c.stroke(hairLines, with: .color(Pen.ink.opacity(0.75)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        let x = f.fx
        pen.stroke(bend(pt(85 + x, 87), pt(90.5 + x, 84), pt(96 + x, 86.5)), 1.5)
        pen.stroke(bend(pt(104 + x, 86.5), pt(109.5 + x, 84), pt(115 + x, 87)), 1.5)
        pen.eye(pt(91 + x, 93), f, r: 2.1)
        pen.eye(pt(109 + x, 93), f, r: 2.1)
        // Heavy lids, and the strong nose from the portrait
        pen.fine(bend(pt(87 + x, 90.5), pt(91 + x, 89), pt(95 + x, 90.5)))
        pen.fine(bend(pt(105 + x, 90.5), pt(109 + x, 89), pt(113 + x, 90.5)))
        pen.stroke(bend(pt(100 + x, 93), pt(95.5 + x, 103), pt(101.5 + x, 104)), 1.4)
        pen.mouth(pt(100 + x, 110.5), f, width: 4.5, depth: 2.6)
        pen.stroke(bend(pt(100 + x, 106.5), pt(95 + x, 107.5), pt(92 + x, 106)), 1.2)
        pen.stroke(bend(pt(100 + x, 106.5), pt(105 + x, 107.5), pt(108 + x, 106)), 1.2)
        pen.solid(Path(roundedRect: CGRect(x: 98.6 + x, y: 113.5, width: 2.8, height: 4), cornerRadius: 1.2))
    }

    func detail(_ f: CrewFrame) -> Path { collar }

    func extras(_ f: CrewFrame) -> [(Path, Color)] {
        [(skin, Color(hex: 0xEBC5A8)), (hairBack.subtracting(face).subtracting(collar).union(hairCap), Color(hex: 0x6C5242))]
    }
}
