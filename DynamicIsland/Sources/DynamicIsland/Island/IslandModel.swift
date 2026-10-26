import AppKit
import SwiftUI

enum IslandTab: Hashable {
    case media, home, controls, posture, calendar, clipboard, system
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
    /// A reminder from the Posture app.
    case postureAlert
    /// Live activity: the posture figure and the progress towards a reminder.
    case postureCompact
    /// An event from the calendar is about to start.
    case calendarReminder
    /// Time for a glass of water.
    case waterReminder
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
    static let postureContentHeight: CGFloat = 150
    static let systemRowHeight: CGFloat = 34
    static let calendarRowHeight: CGFloat = 40
    static let maxCalendarRows = 4
    static let calendarEmptyHeight: CGFloat = 112
    static let clipboardRowHeight: CGFloat = 36
    static let maxClipboardRows = 5
    static let clipboardEmptyHeight: CGFloat = 112
}

@MainActor @Observable
final class IslandModel {
    let media: NowPlayingService
    let audio: AudioService
    let brightness: BrightnessService
    let home: HomeService
    let posture: PostureService
    let system: SystemService
    let calendar: CalendarService
    let clipboard: ClipboardService
    let water: WaterService
    let settings: AppSettings

    var metrics = NotchMetrics.fallback
    private(set) var isOpen = false
    private(set) var isHovering = false
    private(set) var hud: HUDKind?
    private(set) var isPeeking = false
    /// The Home tab is showing the list for picking shortcuts.
    private(set) var isChoosingShortcuts = false
    private(set) var isShowingPostureAlert = false
    private(set) var isShowingCalendarReminder = false
    private(set) var isShowingWaterReminder = false
    var tab: IslandTab = .media

    @ObservationIgnored var onOpenSettings: (() -> Void)?
    @ObservationIgnored var onOpenWelcome: (() -> Void)?
    @ObservationIgnored private var openTask: Task<Void, Never>?
    @ObservationIgnored private var closeTask: Task<Void, Never>?
    @ObservationIgnored private var hudTask: Task<Void, Never>?
    @ObservationIgnored private var peekTask: Task<Void, Never>?
    @ObservationIgnored private var postureAlertTask: Task<Void, Never>?
    @ObservationIgnored private var calendarReminderTask: Task<Void, Never>?
    @ObservationIgnored private var waterReminderTask: Task<Void, Never>?
    @ObservationIgnored private let keyInterceptor = MediaKeyInterceptor()
    @ObservationIgnored private var permissionPoll: Timer?

    init(media: NowPlayingService, audio: AudioService, brightness: BrightnessService, home: HomeService,
         posture: PostureService, system: SystemService, calendar: CalendarService, clipboard: ClipboardService,
         water: WaterService, settings: AppSettings) {
        self.media = media
        self.audio = audio
        self.brightness = brightness
        self.home = home
        self.posture = posture
        self.system = system
        self.calendar = calendar
        self.clipboard = clipboard
        self.water = water
        self.settings = settings

        media.onTrackChange = { [weak self] in self?.showTrackPeek() }
        posture.onAlert = { [weak self] _ in self?.showPostureAlert() }
        calendar.onReminder = { [weak self] _ in self?.showCalendarReminder() }
        calendar.leadMinutes = { [weak settings] in settings?.calendarLeadMinutes ?? 15 }
        calendar.hiddenCalendars = { [weak settings] in settings?.hiddenCalendarIDs ?? [] }
        water.onDue = { [weak self] in self?.showWaterReminder() }
        water.isEnabled = { [weak settings] in settings?.showWaterReminders ?? false }
        water.interval = { [weak settings] in TimeInterval((settings?.waterIntervalMinutes ?? 45) * 60) }
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
        IslandPresentation(PresentationState(
            isOpen: isOpen,
            hud: hud,
            showsCalendarReminder: isShowingCalendarReminder && calendar.reminder != nil,
            showsWaterReminder: isShowingWaterReminder && water.isDue,
            showsPostureAlert: isShowingPostureAlert && posture.latestAlert != nil,
            showsTrackPeek: isPeeking && media.hasMedia,
            showsMediaActivity: settings.showLiveActivity && media.hasMedia && media.isPlaying,
            showsPostureActivity: showsPostureCompact
        ))
    }

    /// Bad posture for a while, and no music taking the spot.
    private var showsPostureCompact: Bool {
        guard settings.showPostureLiveActivity, posture.isConnected, let state = posture.state else { return false }
        return state.isBad && state.progress >= 0.5 && !(media.hasMedia && media.isPlaying)
    }

    var showsPostureTab: Bool { settings.showPostureTab && posture.isConnected }
    var showsCalendarTab: Bool { settings.showCalendarTab }
    var showsClipboardTab: Bool { settings.showClipboardTab }

    var animation: Animation {
        switch presentation {
        case .open: .spring(response: 0.42, dampingFraction: 0.74)
        case .closed: .spring(response: 0.38, dampingFraction: 0.9)
        default: .spring(response: 0.48, dampingFraction: 0.68)
        }
    }

    // MARK: Geometry

    var geometry: IslandGeometry {
        IslandGeometry(presentation: presentation, metrics: metrics, isHovering: isHovering,
                       openContentHeight: isOpen ? openContentHeight : 0)
    }

    var notch: CGSize { metrics.notchSize }
    var hudSideWidth: CGFloat { geometry.hudSideWidth }
    var earRadius: CGFloat { geometry.earRadius }
    var bottomRadius: CGFloat { geometry.bottomRadius }
    var size: CGSize { geometry.size }
    var hoverZone: CGRect { geometry.hoverZone }

    /// The selected tab, falling back to media when the Home or posture tab is hidden.
    var currentTab: IslandTab {
        switch tab {
        case .home where !settings.showHomeTab: .media
        case .posture where !showsPostureTab: .media
        case .calendar where !showsCalendarTab: .media
        case .clipboard where !showsClipboardTab: .media
        default: tab
        }
    }

    var openContentHeight: CGFloat {
        switch currentTab {
        case .media:
            return IslandLayout.mediaContentHeight
        case .home:
            if isChoosingShortcuts {
                let rows = CGFloat(min(max(home.allShortcuts.count, 1), IslandLayout.maxVisibleDevices))
                return 4 + IslandLayout.sectionHeaderHeight + 6 + rows * IslandLayout.deviceRowHeight + 16
            }
            let count = home.shortcuts.count
            guard count > 0 else { return IslandLayout.homeEmptyHeight }
            // One extra slot for the "+" tile.
            let tiles = count + 1
            let rows = CGFloat(min((tiles + IslandLayout.homeColumns - 1) / IslandLayout.homeColumns, IslandLayout.maxHomeRows))
            return 4 + rows * IslandLayout.homeTileHeight + (rows - 1) * IslandLayout.homeTileSpacing + 18
        case .posture:
            return IslandLayout.postureContentHeight
        case .calendar:
            guard calendar.access == .granted, !calendar.events.isEmpty else { return IslandLayout.calendarEmptyHeight }
            let rows = CGFloat(min(calendar.events.count, IslandLayout.maxCalendarRows))
            return 4 + IslandLayout.sectionHeaderHeight + rows * IslandLayout.calendarRowHeight + 16
        case .clipboard:
            guard !clipboard.items.isEmpty else { return IslandLayout.clipboardEmptyHeight }
            let rows = CGFloat(min(clipboard.items.count, IslandLayout.maxClipboardRows))
            return 4 + IslandLayout.sectionHeaderHeight + rows * IslandLayout.clipboardRowHeight + 16
        case .system:
            return 4 + CGFloat(system.rowCount) * IslandLayout.systemRowHeight + 16
        case .controls:
            let sliders: CGFloat = brightness.isAvailable ? 2 : 1
            let rows = CGFloat(min(audio.devices.count, IslandLayout.maxVisibleDevices))
            return 4 + sliders * IslandLayout.sliderRowHeight + 8 + IslandLayout.sectionHeaderHeight
                + rows * IslandLayout.deviceRowHeight + 16
        }
    }

    // MARK: Interaction

    func setHovering(_ hovering: Bool) {
        guard hovering != isHovering else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.66)) { isHovering = hovering }

        if hovering {
            closeTask?.cancel()
            // The water reminder has its own buttons, so hovering it doesn't open the island.
            if settings.hoverToOpen && !isOpen && presentation != .waterReminder {
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
        postureAlertTask?.cancel()
        calendarReminderTask?.cancel()
        if isShowingWaterReminder { dismissWaterReminder(drank: false) }
        if isShowingCalendarReminder && showsCalendarTab { tab = .calendar }
        hud = nil
        isPeeking = false
        isShowingPostureAlert = false
        isShowingCalendarReminder = false
        if currentTab == .home { home.refresh() }
        if currentTab == .calendar { calendar.reload() }
        isOpen = true
    }

    func performHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard settings.hapticFeedback else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        isChoosingShortcuts = false
    }

    func setChoosingShortcuts(_ choosing: Bool) {
        if choosing { home.refresh() }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { isChoosingShortcuts = choosing }
    }

    func toggle() { isOpen ? close() : open() }

    /// Copies an older clipboard item again and, if allowed, pastes it into the app in front.
    func useClipboardItem(_ item: ClipboardItem) {
        clipboard.use(item, paste: settings.pasteFromClipboardHistory)
        close()
    }

    func select(_ tab: IslandTab) {
        if tab == .home { home.refresh() }
        if tab == .calendar { calendar.reload() }
        isChoosingShortcuts = false
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

    func showPostureAlert() {
        guard settings.showPostureAlerts, !isOpen else { return }
        isPeeking = false
        isShowingPostureAlert = true
        performHaptic(.generic)
        postureAlertTask?.cancel()
        postureAlertTask = schedule(after: 6) { $0.isShowingPostureAlert = false }
    }

    func showCalendarReminder() {
        guard settings.showCalendarReminders, !isOpen else { return }
        isPeeking = false
        isShowingPostureAlert = false
        isShowingCalendarReminder = true
        performHaptic(.generic)
        calendarReminderTask?.cancel()
        calendarReminderTask = schedule(after: 12) { $0.isShowingCalendarReminder = false }
    }

    /// Pops out of the notch until the user answers; left alone, it asks again later.
    func showWaterReminder() {
        guard settings.showWaterReminders, !isOpen, !isShowingWaterReminder else { return }
        isPeeking = false
        isShowingPostureAlert = false
        isShowingWaterReminder = true
        performHaptic(.generic)
        waterReminderTask?.cancel()
        waterReminderTask = schedule(after: 20) { $0.dismissWaterReminder(drank: false) }
    }

    func dismissWaterReminder(drank: Bool) {
        waterReminderTask?.cancel()
        if drank { water.drink() } else { water.snooze() }
        isShowingWaterReminder = false
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
