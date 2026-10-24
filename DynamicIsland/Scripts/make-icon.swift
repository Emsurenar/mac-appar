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
    NSGradient(colors: [NSColor(srgbRed: 0.36, green: 0.55, blue: 1.0, alpha: 1),
                        NSColor(srgbRed: 0.55, green: 0.33, blue: 0.95, alpha: 1),
                        NSColor(srgbRed: 0.95, green: 0.45, blue: 0.62, alpha: 1)])!
        .draw(in: body, angle: -60)
    // Soft highlight like a Tahoe wallpaper.
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.35), NSColor.white.withAlphaComponent(0)])!
        .draw(in: NSBezierPath(ovalIn: NSRect(x: 180, y: 120, width: 760, height: 560)), relativeCenterPosition: .zero)

    // The island hanging from the top edge.
    let island = NSRect(x: 232, y: 640, width: 560, height: 200)
    let islandPath = NSBezierPath(roundedRect: island, xRadius: 100, yRadius: 100)
    NSColor.black.setFill()
    islandPath.fill()
    NSBezierPath(rect: NSRect(x: 232, y: 760, width: 560, height: 164)).fill()

    let art = NSRect(x: 292, y: 680, width: 120, height: 120)
    NSGradient(colors: [NSColor(srgbRed: 1.0, green: 0.62, blue: 0.3, alpha: 1),
                        NSColor(srgbRed: 0.98, green: 0.28, blue: 0.45, alpha: 1)])!
        .draw(in: NSBezierPath(roundedRect: art, xRadius: 30, yRadius: 30), angle: -45)

    let heights: [CGFloat] = [56, 104, 76, 120, 64]
    NSColor(srgbRed: 1.0, green: 0.55, blue: 0.5, alpha: 1).setFill()
    for (i, h) in heights.enumerated() {
        let x = 600 + CGFloat(i) * 30
        NSBezierPath(roundedRect: NSRect(x: x, y: 740 - h / 2, width: 16, height: h), xRadius: 8, yRadius: 8).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
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
