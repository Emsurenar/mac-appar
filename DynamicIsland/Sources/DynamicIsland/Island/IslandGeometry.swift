import CoreGraphics

/// The facts that decide what the closed island shows, gathered from the services.
/// Kept as plain values so the priority order can be tested without them.
struct PresentationState: Equatable {
    var isOpen = false
    var hud: HUDKind?
    var showsCalendarReminder = false
    var showsWaterReminder = false
    var showsPostureAlert = false
    var showsTrackPeek = false
    var showsMediaActivity = false
    var showsPostureActivity = false
}

extension IslandPresentation {
    /// Picks the presentation with the highest priority: an open island first, then HUDs,
    /// reminders, the track peek and last the live activities.
    init(_ state: PresentationState) {
        if state.isOpen { self = .open }
        else if let hud = state.hud { self = .hud(hud) }
        else if state.showsCalendarReminder { self = .calendarReminder }
        else if state.showsWaterReminder { self = .waterReminder }
        else if state.showsPostureAlert { self = .postureAlert }
        else if state.showsTrackPeek { self = .peek }
        else if state.showsMediaActivity { self = .compact }
        else if state.showsPostureActivity { self = .postureCompact }
        else { self = .closed }
    }
}

/// The island's shape for one presentation: its size, corner radii and the area that counts as hovering it.
struct IslandGeometry: Equatable {
    var presentation: IslandPresentation
    var metrics: NotchMetrics
    var isHovering: Bool
    /// Height of the open island's content; only used while it's open.
    var openContentHeight: CGFloat

    var notch: CGSize { metrics.notchSize }

    var compactSideWidth: CGFloat { notch.height + 4 }
    var hudSideWidth: CGFloat { 66 }

    /// Width of the concave "ears" that blend the island into the top edge.
    var earRadius: CGFloat {
        switch presentation {
        case .closed: isHovering ? 6 : 0
        case .compact, .postureCompact, .hud(.volume), .hud(.brightness): 8
        case .peek, .postureAlert, .calendarReminder, .waterReminder, .hud(.outputDevice): 10
        case .open: 14
        }
    }

    var bottomRadius: CGFloat {
        switch presentation {
        case .closed: isHovering ? 12 : 8
        case .compact, .postureCompact, .hud(.volume), .hud(.brightness): 13
        case .peek, .hud(.outputDevice): 22
        case .postureAlert, .calendarReminder, .waterReminder: 24
        case .open: 32
        }
    }

    var openWidth: CGFloat { max(notch.width + 340, 500) }

    var size: CGSize {
        let ears = earRadius * 2
        switch presentation {
        case .closed:
            if !metrics.hasNotch { return CGSize(width: notch.width, height: isHovering ? 8 : 0) }
            return isHovering ? CGSize(width: notch.width + 16 + ears, height: notch.height + 4) : notch
        case .compact, .postureCompact:
            return CGSize(width: notch.width + compactSideWidth * 2 + ears, height: notch.height)
        case .postureAlert:
            return CGSize(width: notch.width + 260 + ears, height: notch.height + 64)
        case .calendarReminder:
            return CGSize(width: notch.width + 300 + ears, height: notch.height + 64)
        case .waterReminder:
            return CGSize(width: notch.width + 300 + ears, height: notch.height + 64)
        case .hud(.volume), .hud(.brightness):
            return CGSize(width: notch.width + hudSideWidth * 2 + ears, height: notch.height)
        case .peek:
            return CGSize(width: notch.width + 200 + ears, height: notch.height + 52)
        case .hud(.outputDevice):
            return CGSize(width: notch.width + 170 + ears, height: notch.height + 50)
        case .open:
            return CGSize(width: openWidth + ears, height: notch.height + openContentHeight)
        }
    }

    /// The region (in screen coordinates) where the pointer counts as "on the island".
    var hoverZone: CGRect {
        let size = size
        let screen = metrics.screenFrame
        var rect = CGRect(x: metrics.centerX - size.width / 2, y: screen.maxY - size.height,
                          width: size.width, height: size.height)
        switch presentation {
        case .closed:
            let height = max(notch.height, 8)
            rect = CGRect(x: metrics.centerX - notch.width / 2 - 10, y: screen.maxY - height,
                          width: notch.width + 20, height: height)
        case .open:
            rect = rect.insetBy(dx: -8, dy: -8)
        default:
            rect = rect.insetBy(dx: -2, dy: -2)
        }
        rect.size.height += 8 // the pointer can sit on the very top edge
        return rect
    }
}
