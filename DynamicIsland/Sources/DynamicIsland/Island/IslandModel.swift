import AppKit
import SwiftUI

enum IslandTab: Hashable {
    case media, home, controls
}

enum HUDKind: Equatable {
    case volume, brightness, outputDevice
}

enum IslandPresentation: Equatable {
    case closed
    /// Live activity: artwork and equalizer on either side of the notch.
    case compact
    /// Briefly shows the new song after a track change.
    case peek
    case hud(HUDKind)
    case open
}

/// Shared measurements so the shape and the content always agree.
enum IslandLayout {
    static let mediaContentHeight: CGFloat = 162
    static let sliderRowHeight: CGFloat = 30
    static let deviceRowHeight: CGFloat = 34
    static let sectionHeaderHeight: CGFloat = 22
    static let maxVisibleDevices = 5
    static let contentPadding: CGFloat = 20
    static let homeColumns = 4
    static let homeTileHeight: CGFloat = 80
    static let homeTileSpacing: CGFloat = 8
    static let maxHomeRows = 3
    static let homeEmptyHeight: CGFloat = 112
}

@MainActor @Observable
final class IslandModel {
    let media: NowPlayingService
    let audio: AudioService
    let brightness: BrightnessService
    let home: HomeService
    let settings: AppSettings

    var metrics = NotchMetrics.fallback
    private(set) var isOpen = false
    private(set) var isHovering = false
    private(set) var hud: HUDKind?
    private(set) var isPeeking = false
    var tab: IslandTab = .media

    @ObservationIgnored var onOpenSettings: (() -> Void)?
    @ObservationIgnored private var openTask: Task<Void, Never>?
    @ObservationIgnored private var closeTask: Task<Void, Never>?
    @ObservationIgnored private var hudTask: Task<Void, Never>?
    @ObservationIgnored private var peekTask: Task<Void, Never>?
    @ObservationIgnored private let keyInterceptor = MediaKeyInterceptor()
    @ObservationIgnored private var permissionPoll: Timer?

    init(media: NowPlayingService, audio: AudioService, brightness: BrightnessService, home: HomeService, settings: AppSettings) {
        self.media = media
        self.audio = audio
        self.brightness = brightness
        self.home = home
        self.settings = settings

        media.onTrackChange = { [weak self] in self?.showTrackPeek() }
        audio.onExternalVolumeChange = { [weak self] in
            guard let self, self.settings.showVolumeHUD || self.isReplacingSystemHUD else { return }
            self.showHUD(.volume)
        }
        audio.onOutputDeviceChange = { [weak self] _ in
            guard let self, self.settings.showDeviceChanges else { return }
            self.showHUD(.outputDevice)
        }
        keyInterceptor.handler = { [weak self] key, fine in
            self?.handleKey(key, fine: fine) ?? false
        }
        settings.onReplaceSystemHUDChange = { [weak self] in self?.updateKeyInterception(requestPermission: true) }
        updateKeyInterception(requestPermission: false)
    }

    // MARK: Presentation

    var presentation: IslandPresentation {
        if isOpen { return .open }
        if let hud { return .hud(hud) }
        if isPeeking && media.hasMedia { return .peek }
        if settings.showLiveActivity && media.hasMedia && media.isPlaying { return .compact }
        return .closed
    }

    var animation: Animation {
        switch presentation {
        case .open: .spring(response: 0.42, dampingFraction: 0.74)
        case .closed: .spring(response: 0.38, dampingFraction: 0.9)
        default: .spring(response: 0.48, dampingFraction: 0.68)
        }
    }

    // MARK: Geometry

    var notch: CGSize { metrics.notchSize }

    var compactSideWidth: CGFloat { notch.height + 4 }
    var hudSideWidth: CGFloat { 66 }

    /// Width of the concave "ears" that blend the island into the top edge.
    var earRadius: CGFloat {
        switch presentation {
        case .closed: isHovering ? 6 : 0
        case .compact, .hud(.volume), .hud(.brightness): 8
        case .peek, .hud(.outputDevice): 10
        case .open: 14
        }
    }

    var bottomRadius: CGFloat {
        switch presentation {
        case .closed: isHovering ? 12 : 8
        case .compact, .hud(.volume), .hud(.brightness): 13
        case .peek, .hud(.outputDevice): 22
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
        case .compact:
            return CGSize(width: notch.width + compactSideWidth * 2 + ears, height: notch.height)
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

    /// The selected tab, falling back to media when the Home tab is turned off.
    var currentTab: IslandTab {
        tab == .home && !settings.showHomeTab ? .media : tab
    }

    var openContentHeight: CGFloat {
        switch currentTab {
        case .media:
            return IslandLayout.mediaContentHeight
        case .home:
            let count = home.shortcuts.count
            guard count > 0 else { return IslandLayout.homeEmptyHeight }
            let rows = CGFloat(min((count + IslandLayout.homeColumns - 1) / IslandLayout.homeColumns, IslandLayout.maxHomeRows))
            return 4 + rows * IslandLayout.homeTileHeight + (rows - 1) * IslandLayout.homeTileSpacing + 18
        case .controls:
            let sliders: CGFloat = brightness.isAvailable ? 2 : 1
            let rows = CGFloat(min(audio.devices.count, IslandLayout.maxVisibleDevices))
            return 4 + sliders * IslandLayout.sliderRowHeight + 8 + IslandLayout.sectionHeaderHeight
                + rows * IslandLayout.deviceRowHeight + 16
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

    // MARK: Interaction

    func setHovering(_ hovering: Bool) {
        guard hovering != isHovering else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.66)) { isHovering = hovering }

        if hovering {
            closeTask?.cancel()
            if settings.hoverToOpen && !isOpen {
                // Trackpad haptics only play while a finger touches the pad, so they go out
                // with the movement that reached the notch, not with the delayed open.
                performHaptic(.levelChange)
                openTask = schedule(after: 0.09) { $0.open() }
            }
        } else {
            openTask?.cancel()
            if isOpen {
                closeTask = schedule(after: 0.22) { $0.close() }
            }
        }
    }

    func open() {
        guard !isOpen else { return }
        brightness.refresh()
        hudTask?.cancel()
        peekTask?.cancel()
        hud = nil
        isPeeking = false
        if currentTab == .home { home.refresh() }
        isOpen = true
    }

    func performHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard settings.hapticFeedback else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
    }

    func toggle() { isOpen ? close() : open() }

    func select(_ tab: IslandTab) {
        if tab == .home { home.refresh() }
        guard tab != self.tab else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { self.tab = tab }
    }

    // MARK: Live activities

    func showHUD(_ kind: HUDKind) {
        guard !isOpen else { return }
        isPeeking = false
        hud = kind
        hudTask?.cancel()
        hudTask = schedule(after: kind == .outputDevice ? 2.6 : 1.6) { $0.hud = nil }
    }

    func showTrackPeek() {
        guard settings.showTrackChanges, !isOpen, hud == nil, media.isPlaying else { return }
        isPeeking = true
        peekTask?.cancel()
        peekTask = schedule(after: 3.2) { $0.isPeeking = false }
    }

    // MARK: Keyboard

    var isReplacingSystemHUD: Bool { keyInterceptor.isRunning }

    func updateKeyInterception(requestPermission: Bool) {
        permissionPoll?.invalidate()
        guard settings.replaceSystemHUD else {
            keyInterceptor.stop()
            return
        }
        if keyInterceptor.start() { return }
        if requestPermission { MediaKeyInterceptor.requestPermission() }
        // Start as soon as the user grants Accessibility access.
        permissionPoll = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, self.settings.replaceSystemHUD else { return timer.invalidate() }
                if self.keyInterceptor.start() { timer.invalidate() }
            }
        }
    }

    private func handleKey(_ key: MediaKeyInterceptor.Key, fine: Bool) -> Bool {
        switch key {
        case .volumeUp, .volumeDown, .mute:
            guard audio.canSetVolume else { return false }
            switch key {
            case .volumeUp: audio.stepVolume(by: 1, fine: fine)
            case .volumeDown: audio.stepVolume(by: -1, fine: fine)
            default: audio.toggleMute()
            }
            showHUD(.volume)
        case .brightnessUp, .brightnessDown:
            guard brightness.isAvailable else { return false }
            brightness.step(by: key == .brightnessUp ? 1 : -1, fine: fine)
            showHUD(.brightness)
        }
        return true
    }

    private func schedule(after seconds: Double, _ action: @escaping @MainActor (IslandModel) -> Void) -> Task<Void, Never> {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self else { return }
            action(self)
        }
    }
}
