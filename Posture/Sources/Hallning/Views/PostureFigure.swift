import AppKit
import SwiftUI

/// A seated person seen from the side, facing right. `slouch` animates from upright (0)
/// to slouched (1). Used for the menu bar icon, the rings and the onboarding hero.
struct PostureFigure: Shape {
    var slouch: Double

    var animatableData: Double {
        get { slouch }
        set { slouch = newValue }
    }

    private struct Pose {
        var shoulder, spine, head, elbow, hand: CGPoint
    }

    private static let upright = Pose(shoulder: CGPoint(x: 0.40, y: 0.34), spine: CGPoint(x: 0.36, y: 0.52),
                                      head: CGPoint(x: 0.44, y: 0.15), elbow: CGPoint(x: 0.44, y: 0.55),
                                      hand: CGPoint(x: 0.66, y: 0.52))
    private static let slouched = Pose(shoulder: CGPoint(x: 0.55, y: 0.44), spine: CGPoint(x: 0.24, y: 0.56),
                                       head: CGPoint(x: 0.72, y: 0.29), elbow: CGPoint(x: 0.56, y: 0.62),
                                       hand: CGPoint(x: 0.76, y: 0.60))

    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - size / 2, y: rect.midY - size / 2)
        let t = CGFloat(min(max(slouch, 0), 1))

        func point(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * size, y: origin.y + p.y * size) }
        func mix(_ a: CGPoint, _ b: CGPoint) -> CGPoint { point(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)) }

        let a = Self.upright, b = Self.slouched
        let hip = point(CGPoint(x: 0.36, y: 0.72))
        let knee = point(CGPoint(x: 0.74, y: 0.72))
        let foot = point(CGPoint(x: 0.74, y: 0.97))
        let shoulder = mix(a.shoulder, b.shoulder)
        let spine = mix(a.spine, b.spine)
        let head = mix(a.head, b.head)
        let elbow = mix(a.elbow, b.elbow)
        let hand = mix(a.hand, b.hand)

        let lineWidth = 0.085 * size
        let radius = 0.10 * size

        var lines = Path()
        lines.move(to: foot)
        lines.addLine(to: knee)
        lines.addLine(to: hip)
        lines.addQuadCurve(to: shoulder, control: spine)

        // The neck stops short of the head, so the round cap leaves a small gap.
        let dx = head.x - shoulder.x, dy = head.y - shoulder.y
        let length = max(hypot(dx, dy), 0.001)
        let gap = radius * 1.25 + lineWidth / 2
        if length > gap {
            lines.move(to: shoulder)
            lines.addLine(to: CGPoint(x: head.x - dx / length * gap, y: head.y - dy / length * gap))
        }

        lines.move(to: shoulder)
        lines.addLine(to: elbow)
        lines.addLine(to: hand)

        var path = lines.strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
        path.addEllipse(in: CGRect(x: head.x - radius, y: head.y - radius, width: radius * 2, height: radius * 2))
        return path
    }
}

extension PostureFigure {
    /// How slouched the figure should look for a status.
    static func slouch(for status: PostureStatus) -> Double {
        switch status {
        case .bad: 0.85
        case .uncertain: 0.35
        default: 0
        }
    }

    /// The 18 pt template image for the menu bar.
    @MainActor
    static func menuBarImage(slouch: Double) -> NSImage {
        let key = Int((slouch * 10).rounded())
        if let cached = menuBarCache[key] { return cached }
        let renderer = ImageRenderer(content: PostureFigure(slouch: Double(key) / 10)
            .fill(Color.black)
            .frame(width: 18, height: 18))
        renderer.scale = 2
        let image = renderer.nsImage ?? NSImage(systemSymbolName: "figure.stand", accessibilityDescription: nil) ?? NSImage()
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        menuBarCache[key] = image
        return image
    }

    @MainActor private static var menuBarCache: [Int: NSImage] = [:]
}

/// The figure inside a progress ring, coloured by status.
struct FigureRing: View {
    var progress: Double
    var slouch: Double
    var color: Color
    var lineWidth: CGFloat = 5
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(progress, 0), 1)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            PostureFigure(slouch: slouch)
                .fill(color.gradient)
                .padding(size * 0.22)
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: slouch)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
    }
}

/// Draws a body pose as a skeleton. `mirrored` matches a selfie-style preview.
struct SkeletonView: View {
    var pose: BodyPose?
    var color: Color = .green
    var mirrored = true
    var lineWidth: CGFloat = 3

    var body: some View {
        Canvas { context, size in
            guard let pose else { return }
            func point(_ joint: JointName) -> CGPoint? {
                guard let p = pose.normalized(joint) else { return nil }
                let x = mirrored ? 1 - p.x : p.x
                return CGPoint(x: x * size.width, y: (1 - p.y) * size.height)
            }
            var bones = Path()
            for (a, b) in BodyPose.bones {
                guard let pa = point(a), let pb = point(b) else { continue }
                bones.move(to: pa)
                bones.addLine(to: pb)
            }
            context.stroke(bones, with: .color(color.opacity(0.9)),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            for joint in JointName.allCases {
                guard let p = point(joint) else { continue }
                let r = lineWidth * 1.3
                context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(.white))
            }
            if let face = pose.face {
                let box = face.box
                let x = mirrored ? 1 - box.maxX : box.minX
                let rect = CGRect(x: x * size.width, y: (1 - box.maxY) * size.height,
                                  width: box.width * size.width, height: box.height * size.height)
                context.stroke(Path(roundedRect: rect, cornerRadius: rect.width * 0.2), with: .color(.white.opacity(0.5)),
                               style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
            }
        }
    }
}

/// A skeleton thumbnail framed around the upper body, for calibration grids.
struct PoseThumbnail: View {
    var pose: BodyPose?
    var color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
            if let pose = pose?.croppedToBody() {
                SkeletonView(pose: pose, color: color, lineWidth: 2.2)
                    .aspectRatio(pose.aspect, contentMode: .fit)
                    .padding(8)
            } else {
                Image(systemName: "person.fill.viewfinder")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

extension BodyPose {
    /// The same pose re-normalised to a square around the detected joints, so thumbnails
    /// show the person instead of the whole camera frame.
    func croppedToBody(margin: Double = 0.18) -> BodyPose? {
        let points = joints.values.map { CGPoint(x: $0.x * aspect, y: $0.y) }
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return nil }
        var side = max(maxX - minX, maxY - minY)
        side = max(side * (1 + margin * 2), 0.05)
        let origin = CGPoint(x: (minX + maxX - side) / 2, y: (minY + maxY - side) / 2)
        func map(_ p: CGPoint) -> CGPoint {
            CGPoint(x: (p.x * aspect - origin.x) / side, y: (p.y - origin.y) / side)
        }
        var cropped = self
        cropped.joints = joints.mapValues(map)
        cropped.aspect = 1
        if let face {
            let a = map(CGPoint(x: face.box.minX, y: face.box.minY))
            let b = map(CGPoint(x: face.box.maxX, y: face.box.maxY))
            cropped.face?.box = CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
        }
        return cropped
    }
}
