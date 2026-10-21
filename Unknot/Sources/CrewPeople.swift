import SwiftUI

// The people in the Stretch Crew, drawn from photographs and portraits. They share the crew's build, a big head
// on a small body with noodle arms, and borrow a little from Rick and Morty: big white eyeballs with small
// pupils, heavy lids and bags, noses drawn as one curve, and mouths that show their teeth.

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

/// The colour a tint ends up as on paper, for parts painted over the print, like eyelids over the eyeballs.
private func printed(_ hex: UInt32) -> Color {
    Color(.sRGB, red: Double((hex >> 16) & 0xFF) / 255 * 0xF7 / 255,
          green: Double((hex >> 8) & 0xFF) / 255 * 0xF5 / 255,
          blue: Double(hex & 0xFF) / 255 * 0xF0 / 255)
}

/// Eyes drawn as almond-shaped openings: an upper lid line, the white, a dark iris with a glint, a finer lower
/// lid and the fold above. No outline all the way round, so they never read as glasses. Drawn in `overlay`,
/// after the colour, so the whites stay white.
struct PersonEyes {
    var centers: [CGPoint]
    var w: CGFloat                // half the width of each eye
    var h: CGFloat                // how far it opens above and below the middle
    var iris: CGFloat
    var tilt: CGFloat = 0         // how much higher the outer corners sit
    var irisColor = Color(hex: 0x3A2A22)
    var lid: CGFloat = 1.8        // the weight of the upper lid line
    var fold: CGFloat = 1         // 0 for no fold above the eye, 2 for a heavy one

    func draw(_ pen: Pen, _ f: CrewFrame) {
        for (i, c0) in centers.enumerated() {
            let side: CGFloat = i == 0 ? -1 : 1
            let c = pt(c0.x + f.fx, c0.y)
            let inner = pt(c.x - side * w, c.y + 0.4)
            let outer = pt(c.x + side * w, c.y - tilt)
            switch f.eyes {
            case .closed:
                pen.stroke(bend(inner, pt(c.x, c.y + h * 1.4), outer), lid)
            case .happy:
                pen.stroke(bend(inner, pt(c.x, c.y - h * 2.2), outer), lid)
            case .open:
                let top = pt(c.x + side * w * 0.12, c.y - h * 2)
                let bottom = pt(c.x - side * w * 0.05, c.y + h * 1.5)
                let almond = makePath { p in
                    p.move(to: inner); p.addQuadCurve(to: outer, control: top); p.addQuadCurve(to: inner, control: bottom); p.closeSubpath()
                }
                pen.paper(almond)
                let iris = pt(c.x + f.look * 0.45 + side * 0.3, c.y + h * 0.15 + f.lookUp * 0.35)
                let inside = pen.moved { $0.clip(to: almond) }
                inside.c.fill(oval(iris.x, iris.y, self.iris * 2, self.iris * 2), with: .color(irisColor))
                inside.solid(oval(iris.x, iris.y, self.iris * 0.9, self.iris * 0.9))
                inside.c.fill(oval(iris.x - self.iris * 0.35, iris.y - self.iris * 0.4, self.iris * 0.55, self.iris * 0.55), with: .color(Pen.paper))
                pen.stroke(bend(pt(inner.x - side * 0.6, inner.y), top, pt(outer.x + side * 0.8, outer.y - 0.3)), lid)
                pen.fine(bend(pt(inner.x + side * w * 0.35, inner.y + h * 0.45), bottom, outer))
            }
            if fold > 0 {
                pen.c.stroke(bend(pt(c.x - side * w * 0.6, c.y - h * 1.6), pt(c.x + side * w * 0.2, c.y - h * 2.9 - fold), pt(c.x + side * w * 1.05, c.y - h * 1.2)),
                             with: .color(Pen.ink.opacity(0.75)), style: StrokeStyle(lineWidth: 0.9 + fold * 0.25, lineCap: .round))
            }
        }
    }
}

/// Cartoon eyes: big white eyeballs with small pupils that look about, upper lids that can droop, lower lids
/// that rise when smiling, and bags underneath. Drawn in `overlay`, after the colour, so the whites stay white.
struct ToonEyes {
    var centers: [CGPoint]
    var r: CGFloat
    var lid: CGFloat = 0          // how far the upper lids come down, 0–1
    var squint: CGFloat = 0       // how far the lower lids come up
    var skin: UInt32
    var bags: CGFloat = 1         // 0 for none, 2 for a second line

    func draw(_ pen: Pen, _ f: CrewFrame) {
        for (i, c0) in centers.enumerated() {
            let side: CGFloat = i == 0 ? -1 : 1
            let c = pt(c0.x + f.fx, c0.y)
            switch f.eyes {
            case .closed:
                pen.stroke(bend(pt(c.x - r, c.y), pt(c.x, c.y + r * 0.5), pt(c.x + r, c.y)), 1.7)
            case .happy:
                pen.stroke(bend(pt(c.x - r, c.y + r * 0.25), pt(c.x, c.y - r * 0.85), pt(c.x + r, c.y + r * 0.25)), 1.7)
            case .open:
                let ball = oval(c.x, c.y, r * 2, r * 2)
                pen.paper(ball)
                let pupil = pt(c.x + f.look * 0.45 - side * r * 0.1, c.y + r * 0.08 + f.lookUp * 0.4)
                pen.solid(oval(pupil.x, pupil.y, r * 0.5, r * 0.5))
                if lid > 0 {
                    let y = c.y - r + 2 * r * lid
                    pen.solid(ball.intersection(Path(CGRect(x: c.x - r - 1, y: c.y - r - 1, width: r * 2 + 2, height: y - c.y + r + 1))), color: printed(skin))
                    let half = sqrt(max(0, r * r - (y - c.y) * (y - c.y)))
                    pen.stroke(bend(pt(c.x - half, y), pt(c.x, y + 0.8), pt(c.x + half, y)), 1.5)
                }
                if squint > 0 {
                    let y = c.y + r - 2 * r * squint
                    pen.solid(ball.intersection(Path(CGRect(x: c.x - r - 1, y: y, width: r * 2 + 2, height: c.y + r - y + 1))), color: printed(skin))
                    let half = sqrt(max(0, r * r - (y - c.y) * (y - c.y)))
                    pen.stroke(bend(pt(c.x - half, y), pt(c.x, y - 1.2), pt(c.x + half, y)), 1.3)
                }
                pen.stroke(ball, 1.5)
            }
            if bags > 0 {
                pen.fine(bend(pt(c.x - r * 0.85, c.y + r * 1.25), pt(c.x, c.y + r * 1.7), pt(c.x + r * 0.85, c.y + r * 1.25)))
            }
            if bags > 1 {
                pen.fine(bend(pt(c.x - r * 0.5, c.y + r * 1.75), pt(c.x, c.y + r * 2.05), pt(c.x + r * 0.5, c.y + r * 1.75)))
            }
        }
    }
}

/// The shadow side of a face: a narrow band down its right edge. The usual crescent also runs under the jaw,
/// where it reads as stubble.
private func faceShadow(_ face: Path) -> Hatch {
    Hatch(face.subtracting(face.applying(CGAffineTransform(translationX: -4.5, y: 0.6))), spacing: 3)
}

/// A small lapel pin: a flag of two colours with a cross or stripes, drawn as a tiny print.
private func drawFlagPin(_ pen: Pen, at origin: CGPoint, swedish: Bool) {
    let rect = CGRect(x: origin.x, y: origin.y, width: 5.6, height: 3.8)
    pen.paper(Path(rect))
    if swedish {
        pen.tint(Path(rect), Color(hex: 0x3C6AAE))
        pen.c.fill(Path(CGRect(x: rect.minX + 1.6, y: rect.minY, width: 1.1, height: rect.height)), with: .color(Color(hex: 0xF2C43C)))
        pen.c.fill(Path(CGRect(x: rect.minX, y: rect.midY - 0.55, width: rect.width, height: 1.1)), with: .color(Color(hex: 0xF2C43C)))
    } else {
        for k in 0..<3 {
            pen.c.fill(Path(CGRect(x: rect.minX, y: rect.minY + CGFloat(k) * 1.3, width: rect.width, height: 0.65)), with: .color(Color(hex: 0xC54B45)))
        }
        pen.c.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: 2.4, height: 2)), with: .color(Color(hex: 0x3E5C9A)))
    }
    pen.c.stroke(Path(rect), with: .color(Pen.ink), lineWidth: 0.7)
}

/// Lapels, a shirt and a tie with a fine pattern, for the people in suits.
struct Suit {
    let body: Path
    let shirt: Path
    let lapels: Path
    let tie: Path
    let tiePattern: Path

    init(left: CGFloat = 70, right: CGFloat = 130, top: CGFloat = 116) {
        body = jacket(left: left, right: right, top: top)
        shirt = makePath { p in
            p.move(to: pt(90, top)); p.addLine(to: pt(110, top)); p.addLine(to: pt(100, top + 25)); p.closeSubpath()
        }
        lapels = makePath { p in
            p.move(to: pt(87, top + 1)); p.addLine(to: pt(99, top + 34))
            p.move(to: pt(113, top + 1)); p.addLine(to: pt(101, top + 34))
            p.move(to: pt(87, top + 1)); p.addLine(to: pt(83.5, top + 12)); p.addLine(to: pt(91, top + 16))
            p.move(to: pt(113, top + 1)); p.addLine(to: pt(116.5, top + 12)); p.addLine(to: pt(109, top + 16))
        }
        let t = makePath { p in
            p.move(to: pt(97.4, top + 7)); p.addLine(to: pt(102.6, top + 7)); p.addLine(to: pt(101.6, top + 11.5))
            p.addLine(to: pt(103.8, top + 26)); p.addLine(to: pt(100, top + 30.5)); p.addLine(to: pt(96.2, top + 26))
            p.addLine(to: pt(98.4, top + 11.5)); p.closeSubpath()
        }
        tie = t
        tiePattern = makePath { p in
            for row in 0..<6 {
                for col in 0..<2 {
                    let q = pt(98.6 + CGFloat(col) * 2.8 + (row % 2 == 0 ? 0 : 1.4), top + 13 + CGFloat(row) * 2.6)
                    if t.contains(q) { p.addEllipse(in: CGRect(x: q.x - 0.4, y: q.y - 0.4, width: 0.8, height: 0.8)) }
                }
            }
        }
    }

    func draw(_ pen: Pen) {
        pen.paper(shirt)
        pen.fine(shirt)
        pen.fine(lapels)
        pen.shape(tie, 1.3)
        for y: CGFloat in [152, 159] { pen.c.stroke(oval(100, y, 2.6, 2.6), with: .color(Pen.ink), lineWidth: 1) }
    }
}

// MARK: - Stefan Löfven

/// Stefan Löfven, from two photographs: a long face with a broad jaw, light brown greying hair with a side
/// parting, combed smoothly across the top; narrowed, smiling eyes with laughter lines, light brows that slope
/// down at the ends, a broad nose with a round tip, a thin closed smile pulled up at one corner, a strong
/// chin, a dark suit, a red tie and a Swedish flag pin.
struct StefanArt: CrewArt {
    let accent = Color(hex: 0x3A4256)
    let detailColor = Color(hex: 0xCC4448)
    let body: Path
    let wash: Path
    let hatches: [Hatch]
    let suit: Suit
    let head: Path
    let headHatch: Hatch
    let hair: Path
    let sideHair: Path                           // shorter and greyer above the ears
    let hairTint: Path
    let hairLines: Path
    let skin: Path
    let earTint: Path
    let eyes = PersonEyes(centers: [pt(89.5, 93), pt(110.5, 93)], w: 5.6, h: 1.6, iris: 2.1, tilt: -0.6,
                          irisColor: Color(hex: 0x5E7896), lid: 1.9, fold: 0.6)
    let shoulders = [pt(71, 129), pt(129, 129)]
    let arm = ArmStyle.noodle(length: 26, hand: .loop)
    let armOffset = -12.0
    let brow: CGPoint? = pt(113, 86)
    let reachExtra: CGFloat = 30
    let groundWidth: CGFloat = 86
    var headBox: CGRect { head.boundingRect }
    let headPivot: CGPoint? = pt(100, 119)

    init() {
        suit = Suit(left: 70, right: 130, top: 119)
        body = suit.body
        wash = suit.body.subtracting(suit.shirt)
        hatches = [Hatch.shadow(of: suit.body, shift: 12)]
        // Long, with wide cheeks and a broad jaw ending in a big rounded chin
        let face = makePath { p in
            p.move(to: pt(100, 59))
            p.addCurve(to: pt(123.5, 80), control1: pt(114, 59), control2: pt(122.5, 68))
            p.addCurve(to: pt(125, 104), control1: pt(125, 90), control2: pt(126, 97))
            p.addCurve(to: pt(115, 121.5), control1: pt(124, 113), control2: pt(120, 118))
            p.addCurve(to: pt(100, 127), control1: pt(110, 125), control2: pt(105, 127))
            p.addCurve(to: pt(85, 121.5), control1: pt(95, 127), control2: pt(90, 125))
            p.addCurve(to: pt(75, 104), control1: pt(80, 118), control2: pt(76, 113))
            p.addCurve(to: pt(76.5, 80), control1: pt(74, 97), control2: pt(75, 90))
            p.addCurve(to: pt(100, 59), control1: pt(77.5, 68), control2: pt(86, 59))
        }
        head = face
        headHatch = faceShadow(face)
        // Parted on his right and combed across. On the parted side the temple is high and the hair short; from
        // the parting it sweeps over in a soft wave that rises above the skull at the front and falls over the
        // far temple.
        let hairShape = makePath { p in
            p.move(to: pt(77.5, 85))
            p.addCurve(to: pt(76.5, 70), control1: pt(76, 80), control2: pt(75.5, 74))
            p.addCurve(to: pt(97, 54.5), control1: pt(79, 60), control2: pt(88, 55))
            // The swept hair stands up a little at the front before it falls over to the side
            p.addCurve(to: pt(112, 51.5), control1: pt(102, 53), control2: pt(107, 50.5))
            p.addCurve(to: pt(126.5, 70.5), control1: pt(120, 53.5), control2: pt(126, 61))
            p.addCurve(to: pt(124.5, 90), control1: pt(127, 78), control2: pt(126, 85))
            p.addCurve(to: pt(120.5, 79), control1: pt(122.5, 86), control2: pt(121.5, 82))
            p.addCurve(to: pt(103, 67), control1: pt(118, 71.5), control2: pt(110, 66.5))
            p.addCurve(to: pt(88.5, 67.5), control1: pt(97, 67.2), control2: pt(92, 66.5))
            p.addCurve(to: pt(81, 74), control1: pt(85, 68.5), control2: pt(82, 70.5))
            p.addCurve(to: pt(77.5, 85), control1: pt(80, 77.5), control2: pt(79, 82))
            p.closeSubpath()
        }
        hair = hairShape
        sideHair = hairShape.intersection(Path(CGRect(x: 70, y: 70, width: 13, height: 20)))
            .union(hairShape.intersection(Path(CGRect(x: 119, y: 74, width: 12, height: 20))))
        hairLines = makePath { p in
            p.move(to: pt(88.5, 67.5)); p.addQuadCurve(to: pt(92, 56.5), control: pt(89, 61))      // the parting
            // Strands sweeping from the parting over to the far side
            for k in 0..<6 {
                let k = CGFloat(k)
                p.move(to: pt(91 + k * 1.6, 58 + k * 1.7))
                p.addCurve(to: pt(121.5 + k * 0.6, 73 + k * 2.6), control1: pt(103 + k * 1.5, 54 + k * 1.2), control2: pt(118 + k, 62 + k * 1.8))
            }
            // The wave at the front, and short hair combed back on the parted side
            p.move(to: pt(98, 66.5)); p.addQuadCurve(to: pt(110, 64.5), control: pt(104, 63))
            for k in 0..<3 {
                let k = CGFloat(k)
                p.move(to: pt(86.5 - k * 2.5, 66 + k * 1.5)); p.addQuadCurve(to: pt(79.5 - k * 0.8, 74 + k * 4), control: pt(81 - k * 1.5, 67 + k * 2))
            }
        }
        skin = face.subtracting(hairShape)
        earTint = oval(74.5, 97, 7, 13.5).union(oval(125.5, 97, 7, 13.5)).subtracting(face)
        hairTint = hairShape.subtracting(sideHair)
    }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        for x: CGFloat in [86, 114] { pen.solid(oval(x, 171, 18, 8)) }
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        suit.draw(pen)
        drawFlagPin(pen, at: pt(110.5, 129), swedish: true)
    }

    func headParts(_ pen: Pen, _ f: CrewFrame) {
        drawEars(pen, at: [74.5, 125.5], y: 97, w: 7, h: 13.5)
        pen.shape(head)
        pen.hatch(headHatch)
        pen.paper(hair)
        pen.stroke(hair, 1.4)
        let combed = pen.moved { $0.clip(to: hair) }
        combed.c.stroke(hairLines, with: .color(Pen.ink.opacity(0.5)), style: StrokeStyle(lineWidth: 0.85, lineCap: .round))
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        let x = f.fx
        // Light brows sloping down at the outer ends
        pen.stroke(bend(pt(83 + x, 86.5), pt(89 + x, 84.2), pt(95.5 + x, 85.6)), 1.5)
        pen.stroke(bend(pt(104.5 + x, 85.6), pt(111 + x, 84.2), pt(117 + x, 86.5)), 1.5)
        // Laughter lines, and the soft bags under the eyes
        for s: CGFloat in [-1, 1] {
            let ex = 100 + s * 17 + x
            pen.fine(line(pt(ex, 92), pt(ex + s * 3.8, 90.5)))
            pen.fine(line(pt(ex + s * 0.3, 94.3), pt(ex + s * 4, 95.6)))
            pen.c.stroke(bend(pt(100 + s * 7 + x, 97.5), pt(100 + s * 11 + x, 99), pt(100 + s * 15 + x, 97)),
                         with: .color(Pen.ink.opacity(0.5)), lineWidth: 0.9)
        }
        // The broad nose with its round tip
        pen.stroke(makePath { p in
            p.move(to: pt(99 + x, 95)); p.addQuadCurve(to: pt(96.5 + x, 104), control: pt(97 + x, 99.5))
            p.addCurve(to: pt(100.5 + x, 109), control1: pt(93 + x, 106.5), control2: pt(96.5 + x, 109.5))
            p.addCurve(to: pt(105 + x, 105), control1: pt(104 + x, 108.8), control2: pt(106.5 + x, 107))
        }, 1.6)
        pen.fine(bend(pt(95.5 + x, 104.5), pt(94 + x, 106.5), pt(96 + x, 108)))
        pen.fine(bend(pt(90 + x, 104), pt(87.5 + x, 110), pt(90.5 + x, 116)))
        pen.fine(bend(pt(110 + x, 104), pt(112.5 + x, 110), pt(109.5 + x, 116)))
        switch f.pose.mouth {
        case .smile:
            // Thin, closed, pulled up more at one corner
            pen.stroke(bend(pt(92.5 + x, 114), pt(100 + x, 116.5), pt(108.5 + x, 112.5)), 1.8)
            pen.fine(bend(pt(108.5 + x, 112.5), pt(110 + x, 112.3), pt(110.6 + x, 111)))
            pen.fine(bend(pt(96 + x, 118.5), pt(100 + x, 119.3), pt(104 + x, 118.3)))
        case .open:
            pen.solid(makePath { p in
                p.move(to: pt(92 + x, 113.5)); p.addQuadCurve(to: pt(108 + x, 113), control: pt(100 + x, 115))
                p.addQuadCurve(to: pt(92 + x, 113.5), control: pt(100 + x, 122))
            })
        case .o:
            pen.stroke(oval(100 + x, 116, 5, 5.5), 1.6)
        }
        pen.fine(bend(pt(95.5 + x, 122.5), pt(100 + x, 124), pt(104.5 + x, 122.5)))
    }

    func overlay(_ pen: Pen, _ f: CrewFrame) { eyes.draw(pen, f) }

    func detail(_ f: CrewFrame) -> Path { suit.tie }

    func headTints(_ f: CrewFrame) -> [(Path, Color)] {
        [(skin, Color(hex: 0xEDB8A0)), (hairTint, Color(hex: 0xBDA587)), (sideHair, Color(hex: 0xCFC5B8)),
         (makePath { $0.addPath(oval(86.5 + f.fx, 104, 10, 5)); $0.addPath(oval(113.5 + f.fx, 104, 10, 5)) }, Color(hex: 0xE5947F).opacity(0.4)),
         (earTint, Color(hex: 0xE6AE97))]
    }
}

// MARK: - Jesus

/// Jesus of Nazareth after the icon of Christ Pantocrator at Sinai: long dark hair parted in the middle and
/// falling behind the shoulders, one lock in front, a long face and straight nose, a beard, a cruciform halo,
/// a dark red tunic with a gold stripe and a deep blue mantle.
struct JesusArt: CrewArt {
    let accent = Color(hex: 0xA2503F)            // the tunic
    let detailColor = Color(hex: 0x41609A)       // the mantle
    let body: Path
    let wash: Path
    let hatches: [Hatch]
    let mantle: Path
    let mantleTint: Path
    let mantleHatch: Hatch
    let mantleFolds: Path
    let clavus: Path
    let hairBack: Path
    let frontLock: Path
    let hairCap: Path
    let hairLines: Path
    let face: Path
    let faceHatch: Hatch
    let beard: Path
    let beardLines: Path
    let skin: Path
    let hairTint: Path
    let eyes = ToonEyes(centers: [pt(91, 92), pt(109, 92)], r: 4.8, lid: 0.32, skin: 0xE9C3A2)
    let shoulders = [pt(75, 128), pt(125, 128)]
    let arm = ArmStyle.noodle(length: 26, hand: .loop)
    let armOffset = -12.0
    let brow: CGPoint? = pt(111, 86)
    let reachExtra: CGFloat = 30
    let groundWidth: CGFloat = 92
    var headBox: CGRect { face.boundingRect }
    let headPivot: CGPoint? = pt(100, 118)

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
        // The mantle comes over his left shoulder and wraps round below the waist
        let cloak = makePath { p in
            p.move(to: pt(104, 116))
            p.addLine(to: pt(114, 116))
            p.addCurve(to: pt(126, 124), control1: pt(120, 116), control2: pt(125, 119))
            p.addCurve(to: pt(137, 164), control1: pt(130, 140), control2: pt(137, 153))
            p.addQuadCurve(to: pt(76, 166), control: pt(108, 169))
            p.addCurve(to: pt(102, 136), control1: pt(86, 152), control2: pt(96, 143))
            p.addQuadCurve(to: pt(104, 116), control: pt(106, 126))
            p.closeSubpath()
        }.intersection(tunic)
        mantle = cloak
        mantleHatch = Hatch.shadow(of: cloak, shift: 8, spacing: 2.6)
        mantleFolds = makePath { p in
            p.move(to: pt(110, 124)); p.addQuadCurve(to: pt(118, 160), control: pt(118, 140))
            p.move(to: pt(118, 122)); p.addQuadCurve(to: pt(128, 158), control: pt(126, 138))
            p.move(to: pt(96, 152)); p.addQuadCurve(to: pt(126, 164), control: pt(110, 156))
            p.move(to: pt(88, 158)); p.addQuadCurve(to: pt(112, 166), control: pt(100, 161))
        }.intersection(cloak)
        clavus = Path(roundedRect: CGRect(x: 85, y: 117, width: 4, height: 34), cornerRadius: 1).intersection(tunic)
        wash = tunic.subtracting(cloak)
        hatches = [Hatch.shadow(of: tunic, shift: 12)]

        let head = makePath { p in
            p.move(to: pt(100, 62))
            p.addCurve(to: pt(120, 86), control1: pt(113, 62), control2: pt(120, 72))
            p.addCurve(to: pt(117, 110), control1: pt(121, 97), control2: pt(120, 104))
            p.addCurve(to: pt(100, 125), control1: pt(113, 119), control2: pt(107, 125))
            p.addCurve(to: pt(83, 110), control1: pt(93, 125), control2: pt(87, 119))
            p.addCurve(to: pt(80, 86), control1: pt(80, 104), control2: pt(79, 97))
            p.addCurve(to: pt(100, 62), control1: pt(80, 72), control2: pt(87, 62))
        }
        face = head
        faceHatch = faceShadow(head)
        hairBack = oval(100, 82, 50, 46)
            .union(lock(side: -1, outer: 75, inner: 86, top: 84, bottom: 136, waves: 2))
            .union(lock(side: 1, outer: 75, inner: 86, top: 84, bottom: 136, waves: 2))
        frontLock = makePath { p in
            p.move(to: pt(117, 100))
            p.addCurve(to: pt(124, 140), control1: pt(122, 112), control2: pt(126, 128))
            p.addQuadCurve(to: pt(116, 138), control: pt(120, 143))
            p.addCurve(to: pt(113, 106), control1: pt(116, 126), control2: pt(112, 114))
            p.closeSubpath()
        }
        let above = makePath { p in
            p.move(to: pt(70, 56)); p.addLine(to: pt(130, 56)); p.addLine(to: pt(130, 100)); p.addLine(to: pt(121, 100))
            p.addCurve(to: pt(100, 72), control1: pt(119, 82), control2: pt(110, 72))
            p.addCurve(to: pt(79, 100), control1: pt(90, 72), control2: pt(81, 82))
            p.addLine(to: pt(70, 100)); p.closeSubpath()
        }
        hairCap = head.intersection(above)
        hairLines = makePath { p in
            for k: CGFloat in [0, 1, 2, 3] {
                for s: CGFloat in [-1, 1] {
                    p.move(to: pt(100 + s * 0.8, 63.5 + k * 0.4))
                    p.addCurve(to: pt(100 + s * (21 + k * 1.2), 98 + k * 2), control1: pt(100 + s * (7 + k * 2), 64 + k * 2), control2: pt(100 + s * (17 + k), 76 + k * 3))
                }
            }
            p.move(to: pt(118.5, 106)); p.addCurve(to: pt(121, 136), control1: pt(121, 116), control2: pt(122.5, 128))
        }
        .union(strands(side: -1, from: 76, to: 85, top: 96, bottom: 134, count: 4, waves: 1.5))
        .union(strands(side: 1, from: 76, to: 85, top: 96, bottom: 134, count: 4, waves: 1.5))
        // Moustache and a full beard, slightly forked at the end
        let full = makePath { p in
            p.move(to: pt(82, 100))
            p.addCurve(to: pt(97.5, 131), control1: pt(81, 117), control2: pt(89, 127))
            p.addLine(to: pt(100, 127.5))
            p.addLine(to: pt(102.5, 131))
            p.addCurve(to: pt(118, 100), control1: pt(111, 127), control2: pt(119, 117))
            p.addCurve(to: pt(100, 108.5), control1: pt(114, 107), control2: pt(108, 106))
            p.addCurve(to: pt(82, 100), control1: pt(92, 106), control2: pt(86, 107))
            p.closeSubpath()
        }
        beard = full
        beardLines = texture(in: full.subtracting(oval(100, 115, 12, 7)), count: 60, seed: 4, length: 2.6, angle: 95)
        mantleTint = cloak.subtracting(frontLock)
        skin = head.subtracting(hairCap).subtracting(full)
        hairTint = hairBack.subtracting(head).union(hairCap).union(frontLock)
    }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        for x: CGFloat in [86, 114] {
            pen.shape(oval(x, 171.5, 17, 6.5), 1.6)
            pen.fine(line(pt(x - 6, 170), pt(x + 6, 170)))
            pen.fine(bend(pt(x - 3, 168.5), pt(x, 166.5), pt(x + 3, 168.5)))
        }
    }

    func behind(_ pen: Pen, _ f: CrewFrame) {
        // A gold halo with the arms of a cross showing round the head
        let outer = oval(100, 82, 70, 70), inner = oval(100, 82, 63, 63)
        pen.tint(outer, Color(hex: 0xF0D98E).opacity(0.55))
        pen.tint(outer.subtracting(inner), Color(hex: 0xDDB54F))
        let cross = makePath { p in
            for angle in [180.0, 270.0, 0.0] {
                let a = angle * .pi / 180
                for offset: CGFloat in [-3.2, 3.2] {
                    let n = pt(CGFloat(-sin(a)) * offset, CGFloat(cos(a)) * offset)
                    p.move(to: pt(100 + CGFloat(cos(a)) * 22 + n.x, 82 + CGFloat(sin(a)) * 22 + n.y))
                    p.addLine(to: pt(100 + CGFloat(cos(a)) * 34.5 + n.x, 82 + CGFloat(sin(a)) * 34.5 + n.y))
                }
            }
        }
        pen.fine(cross)
        pen.c.stroke(outer, with: .color(Pen.ink), lineWidth: 1.3)
        pen.c.stroke(inner, with: .color(Pen.ink), lineWidth: 0.9)
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.shape(clavus, 1)
        pen.shape(mantle, 1.6)
        pen.hatch(mantleHatch)
        pen.fine(mantleFolds)
    }

    func headParts(_ pen: Pen, _ f: CrewFrame) {
        pen.shape(hairBack, 1.8)
        pen.shape(face)
        pen.hatch(faceHatch)
        pen.shape(hairCap, 1.4)
        pen.shape(frontLock, 1.5)
        pen.c.stroke(hairLines, with: .color(Pen.ink.opacity(0.7)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        let x = f.fx
        let b = pen.moved { $0.translateBy(x: x * 0.5, y: 0) }
        b.shape(beard, 1.5)
        b.c.stroke(beardLines, with: .color(Pen.ink.opacity(0.6)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        pen.stroke(bend(pt(85 + x, 85.5), pt(90.5 + x, 82.5), pt(96 + x, 85)), 1.6)
        pen.stroke(bend(pt(104 + x, 85), pt(109.5 + x, 82.5), pt(115 + x, 85.5)), 1.6)
        pen.stroke(makePath { p in
            p.move(to: pt(99.5 + x, 88)); p.addLine(to: pt(98.5 + x, 103))
            p.addQuadCurve(to: pt(100.5 + x, 105.5), control: pt(97 + x, 105.5))
            p.addQuadCurve(to: pt(103.5 + x, 103.5), control: pt(103 + x, 105.5))
        }, 1.5)
        pen.mouth(pt(100 + x, 114), f, width: 4, depth: 1.8)
        pen.stroke(bend(pt(100 + x, 108), pt(94 + x, 108.5), pt(91 + x, 113)), 1.5)
        pen.stroke(bend(pt(100 + x, 108), pt(106 + x, 108.5), pt(109 + x, 113)), 1.5)
    }

    func overlay(_ pen: Pen, _ f: CrewFrame) { eyes.draw(pen, f) }

    func detail(_ f: CrewFrame) -> Path { mantleTint }

    func extras(_ f: CrewFrame) -> [(Path, Color)] { [(clavus, Color(hex: 0xDDB54F))] }

    func headTints(_ f: CrewFrame) -> [(Path, Color)] {
        return [(skin, Color(hex: 0xE9C3A2)), (hairTint, Color(hex: 0x5E4535)),
                (beard.applying(CGAffineTransform(translationX: f.fx * 0.5, y: 0)), Color(hex: 0x6A4C3A))]
    }
}

// MARK: - Gandhi

/// Mahatma Gandhi, from a studio portrait of 1931: a close-shaven head with grey stubble, big ears, small round
/// wire glasses, a large nose, a bushy grey moustache over a wide smile, deep lines, and a thick white shawl.
struct GandhiArt: CrewArt {
    let accent = Color(hex: 0xEDE6D8)
    let detailColor = Color(hex: 0xD9D2C4)
    let body: Path
    let wash: Path
    let hatches: [Hatch]
    let shawlEdge: Path
    let folds: Path
    let neck: Path
    let head: Path
    let headHatch: Hatch
    let stubble: Path
    let skin: Path
    let moustache: Path
    let moustacheLines: Path
    let earTint: Path
    let eyes = ToonEyes(centers: [pt(90, 92), pt(110, 92)], r: 3.8, lid: 0.3, squint: 0.3, skin: 0xA8785A, bags: 0)
    let shoulders = [pt(73, 130), pt(127, 130)]
    let arm = ArmStyle.noodle(length: 25, hand: .loop)
    let armOffset = -12.0
    let brow: CGPoint? = pt(112, 86)
    let reachExtra: CGFloat = 30
    let groundWidth: CGFloat = 86
    var headBox: CGRect { head.boundingRect }
    let headPivot: CGPoint? = pt(100, 118)
    var waist: CGPoint { pt(100, 150) }

    init() {
        let cloth = makePath { p in
            p.move(to: pt(68, 132))
            p.addCurve(to: pt(88, 116), control1: pt(69, 122), control2: pt(77, 116))
            p.addLine(to: pt(112, 116))
            p.addCurve(to: pt(132, 132), control1: pt(123, 116), control2: pt(131, 122))
            p.addCurve(to: pt(126, 163), control1: pt(133, 146), control2: pt(129, 157))
            p.addQuadCurve(to: pt(74, 163), control: pt(100, 166))
            p.addCurve(to: pt(68, 132), control1: pt(71, 157), control2: pt(67, 146))
        }
        body = cloth
        neck = makePath { p in p.move(to: pt(94, 116)); p.addLine(to: pt(106, 116)); p.addLine(to: pt(100, 127)); p.closeSubpath() }
        wash = cloth.subtracting(neck)
        hatches = [Hatch.shadow(of: cloth, shift: 12)]
        // The shawl comes over his left shoulder and across his chest in thick folds
        shawlEdge = makePath { p in
            p.move(to: pt(106, 117)); p.addCurve(to: pt(80, 160), control1: pt(98, 132), control2: pt(86, 146))
        }
        folds = makePath { p in
            p.move(to: pt(112, 118)); p.addCurve(to: pt(90, 160), control1: pt(106, 134), control2: pt(96, 148))
            p.move(to: pt(120, 122)); p.addCurve(to: pt(102, 161), control1: pt(116, 136), control2: pt(106, 150))
            p.move(to: pt(127, 130)); p.addCurve(to: pt(115, 161), control1: pt(126, 142), control2: pt(118, 152))
            p.move(to: pt(76, 124)); p.addQuadCurve(to: pt(74, 150), control: pt(77, 138))
            p.move(to: pt(84, 120)); p.addQuadCurve(to: pt(82, 140), control: pt(85, 130))
            p.move(to: pt(94, 120)); p.addQuadCurve(to: pt(90, 132), control: pt(93, 127))
        }
        let face = makePath { p in
            p.move(to: pt(100, 58))
            p.addCurve(to: pt(124, 84), control1: pt(115, 58), control2: pt(124, 70))
            p.addCurve(to: pt(118, 110), control1: pt(124, 96), control2: pt(122, 104))
            p.addCurve(to: pt(100, 123), control1: pt(114, 118), control2: pt(107, 123))
            p.addCurve(to: pt(82, 110), control1: pt(93, 123), control2: pt(86, 118))
            p.addCurve(to: pt(76, 84), control1: pt(78, 104), control2: pt(76, 96))
            p.addCurve(to: pt(100, 58), control1: pt(76, 70), control2: pt(85, 58))
        }
        head = face
        headHatch = faceShadow(face)
        var r = SeededRandom(state: 19)
        stubble = makePath { p in
            var placed = 0
            let scalp = face.intersection(Path(CGRect(x: 70, y: 55, width: 60, height: 22)))
            while placed < 120 {
                let q = pt(77 + r.next() * 46, 58 + r.next() * 19)
                if scalp.contains(q) {
                    p.addEllipse(in: CGRect(x: q.x - 0.35, y: q.y - 0.35, width: 0.7, height: 0.7))
                    placed += 1
                }
            }
        }
        let tache = makePath { p in
            p.move(to: pt(89, 112.5))
            p.addQuadCurve(to: pt(100, 106.5), control: pt(91, 106))
            p.addQuadCurve(to: pt(111, 112.5), control: pt(109, 106))
            p.addQuadCurve(to: pt(100, 112), control: pt(105, 114.5))
            p.addQuadCurve(to: pt(89, 112.5), control: pt(95, 114.5))
            p.closeSubpath()
        }
        moustache = tache
        moustacheLines = makePath { p in
            for k in 0..<9 {
                let x = 91.5 + CGFloat(k) * 2.1
                p.move(to: pt(x, 108.5 + abs(x - 100) * 0.12)); p.addLine(to: pt(x + (x < 100 ? -0.8 : 0.8), 112.2))
            }
        }
        skin = face.subtracting(tache)
        earTint = oval(71.5, 92, 12.5, 18.5).union(oval(128.5, 92, 12.5, 18.5)).subtracting(face)
    }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        for x: CGFloat in [91, 109] {
            let shin = Path(roundedRect: CGRect(x: x - 2.6, y: 161, width: 5.2, height: 8), cornerRadius: 2.6)
            pen.shape(shin, 1.4)
            pen.tint(shin, Color(hex: 0xA8785A))
        }
        for x: CGFloat in [89, 111] {
            pen.shape(oval(x, 172, 16, 4.6), 1.5)
            let foot = oval(x, 169.5, 11, 5)
            pen.shape(foot, 1.3)
            pen.tint(foot, Color(hex: 0xA8785A))
            pen.fine(line(pt(x - 4, 170), pt(x + 4, 170)))
        }
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.paper(neck)
        pen.fine(folds)
        pen.stroke(shawlEdge, 1.6)
    }

    func headParts(_ pen: Pen, _ f: CrewFrame) {
        drawEars(pen, at: [71.5, 128.5], y: 92, w: 12.5, h: 18.5)
        pen.shape(head)
        pen.hatch(headHatch)
        pen.c.fill(stubble, with: .color(Pen.ink.opacity(0.45)))
        // The lines of his forehead
        for (y, w) in [(70.0, 10.0), (74.5, 12.0), (79.0, 9.0)] {
            pen.fine(bend(pt(100 - w, y + 1), pt(100, y - 1), pt(100 + w, y + 1)))
        }
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        let x = f.fx
        pen.fine(bend(pt(84 + x, 84), pt(90 + x, 82), pt(96 + x, 84)))
        pen.fine(bend(pt(104 + x, 84), pt(110 + x, 82), pt(116 + x, 84)))
        // A big nose with a round tip
        pen.stroke(makePath { p in
            p.move(to: pt(98.5 + x, 92)); p.addQuadCurve(to: pt(95 + x, 104), control: pt(96 + x, 98))
            p.addQuadCurve(to: pt(100 + x, 107), control: pt(94.5 + x, 107.5))
            p.addQuadCurve(to: pt(106 + x, 104), control: pt(105.5 + x, 107.5))
        }, 1.6)
        // Deep lines from the nose to the mouth, and round the eyes
        pen.fine(bend(pt(90 + x, 101), pt(86.5 + x, 108), pt(89 + x, 116)))
        pen.fine(bend(pt(110 + x, 101), pt(113.5 + x, 108), pt(111 + x, 116)))
        for s: CGFloat in [-1, 1] {
            pen.fine(line(pt(100 + s * 16.5 + x, 91), pt(100 + s * 20 + x, 89.5)))
            pen.fine(line(pt(100 + s * 16.5 + x, 93.5), pt(100 + s * 20 + x, 95)))
        }
        switch f.pose.mouth {
        case .smile:
            pen.stroke(bend(pt(92 + x, 114), pt(100 + x, 118.5), pt(108 + x, 114)), 1.7)
        case .open:
            pen.solid(makePath { p in
                p.move(to: pt(92 + x, 113.5)); p.addQuadCurve(to: pt(108 + x, 113.5), control: pt(100 + x, 115))
                p.addQuadCurve(to: pt(92 + x, 113.5), control: pt(100 + x, 122))
            })
        case .o:
            pen.stroke(oval(100 + x, 116, 4.5, 5), 1.5)
        }
        let m = pen.moved { $0.translateBy(x: x, y: 0) }
        m.shape(moustache, 1.3)
        m.c.stroke(moustacheLines, with: .color(Pen.ink.opacity(0.5)), lineWidth: 0.7)
    }

    func overlay(_ pen: Pen, _ f: CrewFrame) {
        eyes.draw(pen, f)
        // Small round wire glasses, over the eyes
        let x = f.fx
        let glasses = makePath { p in
            p.addEllipse(in: CGRect(x: 83.5 + x, y: 86, width: 13, height: 12))
            p.addEllipse(in: CGRect(x: 103.5 + x, y: 86, width: 13, height: 12))
            p.move(to: pt(96.5 + x, 91.5)); p.addQuadCurve(to: pt(103.5 + x, 91.5), control: pt(100 + x, 89))
            p.move(to: pt(83.5 + x, 91)); p.addLine(to: pt(75, 89.5))
            p.move(to: pt(116.5 + x, 91)); p.addLine(to: pt(125, 89.5))
        }
        pen.stroke(glasses, 1.2)
        pen.c.stroke(line(pt(86.5 + x, 89.5), pt(88.5 + x, 87.8)), with: .color(Pen.ink.opacity(0.35)), lineWidth: 0.8)
        pen.c.stroke(line(pt(106.5 + x, 89.5), pt(108.5 + x, 87.8)), with: .color(Pen.ink.opacity(0.35)), lineWidth: 0.8)
    }

    func detail(_ f: CrewFrame) -> Path { Path() }

    func extras(_ f: CrewFrame) -> [(Path, Color)] { [(neck, Color(hex: 0xA8785A))] }

    func headTints(_ f: CrewFrame) -> [(Path, Color)] {
        [(skin, Color(hex: 0xA8785A)), (moustache.applying(CGAffineTransform(translationX: f.fx, y: 0)), detailColor),
         (earTint, Color(hex: 0x9E6E52))]
    }
}

// MARK: - Descartes

/// René Descartes as Frans Hals painted him: long dark wavy hair with locks falling over the forehead, high arched
/// brows, heavy lids, a long nose with a round end, a thin moustache turned up at the ends, a tuft under the lip,
/// a white falling collar and black clothes.
struct DescartesArt: CrewArt {
    let accent = Color(hex: 0x3E3E45)
    let detailColor = Color(hex: 0xEFE9DD)
    let body: Path
    let wash: Path
    let hatches: [Hatch]
    let cloth: Hatch
    let collar: Path
    let collarLines: Path
    let buttons: Path
    let hairBack: Path
    let fringe: Path
    let hairLines: Path
    let face: Path
    let faceHatch: Hatch
    let skin: Path
    let hairTint: Path
    let eyes = ToonEyes(centers: [pt(90, 92), pt(110, 92)], r: 5.3, lid: 0.4, skin: 0xEBC2A4, bags: 2)
    let shoulders = [pt(73, 128), pt(127, 128)]
    let arm = ArmStyle.noodle(length: 26, hand: .loop)
    let armOffset = -12.0
    let brow: CGPoint? = pt(112, 86)
    let reachExtra: CGFloat = 30
    let groundWidth: CGFloat = 86
    var headBox: CGRect { face.boundingRect }
    let headPivot: CGPoint? = pt(100, 118)

    init() {
        let doublet = jacket(left: 72, right: 128)
        body = doublet
        let band = makePath { p in
            p.move(to: pt(100, 122.5))
            p.addQuadCurve(to: pt(80, 121), control: pt(88, 123))
            p.addLine(to: pt(84, 138))
            p.addQuadCurve(to: pt(99, 133), control: pt(92, 137))
            p.addLine(to: pt(101, 133))
            p.addQuadCurve(to: pt(116, 138), control: pt(108, 137))
            p.addLine(to: pt(120, 121))
            p.addQuadCurve(to: pt(100, 122.5), control: pt(112, 123))
            p.closeSubpath()
        }
        collar = band
        collarLines = makePath { p in
            p.move(to: pt(100, 120)); p.addLine(to: pt(100, 133))
            p.move(to: pt(88, 126)); p.addQuadCurve(to: pt(90, 135), control: pt(88, 131))
            p.move(to: pt(112, 126)); p.addQuadCurve(to: pt(110, 135), control: pt(112, 131))
        }
        buttons = makePath { p in
            for y in stride(from: 141.0, through: 161.0, by: 5.0) { p.addEllipse(in: CGRect(x: 98.8, y: y - 1.2, width: 2.4, height: 2.4)) }
        }
        wash = doublet.subtracting(band)
        hatches = [Hatch.shadow(of: doublet, shift: 12)]
        cloth = Hatch(doublet.subtracting(band), spacing: 3.2, angle: -40)

        let head = makePath { p in
            p.move(to: pt(100, 60))
            p.addCurve(to: pt(123, 84), control1: pt(114, 60), control2: pt(123, 70))
            p.addCurve(to: pt(121, 108), control1: pt(124, 95), control2: pt(123, 102))
            p.addCurve(to: pt(100, 124), control1: pt(118, 118), control2: pt(109, 124))
            p.addCurve(to: pt(79, 108), control1: pt(91, 124), control2: pt(82, 118))
            p.addCurve(to: pt(77, 84), control1: pt(77, 102), control2: pt(76, 95))
            p.addCurve(to: pt(100, 60), control1: pt(77, 70), control2: pt(86, 60))
        }
        face = head
        faceHatch = faceShadow(head)
        hairBack = oval(100, 82, 60, 52)
            .union(lock(side: -1, outer: 66, inner: 82, top: 82, bottom: 134, waves: 6))
            .union(lock(side: 1, outer: 66, inner: 82, top: 82, bottom: 134, waves: 6))
        // Locks falling over the forehead instead of a parting
        let tips: [(CGFloat, CGFloat)] = [(77, 92), (81, 80), (85, 84), (89, 77), (93, 82), (97, 75), (101, 80),
                                          (105, 74), (109, 81), (113, 76), (117, 83), (121, 79), (124, 92)]
        let fringeLine = makePath { p in
            p.move(to: pt(70, 50)); p.addLine(to: pt(130, 50)); p.addLine(to: pt(130, 92))
            for (i, t) in tips.reversed().enumerated() where i > 0 {
                let prev = tips.reversed()[i - 1]
                p.addQuadCurve(to: pt(t.0, t.1), control: pt((t.0 + prev.0) / 2, min(t.1, prev.1) - 2))
            }
            p.addLine(to: pt(70, 92)); p.closeSubpath()
        }
        fringe = head.intersection(fringeLine)
        hairLines = makePath { p in
            for t in tips.dropFirst().dropLast() where t.1 > 79 {
                p.move(to: pt(t.0, t.1 - 1)); p.addQuadCurve(to: pt(100 + (t.0 - 100) * 0.6, 62), control: pt(t.0 + (t.0 < 100 ? 2 : -2), 70))
            }
        }
        .union(strands(side: -1, from: 68, to: 81, top: 90, bottom: 132, count: 5, waves: 5))
        .union(strands(side: 1, from: 68, to: 81, top: 90, bottom: 132, count: 5, waves: 5))
        skin = head.subtracting(fringe)
        hairTint = hairBack.subtracting(head).subtracting(band).union(fringe)
    }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        for x: CGFloat in [86, 114] { pen.solid(oval(x, 171, 17, 7.5)) }
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.hatch(cloth)
        pen.c.fill(buttons, with: .color(Pen.paper))
        pen.c.stroke(buttons, with: .color(Pen.ink), lineWidth: 0.8)
    }

    func headParts(_ pen: Pen, _ f: CrewFrame) {
        pen.shape(hairBack, 1.8)
        pen.shape(face)
        pen.hatch(faceHatch)
        pen.shape(fringe, 1.4)
        pen.c.stroke(hairLines, with: .color(Pen.ink.opacity(0.7)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        let x = f.fx
        // High arched brows, the left one raised a little higher, as if doubting
        pen.stroke(bend(pt(82 + x, 85), pt(88 + x, 78.5), pt(96 + x, 83.5)), 1.8)
        pen.stroke(bend(pt(104 + x, 84), pt(111 + x, 80.5), pt(118 + x, 85)), 1.8)
        // A long nose with a round end
        pen.stroke(makePath { p in
            p.move(to: pt(99 + x, 91)); p.addQuadCurve(to: pt(97 + x, 103.5), control: pt(97 + x, 97))
            p.addCurve(to: pt(101 + x, 108.5), control1: pt(94 + x, 106), control2: pt(97 + x, 109))
            p.addCurve(to: pt(105 + x, 104), control1: pt(104.5 + x, 108.5), control2: pt(106.5 + x, 106))
        }, 1.7)
        pen.fine(bend(pt(96 + x, 105.5), pt(97.5 + x, 107.5), pt(99.5 + x, 107.5)))
        // Thin moustache turned up at the ends, a small mouth, the tuft under the lip
        pen.stroke(bend(pt(100 + x, 111), pt(94 + x, 112), pt(91 + x, 109.5)), 1.5)
        pen.stroke(bend(pt(100 + x, 111), pt(106 + x, 112), pt(109 + x, 109.5)), 1.5)
        switch f.pose.mouth {
        case .smile:
            pen.stroke(bend(pt(96 + x, 114.5), pt(100.5 + x, 115.8), pt(104.5 + x, 114)), 1.6)
        case .open:
            pen.solid(makePath { p in
                p.move(to: pt(95 + x, 114)); p.addQuadCurve(to: pt(105 + x, 114), control: pt(100 + x, 115))
                p.addQuadCurve(to: pt(95 + x, 114), control: pt(100 + x, 120))
            })
        case .o:
            pen.stroke(oval(100 + x, 115.5, 4, 4.5), 1.5)
        }
        pen.solid(makePath { p in p.move(to: pt(98.5 + x, 117.5)); p.addLine(to: pt(101.5 + x, 117.5)); p.addLine(to: pt(100 + x, 121.5)); p.closeSubpath() })
    }

    // The collar lies over the hair, just under the chin
    func front(_ pen: Pen, _ f: CrewFrame) {
        pen.shape(collar, 1.4)
        pen.fine(collarLines)
    }

    func overlay(_ pen: Pen, _ f: CrewFrame) { eyes.draw(pen, f) }

    func detail(_ f: CrewFrame) -> Path { collar }

    func headTints(_ f: CrewFrame) -> [(Path, Color)] {
        [(skin, Color(hex: 0xEBC2A4)), (hairTint, Color(hex: 0x4E3A2E)),
         (makePath { $0.addPath(oval(87 + f.fx, 104, 9, 5)); $0.addPath(oval(113 + f.fx, 104, 9, 5)) }, Color(hex: 0xE09A88).opacity(0.4))]
    }
}

// MARK: - Alexander Bard

/// Alexander Bard, from a photograph: a shaven, shiny head with freckles and ears that stand out, pale blue
/// eyes under nearly invisible brows, a broad nose, and a huge, wiry ginger beard with a moustache over the
/// mouth; a dark brown shirt, a black tie with orange polka dots and black braces with white ones.
struct BardArt: CrewArt {
    let accent = Color(hex: 0x6B463C)            // the brown shirt
    let detailColor = Color(hex: 0xE3673F)       // the dots on the tie
    let body: Path
    let wash: Path
    let hatches: [Hatch]
    let tie: Path
    let tieDots: Path
    let braces: Path
    let braceDots: Path
    let collar: Path
    let head: Path
    let headHatch: Hatch
    let shine: Path
    let freckles: Path
    let stubble: Path
    let beard: Path
    let curls: Path
    let moustache: Path
    let skin: Path
    let earTint: Path
    let eyes = ToonEyes(centers: [pt(90.5, 90), pt(109.5, 90)], r: 4.4, lid: 0.3, skin: 0xF0C0AA, bags: 1)
    let shoulders = [pt(71, 129), pt(129, 129)]
    let arm = ArmStyle.noodle(length: 26, hand: .loop)
    let armOffset = -12.0
    let brow: CGPoint? = pt(112, 84)
    let reachExtra: CGFloat = 30
    let groundWidth: CGFloat = 86
    var headBox: CGRect { head.boundingRect }
    let headPivot: CGPoint? = pt(100, 117)

    init() {
        let shirt = jacket(left: 71, right: 129, top: 117)
        body = shirt
        collar = makePath { p in
            p.move(to: pt(90, 117)); p.addLine(to: pt(97, 125)); p.addLine(to: pt(100, 119))
            p.addLine(to: pt(103, 125)); p.addLine(to: pt(110, 117))
        }
        let t = makePath { p in
            p.move(to: pt(97.6, 121)); p.addLine(to: pt(102.4, 121)); p.addLine(to: pt(101.6, 125))
            p.addLine(to: pt(103.2, 158)); p.addLine(to: pt(100, 161.5)); p.addLine(to: pt(96.8, 158))
            p.addLine(to: pt(98.4, 125)); p.closeSubpath()
        }
        tie = t
        tieDots = makePath { p in
            for (x, y) in [(99.0, 128.0), (101.5, 133.0), (98.8, 138.0), (101.3, 143.0), (99.1, 148.0), (101.0, 153.0), (99.6, 157.5)] {
                p.addEllipse(in: CGRect(x: x - 1.15, y: y - 1.15, width: 2.3, height: 2.3))
            }
        }
        let straps = makePath { p in
            p.move(to: pt(80, 118.5)); p.addLine(to: pt(85.5, 118)); p.addLine(to: pt(87.5, 166)); p.addLine(to: pt(82, 166)); p.closeSubpath()
            p.move(to: pt(120, 118.5)); p.addLine(to: pt(114.5, 118)); p.addLine(to: pt(112.5, 166)); p.addLine(to: pt(118, 166)); p.closeSubpath()
        }.intersection(shirt)
        braces = straps
        braceDots = makePath { p in
            for y in stride(from: 122.0, through: 162.0, by: 4.0) {
                let k = CGFloat((y - 118) / 48)
                p.addEllipse(in: CGRect(x: 82.8 + k * 2 - 0.6, y: y - 0.6, width: 1.2, height: 1.2))
                p.addEllipse(in: CGRect(x: 117.2 - k * 2 - 0.6, y: y - 0.6, width: 1.2, height: 1.2))
            }
        }
        wash = shirt.subtracting(t).subtracting(straps)
        hatches = [Hatch.shadow(of: shirt, shift: 12)]

        // A broad, bare dome of a head
        let face = makePath { p in
            p.move(to: pt(100, 57))
            p.addCurve(to: pt(124, 80), control1: pt(115, 57), control2: pt(124, 67))
            p.addCurve(to: pt(122, 106), control1: pt(124.5, 92), control2: pt(124, 100))
            p.addCurve(to: pt(100, 121), control1: pt(119, 115), control2: pt(110, 121))
            p.addCurve(to: pt(78, 106), control1: pt(90, 121), control2: pt(81, 115))
            p.addCurve(to: pt(76, 80), control1: pt(76, 100), control2: pt(75.5, 92))
            p.addCurve(to: pt(100, 57), control1: pt(76, 67), control2: pt(85, 57))
        }
        head = face
        headHatch = faceShadow(face)
        shine = bend(pt(86, 66), pt(92, 61.5), pt(100, 60.5)).strokedPath(StrokeStyle(lineWidth: 2.6, lineCap: .round))
        var r = SeededRandom(state: 52)
        freckles = makePath { p in
            for _ in 0..<26 {
                let q = pt(82 + r.next() * 36, 66 + r.next() * 34)
                if face.contains(q) && !oval(100, 90, 34, 12).contains(q) {
                    p.addEllipse(in: CGRect(x: q.x - 0.45, y: q.y - 0.45, width: 0.9, height: 0.9))
                }
            }
        }
        stubble = texture(in: face.intersection(Path(CGRect(x: 75, y: 76, width: 7, height: 18)))
            .union(face.intersection(Path(CGRect(x: 118, y: 76, width: 7, height: 18)))), count: 18, seed: 9, length: 1.6, angle: 100)
        // The beard: full from ear to ear, wiry, falling well below the chin
        let full = makePath { p in
            p.move(to: pt(78.5, 96))
            p.addCurve(to: pt(80, 124), control1: pt(76, 105), control2: pt(76.5, 116))
            p.addCurve(to: pt(92, 142), control1: pt(82, 133), control2: pt(86, 139))
            p.addQuadCurve(to: pt(100, 145.5), control: pt(95.5, 145.5))
            p.addQuadCurve(to: pt(108, 142), control: pt(104.5, 145.5))
            p.addCurve(to: pt(120, 124), control1: pt(114, 139), control2: pt(118, 133))
            p.addCurve(to: pt(121.5, 96), control1: pt(123.5, 116), control2: pt(124, 105))
            p.addCurve(to: pt(108, 107), control1: pt(118, 102), control2: pt(113, 107))
            p.addQuadCurve(to: pt(100, 104.5), control: pt(104, 104))
            p.addQuadCurve(to: pt(92, 107), control: pt(96, 104))
            p.addCurve(to: pt(78.5, 96), control1: pt(87, 107), control2: pt(82, 102))
            p.closeSubpath()
        }
        beard = full
        // Wiry curls rather than straight strands
        curls = makePath { p in
            var c = SeededRandom(state: 27)
            var placed = 0
            while placed < 70 {
                let q = pt(79 + c.next() * 42, 104 + c.next() * 41)
                guard full.contains(q) else { continue }
                let a = c.next() * 2 * .pi
                p.move(to: q)
                p.addQuadCurve(to: pt(q.x + 1.2 * CGFloat(cos(a + 1)), q.y + 2.4), control: pt(q.x + 2.2 * CGFloat(cos(a)), q.y + 0.8))
                placed += 1
            }
        }
        moustache = makePath { p in
            p.move(to: pt(100, 104))
            p.addQuadCurve(to: pt(86, 113), control: pt(89, 103.5))
            p.addQuadCurve(to: pt(100, 110.5), control: pt(93, 110.5))
            p.addQuadCurve(to: pt(114, 113), control: pt(107, 110.5))
            p.addQuadCurve(to: pt(100, 104), control: pt(111, 103.5))
            p.closeSubpath()
        }
        skin = face.subtracting(full).subtracting(shine)
        earTint = oval(74.5, 92, 8.5, 14.5).union(oval(125.5, 92, 8.5, 14.5)).subtracting(face)
    }

    func feet(_ pen: Pen, _ f: CrewFrame) {
        for x: CGFloat in [86, 114] { pen.solid(oval(x, 171, 18, 8)) }
    }

    func onBody(_ pen: Pen, _ f: CrewFrame) {
        pen.fine(collar)
        pen.solid(braces)
        pen.c.fill(braceDots, with: .color(Pen.paper))
        pen.solid(tie)
        pen.c.fill(tieDots, with: .color(detailColor))
        for y: CGFloat in [150, 158] {
            pen.c.stroke(oval(92, y, 2, 2), with: .color(Pen.paper.opacity(0.8)), lineWidth: 0.8)
        }
    }

    func headParts(_ pen: Pen, _ f: CrewFrame) {
        drawEars(pen, at: [74.5, 125.5], y: 92, w: 8.5, h: 14.5)
        pen.shape(head)
        pen.hatch(headHatch)
        pen.c.fill(freckles, with: .color(Color(hex: 0xB87A5A)))
        pen.c.stroke(stubble, with: .color(Pen.ink.opacity(0.4)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
    }

    func face(_ pen: Pen, _ f: CrewFrame) {
        let x = f.fx
        // Pale brows, barely there
        pen.c.stroke(bend(pt(84.5 + x, 83), pt(90 + x, 81.5), pt(95.5 + x, 83)), with: .color(Pen.ink.opacity(0.5)), lineWidth: 1.2)
        pen.c.stroke(bend(pt(104.5 + x, 83), pt(110 + x, 81.5), pt(115.5 + x, 83)), with: .color(Pen.ink.opacity(0.5)), lineWidth: 1.2)
        pen.stroke(makePath { p in
            p.move(to: pt(99 + x, 93)); p.addQuadCurve(to: pt(96 + x, 100.5), control: pt(97 + x, 97))
            p.addQuadCurve(to: pt(100 + x, 103), control: pt(95.5 + x, 103.5))
            p.addQuadCurve(to: pt(104.5 + x, 100.5), control: pt(104.5 + x, 103.5))
        }, 1.6)
        let b = pen.moved { $0.translateBy(x: x * 0.5, y: 0) }
        b.shape(beard, 1.6)
        b.c.stroke(curls, with: .color(Pen.ink.opacity(0.55)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        if f.pose.mouth != .smile {
            b.solid(oval(100, 115, f.pose.mouth == .o ? 4.5 : 7, f.pose.mouth == .o ? 5 : 4.5))
        }
        let m = pen.moved { $0.translateBy(x: x * 0.8, y: 0) }
        m.shape(moustache, 1.5)
        m.c.stroke(makePath { p in
            for k in 0..<8 {
                let mx = 88 + CGFloat(k) * 3.4
                p.move(to: pt(mx, 106.5 + abs(mx - 100) * 0.12)); p.addLine(to: pt(mx + (mx < 100 ? -1 : 1), 111))
            }
        }, with: .color(Pen.ink.opacity(0.5)), lineWidth: 0.7)
    }

    func overlay(_ pen: Pen, _ f: CrewFrame) { eyes.draw(pen, f) }

    func detail(_ f: CrewFrame) -> Path { Path() }

    func headTints(_ f: CrewFrame) -> [(Path, Color)] {
        let ginger = Color(hex: 0xC8743F)
        return [(skin, Color(hex: 0xF0C0AA)), (earTint, Color(hex: 0xE9AE96)),
                (beard.applying(CGAffineTransform(translationX: f.fx * 0.5, y: 0)), ginger),
                (moustache.applying(CGAffineTransform(translationX: f.fx * 0.8, y: 0)), ginger)]
    }
}
