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

/// A floating, non-activating glass panel in a corner of the screen. It never steals focus.
@MainActor
final class ReminderPanel {
    private var panel: NSPanel?
    private var slideOffset: CGFloat = 0

    func show(_ session: ReminderSession, at position: ReminderPosition) {
        close()
        let size = NSSize(width: ReminderView.size.width, height: ReminderView.size.height)
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .statusBar
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = true
        p.isMovableByWindowBackground = true
        p.isReleasedWhenClosed = false

        let glass = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        glass.material = .popover
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.maskImage = .roundedMask(radius: ReminderView.cornerRadius)

        let host = FirstMouseHostingView(rootView: ReminderView(s: session).environment(\.locale, Localizer.locale))
        host.frame = glass.bounds
        host.autoresizingMask = [.width, .height]
        glass.addSubview(host)
        p.contentView = glass

        // Use the screen the pointer is on
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let vf = screen.visibleFrame
        let inset: CGFloat = 16
        let target: NSRect
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if position == .topCenter {
            // Drops down out of the camera notch: the panel sits just below the menu bar while it slides,
            // so it seems to come out from behind it
            target = NSRect(x: vf.midX - size.width / 2, y: vf.maxY - size.height - 10, width: size.width, height: size.height)
            p.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue - 1)
            slideOffset = reduceMotion ? 0 : 46
        } else {
            let x = position.isLeft ? vf.minX + inset : vf.maxX - size.width - inset
            let y = position.isTop ? vf.maxY - size.height - inset : vf.minY + inset
            target = NSRect(x: x, y: y, width: size.width, height: size.height)
            // Slide in from the nearest horizontal edge and leave the same way
            slideOffset = reduceMotion ? 0 : (position.isTop ? 20 : -20)
        }

        p.setFrame(target.offsetBy(dx: 0, dy: slideOffset), display: false)
        p.alphaValue = 0
        p.orderFrontRegardless()
        p.invalidateShadow()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = reduceMotion ? 0.25 : (position == .topCenter ? 0.55 : 0.45)
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.84, 0.24, 1)
            p.animator().setFrame(target, display: true)
            p.animator().alphaValue = 1
        }

        NSAccessibility.post(element: p, notification: .announcementRequested, userInfo: [
            .announcement: "\(L("Stretch break")): \(session.current.title). \(session.current.text)",
            .priority: NSAccessibilityPriorityLevel.high.rawValue,
        ])
        panel = p
    }

    func close() {
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
}
