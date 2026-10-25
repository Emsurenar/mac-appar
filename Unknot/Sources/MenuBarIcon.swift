import AppKit

/// The menu bar icon: the frog from the app icon, as a line drawing. It closes its eyes while reminders
/// are paused and smiles with its eyes during a break.
enum MenuBarIcon {
    enum Mood { case awake, asleep, happy }

    static func image(_ mood: Mood) -> NSImage {
        let image = NSImage(size: NSSize(width: 21, height: 16), flipped: true) { _ in
            draw(mood)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Unknot"
        return image
    }

    private static func draw(_ mood: Mood) {
        guard let c = NSGraphicsContext.current?.cgContext else { return }
        let eyes = [CGPoint(x: 6.2, y: 5.4), CGPoint(x: 14.8, y: 5.4)]
        // A wide head with two eye bumps on top
        let head = CGPath(ellipseIn: CGRect(x: 1.6, y: 5.2, width: 17.8, height: 9.6), transform: nil)
            .union(CGPath(ellipseIn: CGRect(x: eyes[0].x - 3.7, y: eyes[0].y - 3.7, width: 7.4, height: 7.4), transform: nil))
            .union(CGPath(ellipseIn: CGRect(x: eyes[1].x - 3.7, y: eyes[1].y - 3.7, width: 7.4, height: 7.4), transform: nil))
        c.setStrokeColor(NSColor.black.cgColor)
        c.setFillColor(NSColor.black.cgColor)
        c.setLineCap(.round)
        c.setLineJoin(.round)
        c.setLineWidth(1.35)
        c.addPath(head)
        c.strokePath()

        c.setLineWidth(1.2)
        for eye in eyes {
            switch mood {
            case .awake:
                c.fillEllipse(in: CGRect(x: eye.x - 1.45, y: eye.y - 1.3, width: 2.9, height: 2.9))
            case .asleep:
                c.move(to: CGPoint(x: eye.x - 1.8, y: eye.y + 0.2))
                c.addQuadCurve(to: CGPoint(x: eye.x + 1.8, y: eye.y + 0.2), control: CGPoint(x: eye.x, y: eye.y + 1.9))
                c.strokePath()
            case .happy:
                c.move(to: CGPoint(x: eye.x - 1.8, y: eye.y + 1.1))
                c.addQuadCurve(to: CGPoint(x: eye.x + 1.8, y: eye.y + 1.1), control: CGPoint(x: eye.x, y: eye.y - 1.3))
                c.strokePath()
            }
        }
        // The smile
        c.move(to: CGPoint(x: 7.6, y: 10.6))
        c.addQuadCurve(to: CGPoint(x: 13.4, y: 10.6), control: CGPoint(x: 10.5, y: mood == .happy ? 13.4 : 12.4))
        c.strokePath()
    }
}
