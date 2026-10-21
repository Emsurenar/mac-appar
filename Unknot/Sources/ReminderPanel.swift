import AppKit
import SwiftUI

/// Lets the buttons react to the first click even though the panel never becomes key.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

extension NSImage {
    /// A rounded-corner mask for NSVisualEffectView; the window shadow follows its shape.
    static func roundedMask(radius r: CGFloat) -> NSImage {
        let edge = r * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: r, yRadius: r).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: r, left: r, bottom: r, right: r)
        image.resizingMode = .stretch
        return image
    }
}

/// A view backed by a layer we configure ourselves: a shape, or a shadow.
private final class LayerView<L: CALayer>: NSView {
    let shape = L()
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
    }
    required init?(coder: NSCoder) { fatalError() }
    override func makeBackingLayer() -> CALayer { shape }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// A floating, non-activating glass panel. It never steals focus.
@MainActor
final class ReminderPanel: NSObject {
    private var panel: NSPanel?
    private var slideOffset: CGFloat = 0
    private var drop: DropAnimation?

    func show(_ session: ReminderSession, at position: ReminderPosition) {
        close()
        let content = ReminderView(s: session).environment(\.locale, Localizer.locale)
        // Use the screen the pointer is on
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        if position == .topCenter {
            drop = DropAnimation(content: content, on: screen)
        } else {
            showInCorner(content, position: position, on: screen)
        }
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: "\(L("Stretch break with %@", session.buddy.name)): \(session.current.title). \(session.current.text)",
            .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])
    }

    func close() {
        drop?.close()
        drop = nil
        guard let p = panel else { return }
        panel = nil
        let offset = slideOffset
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.4, 0, 0.8, 0.2)
            p.animator().alphaValue = 0
            p.animator().setFrame(p.frame.offsetBy(dx: 0, dy: offset), display: true)
        }
        p.perform(#selector(NSWindow.orderOut(_:)), with: nil, afterDelay: 0.35)
    }

    /// In a corner the panel is an ordinary window with a glass background, sliding in from the nearest edge.
    private func showInCorner<V: View>(_ content: V, position: ReminderPosition, on screen: NSScreen) {
        let size = NSSize(width: ReminderView.size.width, height: ReminderView.size.height)
        let p = makePanel(size: size)
        p.hasShadow = true
        p.isMovableByWindowBackground = true

        let glass = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        glass.material = .popover
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.maskImage = .roundedMask(radius: ReminderView.cornerRadius)
        let host = FirstMouseHostingView(rootView: content)
        host.frame = glass.bounds
        host.autoresizingMask = [.width, .height]
        glass.addSubview(host)
        p.contentView = glass

        let vf = screen.visibleFrame
        let inset: CGFloat = 16
        let x = position.isLeft ? vf.minX + inset : vf.maxX - size.width - inset
        let y = position.isTop ? vf.maxY - size.height - inset : vf.minY + inset
        let target = NSRect(x: x, y: y, width: size.width, height: size.height)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        slideOffset = reduceMotion ? 0 : (position.isTop ? 20 : -20)

        p.setFrame(target.offsetBy(dx: 0, dy: slideOffset), display: false)
        p.alphaValue = 0
        p.orderFrontRegardless()
        p.invalidateShadow()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = reduceMotion ? 0.25 : 0.45
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.84, 0.24, 1)
            p.animator().setFrame(target, display: true)
            p.animator().alphaValue = 1
        }
        panel = p
    }
}

private func makePanel(size: NSSize) -> NSPanel {
    let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                    styleMask: [.borderless, .nonactivatingPanel],
                    backing: .buffered, defer: false)
    p.isFloatingPanel = true
    p.level = .statusBar
    p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    p.backgroundColor = .clear
    p.isOpaque = false
    p.hidesOnDeactivate = false
    p.becomesKeyOnlyIfNeeded = true
    p.isReleasedWhenClosed = false
    return p
}

/// The panel at the top center: it comes out of the camera notch and goes back into it.
/// The window reaches up over the menu bar so the drop can start inside the notch; it only takes clicks
/// over the panel itself, so the menu bar keeps working around it.
@MainActor
private final class DropAnimation: NSObject {
    private let window: NSPanel
    private let geometry: DropGeometry
    private let glass = NSView()
    private let glassMask = CAShapeLayer()
    private let ink = LayerView<CAGradientLayer>()
    private let inkMask = CAShapeLayer()
    private let shadow = LayerView<CALayer>()
    private let shadowMask = CAShapeLayer()
    private let host: NSView
    private var timer: Timer?
    private var started = Date()
    private var closing = false
    private let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    init<V: View>(content: V, on screen: NSScreen) {
        geometry = DropGeometry(screen: screen)
        window = makePanel(size: geometry.windowFrame.size)
        host = FirstMouseHostingView(rootView: content)
        super.init()

        window.hasShadow = false
        window.setFrame(geometry.windowFrame, display: false)
        let root = NSView(frame: NSRect(origin: .zero, size: geometry.windowFrame.size))
        root.wantsLayer = true

        // A soft shadow under the panel, kept outside it so it doesn't darken the glass
        shadow.frame = root.bounds
        shadow.shape.shadowColor = NSColor.black.cgColor
        shadow.shape.shadowRadius = 16
        shadow.shape.shadowOffset = CGSize(width: 0, height: -6)
        shadowMask.fillRule = .evenOdd
        shadowMask.frame = root.bounds
        shadow.shape.mask = shadowMask
        root.addSubview(shadow)

        glass.frame = root.bounds
        glass.wantsLayer = true
        let material = NSVisualEffectView(frame: root.bounds)
        material.material = .popover
        material.blendingMode = .behindWindow
        material.state = .active
        material.autoresizingMask = [.width, .height]
        glass.addSubview(material)
        glassMask.frame = root.bounds
        glass.layer?.mask = glassMask
        root.addSubview(glass)

        ink.frame = root.bounds
        ink.shape.colors = [NSColor.black.cgColor, NSColor.black.cgColor, NSColor.black.withAlphaComponent(0).cgColor]
        ink.shape.startPoint = CGPoint(x: 0.5, y: 1)   // the top, in a layer's y-up space
        ink.shape.endPoint = CGPoint(x: 0.5, y: 0)
        ink.shape.mask = inkMask
        root.addSubview(ink)

        host.frame = geometry.flip(geometry.drop.panel)
        root.addSubview(host)
        window.contentView = root

        render(at: reduceMotion ? 1 : 0)
        if reduceMotion { window.alphaValue = 0 }
        window.ignoresMouseEvents = true
        window.orderFrontRegardless()
        if reduceMotion {
            NSAnimationContext.runAnimationGroup { $0.duration = 0.25; window.animator().alphaValue = 1 }
        }
        start()
    }

    func close() {
        closing = true
        window.ignoresMouseEvents = true
        if reduceMotion {
            NSAnimationContext.runAnimationGroup { $0.duration = 0.25; window.animator().alphaValue = 0 }
            finish(after: 0.3)
            return
        }
        start()
    }

    private func start() {
        started = Date()
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 120, target: self, selector: #selector(step), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func step() {
        let elapsed = Date().timeIntervalSince(started)
        if closing {
            guard !reduceMotion else { return }
            let k = min(elapsed / NotchDrop.closeDuration, 1)
            render(at: 1 - CGFloat(k * k * (3 - 2 * k)))
            if k >= 1 { finish(after: 0) }
        } else {
            let k = reduceMotion ? 1 : min(elapsed / NotchDrop.openDuration, 1)
            if k < 1 { render(at: CGFloat(k)) } else if timer?.timeInterval != 1.0 / 30 {
                render(at: 1)
                // Open: keep checking whether the pointer is over the panel, so clicks around it go through
                timer?.invalidate()
                let t = Timer(timeInterval: 1.0 / 30, target: self, selector: #selector(step), userInfo: nil, repeats: true)
                RunLoop.main.add(t, forMode: .common)
                timer = t
            }
            if k >= 1 {
                window.ignoresMouseEvents = !geometry.panelOnScreen.contains(NSEvent.mouseLocation)
            }
        }
    }

    private func render(at t: CGFloat) {
        let f = geometry.drop.frame(at: t)
        let outline = geometry.flip(f.outline)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glassMask.path = outline
        // The black is a gradient over the drop's own height, so it can drain upwards
        let box = outline.boundingBoxOfPath
        ink.frame = box
        var toLocal = CGAffineTransform(translationX: -box.minX, y: -box.minY)
        inkMask.frame = CGRect(origin: .zero, size: box.size)
        inkMask.path = outline.copy(using: &toLocal)
        let stops = NotchDrop.inkStops(f.ink)
        ink.shape.locations = [0, NSNumber(value: Double(stops.solid)), NSNumber(value: Double(stops.clear))]
        ink.isHidden = f.ink <= 0
        shadow.shape.shadowPath = outline
        shadow.shape.shadowOpacity = Float(0.28 * f.shadow)
        let surround = CGMutablePath()
        surround.addRect(shadow.bounds)
        surround.addPath(outline)
        shadowMask.path = surround
        CATransaction.commit()
        host.alphaValue = f.content
        host.setFrameOrigin(geometry.flip(geometry.drop.panel.offsetBy(dx: 0, dy: f.contentOffset)).origin)
    }

    private func finish(after delay: TimeInterval) {
        timer?.invalidate()
        timer = nil
        window.perform(#selector(NSWindow.orderOut(_:)), with: nil, afterDelay: delay)
    }
}

/// Where the notch, the panel and the window are on a screen.
private struct DropGeometry {
    let windowFrame: NSRect
    let drop: NotchDrop
    let panelOnScreen: NSRect

    init(screen: NSScreen) {
        let frame = screen.frame
        let size = ReminderView.size
        // The menu bar, or the notch's height when the menu bar is hidden in full screen
        let menuBar = max(frame.maxY - screen.visibleFrame.maxY, screen.safeAreaInsets.top)
        let margin: CGFloat = 36
        let gap: CGFloat = 10
        let panelX = (frame.midX - size.width / 2).rounded()
        windowFrame = NSRect(x: panelX - margin, y: frame.maxY - menuBar - gap - size.height - margin,
                             width: size.width + margin * 2, height: menuBar + gap + size.height + margin)
        panelOnScreen = NSRect(x: panelX, y: windowFrame.minY + margin, width: size.width, height: size.height)

        // Window coordinates with y pointing down, so the top of the screen is 0
        let panel = CGRect(x: margin, y: menuBar + gap, width: size.width, height: size.height)
        let left = screen.auxiliaryTopLeftArea ?? .zero
        let right = screen.auxiliaryTopRightArea ?? .zero
        if screen.safeAreaInsets.top > 0 && left.width > 0 && right.width > 0 {
            let notch = CGRect(x: left.maxX - windowFrame.minX, y: 0, width: right.minX - left.maxX, height: screen.safeAreaInsets.top)
            drop = NotchDrop(start: notch, panel: panel, fromNotch: true, cornerRadius: ReminderView.cornerRadius)
        } else {
            let sliver = CGRect(x: panel.midX - 70, y: menuBar, width: 140, height: 2)
            drop = NotchDrop(start: sliver, panel: panel, fromNotch: false, cornerRadius: ReminderView.cornerRadius)
        }
    }

    /// From y-down window coordinates to the layers' y-up ones.
    func flip(_ path: CGPath) -> CGPath {
        var t = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: windowFrame.height)
        return path.copy(using: &t) ?? path
    }

    func flip(_ rect: CGRect) -> NSRect {
        NSRect(x: rect.minX, y: windowFrame.height - rect.maxY, width: rect.width, height: rect.height)
    }
}
