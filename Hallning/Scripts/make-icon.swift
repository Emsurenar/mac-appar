// Renders Resources/AppIcon.icns. Run: swift Scripts/make-icon.swift
import AppKit

func render(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px) / 1024
    NSGraphicsContext.current?.cgContext.scaleBy(x: s, y: s)

    // macOS icon grid: 824pt squircle centered on a 1024 canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor.black.setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    squircle.addClip()
    NSGradient(colors: [NSColor(srgbRed: 0.20, green: 0.80, blue: 0.76, alpha: 1),
                        NSColor(srgbRed: 0.12, green: 0.56, blue: 0.90, alpha: 1),
                        NSColor(srgbRed: 0.16, green: 0.32, blue: 0.86, alpha: 1)])!
        .draw(in: body, angle: -60)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.32), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSBezierPath(ovalIn: NSRect(x: 180, y: 420, width: 760, height: 560)), relativeCenterPosition: .zero)

    // The upright seated figure, same geometry as PostureFigure (unit square, y down).
    let size: CGFloat = 560
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: 210 + x * size, y: 803 - y * size) }
    let lines = NSBezierPath()
    lines.lineWidth = 0.085 * size
    lines.lineCapStyle = .round
    lines.lineJoinStyle = .round
    lines.move(to: p(0.74, 0.97)); lines.line(to: p(0.74, 0.72)); lines.line(to: p(0.36, 0.72))
    lines.curve(to: p(0.40, 0.34), controlPoint1: p(0.36, 0.52), controlPoint2: p(0.36, 0.52))
    let head = p(0.44, 0.15), shoulder = p(0.40, 0.34), r = 0.10 * size
    let dx = head.x - shoulder.x, dy = head.y - shoulder.y, length = hypot(dx, dy)
    lines.move(to: shoulder)
    lines.line(to: NSPoint(x: head.x - dx / length * r * 1.25, y: head.y - dy / length * r * 1.25))
    lines.move(to: shoulder); lines.line(to: p(0.44, 0.55)); lines.line(to: p(0.66, 0.52))

    NSGraphicsContext.saveGraphicsState()
    let figureShadow = NSShadow()
    figureShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    figureShadow.shadowBlurRadius = 18
    figureShadow.shadowOffset = NSSize(width: 0, height: -8)
    figureShadow.set()
    NSColor.white.setStroke()
    NSColor.white.setFill()
    lines.stroke()
    NSBezierPath(ovalIn: NSRect(x: head.x - r, y: head.y - r, width: r * 2, height: r * 2)).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("HallningIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! render(base * scale).representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! task.run()
task.waitUntilExit()
print("Wrote Resources/AppIcon.icns")
