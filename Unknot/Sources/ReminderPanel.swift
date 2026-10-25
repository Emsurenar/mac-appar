import AppKit
import SwiftUI

/// Lets the buttons react to the first click even though the panel never becomes key.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
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

/// A floating, non-activating island. It never steals focus.
@MainActor
final class ReminderPanel: NSObject {
    private var panel: NSPanel?
    private var slideOffset: CGFloat = 0
    private var drop: DropAnimation?

    func show(_ session: ReminderSession, at position: ReminderPosition) {
        close()
        // Use the screen the pointer is on
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        if position == .topCenter {
            drop = DropAnimation(session: session, on: screen)
        } else {
            showInCorner(session, position: position, on: screen)
        }
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

    /// In a corner there's no notch to grow from: the island is a black rounded panel that slides in from the
    /// nearest edge.
    private func showInCorner(_ session: ReminderSession, position: ReminderPosition, on screen: NSScreen) {
        let content = ReminderView(s: session).environment(\.locale, Localizer.locale)
        let size = NSSize(width: ReminderView.size(topInset: 0, sideInset: 0).width,
                          height: ReminderView.size(topInset: 0, sideInset: 0).height)
        let p = makePanel(size: size)
        p.hasShadow = true
        p.isMovableByWindowBackground = true

        let black = NSView(frame: NSRect(origin: .zero, size: size))
        black.wantsLayer = true
        black.layer?.backgroundColor = NSColor.black.cgColor
        black.layer?.cornerRadius = Island.panelRadius
        black.layer?.cornerCurve = .continuous
        black.layer?.masksToBounds = true
        let host = FirstMouseHostingView(rootView: content)
        host.frame = black.bounds
        host.autoresizingMask = [.width, .height]
        black.addSubview(host)
        p.contentView = black

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

/// The island at the top center: it grows out of the camera notch and goes back into it, like Dynamic Island.
/// The window covers the top of the screen around the notch; it only takes clicks over the island itself, so
/// the menu bar keeps working around it.
@MainActor
private final class DropAnimation: NSObject {
    private let session: ReminderSession
    private let window: NSPanel
    private let geometry: DropGeometry
    private let island = LayerView<CAShapeLayer>()
    private let shadow = LayerView<CALayer>()
    private let shadowMask = CAShapeLayer()
    private let contentMask = CAShapeLayer()
    private let host: NSView
    private var timer: Timer?
    private var started = Date()
    private var closing = false
    private var settled = false
    private let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

    init(session: ReminderSession, on screen: NSScreen) {
        self.session = session
        geometry = DropGeometry(screen: screen)
        window = makePanel(size: geometry.windowFrame.size)
        host = FirstMouseHostingView(rootView: ReminderView(s: session, topInset: geometry.topInset, sideInset: Island.earRadius)
            .environment(\.locale, Localizer.locale))
        super.init()

        window.hasShadow = false
        window.setFrame(geometry.windowFrame, display: false)
        let root = NSView(frame: NSRect(origin: .zero, size: geometry.windowFrame.size))
        root.wantsLayer = true

        // A soft shadow under the island, kept outside it
        shadow.frame = root.bounds
        shadow.shape.shadowColor = NSColor.black.cgColor
        shadow.shape.shadowRadius = 18
        shadow.shape.shadowOffset = CGSize(width: 0, height: -8)
        shadowMask.fillRule = .evenOdd
        shadowMask.frame = root.bounds
        shadow.shape.mask = shadowMask
        root.addSubview(shadow)

        island.frame = root.bounds
        island.shape.fillColor = NSColor.black.cgColor
        root.addSubview(island)

        // The contents are clipped to the island while it grows, so nothing shows outside the black
        host.frame = geometry.flip(geometry.drop.island)
        host.wantsLayer = true
        contentMask.frame = CGRect(origin: .zero, size: host.frame.size)
        host.layer?.mask = contentMask
        root.addSubview(host)
        window.contentView = root

        render(geometry.drop.frame(at: reduceMotion ? NotchDrop.openDuration : 0))
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
        settled = false
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
            render(geometry.drop.frame(at: elapsed, closing: true))
            if elapsed >= NotchDrop.closeDuration { finish(after: 0) }
            return
        }
        if reduceMotion || elapsed >= NotchDrop.openDuration {
            if !settled {
                settled = true
                render(geometry.drop.frame(at: NotchDrop.openDuration))
                // Open: keep checking whether the pointer is over the island, so clicks around it go through
                timer?.invalidate()
                let t = Timer(timeInterval: 1.0 / 30, target: self, selector: #selector(step), userInfo: nil, repeats: true)
                RunLoop.main.add(t, forMode: .common)
                timer = t
            }
            window.ignoresMouseEvents = !geometry.islandOnScreen.contains(NSEvent.mouseLocation)
        } else {
            render(geometry.drop.frame(at: elapsed))
        }
    }

    private func render(_ f: NotchDrop.Frame) {
        let outline = geometry.flip(f.outline)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        island.shape.path = outline
        shadow.shape.shadowPath = outline
        shadow.shape.shadowOpacity = Float(0.5 * f.shadow)
        let surround = CGMutablePath()
        surround.addRect(shadow.bounds)
        surround.addPath(outline)
        shadowMask.path = surround
        var toHost = CGAffineTransform(translationX: -host.frame.minX, y: -host.frame.minY)
        contentMask.path = outline.copy(using: &toHost)
        CATransaction.commit()
        if session.reveal != f.reveal { session.reveal = f.reveal }
    }

    private func finish(after delay: TimeInterval) {
        timer?.invalidate()
        timer = nil
        window.perform(#selector(NSWindow.orderOut(_:)), with: nil, afterDelay: delay)
    }
}

/// Where the notch, the island and the window are on a screen.
private struct DropGeometry {
    let windowFrame: NSRect
    let drop: NotchDrop
    let islandOnScreen: NSRect
    /// The height of the notch, or of the menu bar on a screen without one: the contents start below it.
    let topInset: CGFloat

    init(screen: NSScreen) {
        let frame = screen.frame
        let left = screen.auxiliaryTopLeftArea ?? .zero
        let right = screen.auxiliaryTopRightArea ?? .zero
        let hasNotch = screen.safeAreaInsets.top > 0 && left.width > 0 && right.width > 0
        // The menu bar, or the notch's height when the menu bar is hidden in full screen
        let menuBar = max(frame.maxY - screen.visibleFrame.maxY, screen.safeAreaInsets.top)
        topInset = hasNotch ? screen.safeAreaInsets.top : menuBar
        let size = ReminderView.size(topInset: topInset, sideInset: Island.earRadius)
        let margin: CGFloat = 40
        let islandX = (frame.midX - size.width / 2).rounded()
        windowFrame = NSRect(x: islandX - margin, y: frame.maxY - size.height - margin,
                             width: size.width + margin * 2, height: size.height + margin)
        islandOnScreen = NSRect(x: islandX, y: frame.maxY - size.height, width: size.width, height: size.height)

        // Window coordinates with y pointing down, so the top of the screen is 0
        let island = CGRect(x: margin, y: 0, width: size.width, height: size.height)
        if hasNotch {
            let notch = CGRect(x: left.maxX - windowFrame.minX, y: 0, width: right.minX - left.maxX, height: screen.safeAreaInsets.top)
            drop = NotchDrop(start: notch, island: island)
        } else {
            // No notch: it grows out of the top edge, from where one would be
            drop = NotchDrop(start: CGRect(x: island.midX - 90, y: 0, width: 180, height: 0), island: island)
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
