import AppKit
import SwiftUI

enum IslandTab: Hashable {
    case media, home, posture, water, calendar, clipboard, system
    /// The island's own settings page, last in the row like the gear always was.
    case settings

    /// The settings page for this tab, so the island and Settings always line up.
    var settingsPage: SettingsPage {
        switch self {
        case .settings: .general
        case .media: .nowPlaying
        case .home: .home
        case .posture: .posture
        case .water: .water
        case .calendar: .calendar
        case .clipboard: .clipboard
        case .system: .system
        }
    }

    var symbol: String { self == .settings ? "gearshape.fill" : settingsPage.symbol }
    var title: String { self == .settings ? "Settings" : settingsPage.title }
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
    /// A screenshot was just taken; it can be dragged out of the island.
    case screenshot
    case open
}

/// Shared measurements so the shape and the content always agree.
enum IslandLayout {
    static let mediaContentHeight: CGFloat = 162
    /// A slider under the player, with the gap above it.
    static let mediaRowHeight: CGFloat = 26
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
    static let waterContentHeight: CGFloat = 124
    static let calendarRowHeight: CGFloat = 40
    static let maxCalendarRows = 4
    static let calendarEmptyHeight: CGFloat = 112
    static let assistantFieldHeight: CGFloat = 38
    static let assistantLineHeight: CGFloat = 16
    static let shelfTileWidth: CGFloat = 76
    static let shelfTileHeight: CGFloat = 78
    /// The drop target above the clipboard while no files are shelved.
    static let shelfDropStripHeight: CGFloat = 44
    static let shelfSpacing: CGFloat = 8
    static let clipboardRowHeight: CGFloat = 36
    static let maxClipboardRows = 5
    static let clipboardEmptyHeight: CGFloat = 112
    /// Four rows show at once in the island's settings; more scroll.
    static let settingsListHeight: CGFloat = 4 * systemRowHeight
    static let screenshotThumbnailSize = CGSize(width: 96, height: 60)
}

@MainActor @Observable
final class IslandModel {
    let media: NowPlayingService
    let audio: AudioService
    let brightness: BrightnessService
    let airPods: AirPodsService
    let home: HomeService
    let posture: PostureService
    let system: SystemService
    let calendar: CalendarService
    /// Typed questions and changes in the calendar tab.
    let assistant: CalendarAssistant
    let shelf: FileShelf
    let clipboard: ClipboardService
    let water: WaterService
    let screenshots: ScreenshotService
    let downloads: DownloadsService
    let settings: AppSettings
    let companions: CompanionApps

    var metrics = NotchMetrics.fallback
    private(set) var isOpen = false
    private(set) var isHovering = false
    private(set) var hud: HUDKind?
    private(set) var isPeeking = false
    /// The Home tab is showing the list for picking shortcuts.
    private(set) var isChoosingShortcuts = false
    /// The media tab has unfolded noise control and the list of outputs.
    private(set) var isChoosingOutput = false
    private(set) var isShowingPostureAlert = false
    private(set) var isShowingCalendarReminder = false
    /// Files are being dragged over the island.
    private(set) var isDropTargeted = false
    private(set) var isShowingWaterReminder = false
    private(set) var isShowingScreenshot = false
    /// The screenshot is being dragged; the island keeps it until the drag ends.
    private(set) var isDraggingScreenshot = false
    /// The calendar assistant's field has the keyboard, so the island stays open when the pointer leaves.
    private(set) var isTyping = false
    /// A screenshot came in while the island was open; it pops out once the island closes.
    @ObservationIgnored private var hasPendingScreenshot = false
    var tab: IslandTab = .media

    @ObservationIgnored var onOpenSettings: (() -> Void)?
    /// The page the settings window shows.
    var settingsPage: SettingsPage = .general
    /// The part whose switches the island's own settings page shows.
    var islandSettingsSection: SettingsPage = .general
    @ObservationIgnored var onOpenWelcome: (() -> Void)?
    @ObservationIgnored private var openTask: Task<Void, Never>?
    @ObservationIgnored private var closeTask: Task<Void, Never>?
    @ObservationIgnored private var hudTask: Task<Void, Never>?
    @ObservationIgnored private var peekTask: Task<Void, Never>?
    @ObservationIgnored private var postureAlertTask: Task<Void, Never>?
    @ObservationIgnored private var calendarReminderTask: Task<Void, Never>?
    @ObservationIgnored private var waterReminderTask: Task<Void, Never>?
    @ObservationIgnored private var screenshotTask: Task<Void, Never>?
    @ObservationIgnored private let keyInterceptor = MediaKeyInterceptor()
    @ObservationIgnored private var permissionPoll: Timer?

    init(media: NowPlayingService, audio: AudioService, brightness: BrightnessService, airPods: AirPodsService,
         home: HomeService, posture: PostureService, system: SystemService, calendar: CalendarService, clipboard: ClipboardService,
         water: WaterService, screenshots: ScreenshotService, downloads: DownloadsService, shelf: FileShelf? = nil, settings: AppSettings) {
        self.media = media
        self.audio = audio
        self.brightness = brightness
        self.airPods = airPods
        self.home = home
        self.posture = posture
        self.system = system
        self.calendar = calendar
        self.assistant = CalendarAssistant(calendar: calendar)
        self.shelf = shelf ?? FileShelf()
        self.clipboard = clipboard
        self.water = water
        self.screenshots = screenshots
        self.downloads = downloads
        self.settings = settings
        self.companions = CompanionApps(settings: settings)

        media.onTrackChange = { [weak self] in self?.showTrackPeek() }
        posture.onAlert = { [weak self] _ in self?.showPostureAlert() }
        calendar.onReminder = { [weak self] _ in self?.showCalendarReminder() }
        self.screenshots.onNewScreenshot = { [weak self] shot in
            self?.shelveNewFiles([shot.url])
            self?.showScreenshot()
        }
        downloads.onNewFiles = { [weak self] urls in self?.shelveNewFiles(urls) }
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
            guard let self else { return }
            self.airPods.refresh(for: self.audio.currentDevice)
            guard self.settings.showDeviceChanges else { return }
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
            showsScreenshot: (isShowingScreenshot || isDraggingScreenshot) && screenshots.latest != nil,
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
    var showsShelf: Bool { settings.showShelfTab }
    /// Clipboard history and the file shelf share one tab.
    var showsClipboardTab: Bool { settings.showClipboardTab || showsShelf }
    var showsSystemTab: Bool { settings.showSystemTab }
    var showsWaterTab: Bool { settings.showWaterTab }

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

    /// The selected tab, falling back to media when that tab is hidden.
    var currentTab: IslandTab {
        switch tab {
        case .home where !settings.showHomeTab: .media
        case .posture where !showsPostureTab: .media
        case .calendar where !showsCalendarTab: .media
        case .clipboard where !showsClipboardTab: .media
        case .system where !showsSystemTab: .media
        case .water where !showsWaterTab: .media
        default: tab
        }
    }

    var openContentHeight: CGFloat {
        switch currentTab {
        case .media:
            var height = IslandLayout.mediaContentHeight
            if brightness.isAvailable { height += IslandLayout.mediaRowHeight }
            if isChoosingOutput { height += outputPanelHeight }
            return height
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
        case .water:
            return IslandLayout.waterContentHeight
        case .calendar:
            guard calendar.access == .signedIn else { return IslandLayout.calendarEmptyHeight }
            var height = IslandLayout.assistantFieldHeight + assistantAnswerHeight
            if calendar.events.isEmpty {
                height += IslandLayout.calendarEmptyHeight
            } else {
                let rows = CGFloat(min(calendar.events.count, IslandLayout.maxCalendarRows))
                height += 4 + IslandLayout.sectionHeaderHeight + rows * IslandLayout.calendarRowHeight + 16
            }
            return height
        case .clipboard:
            var height: CGFloat = 4 + 16
            if showsShelf {
                height += shelf.isEmpty ? IslandLayout.shelfDropStripHeight
                    : IslandLayout.sectionHeaderHeight + IslandLayout.shelfTileHeight + 8
                height += IslandLayout.shelfSpacing
            }
            if settings.showClipboardTab {
                if clipboard.items.isEmpty {
                    height += IslandLayout.clipboardEmptyHeight - 34
                } else {
                    let rows = CGFloat(min(clipboard.items.count, IslandLayout.maxClipboardRows))
                    height += IslandLayout.sectionHeaderHeight + rows * IslandLayout.clipboardRowHeight
                }
            }
            return height
        case .system:
            return 4 + CGFloat(system.rowCount) * IslandLayout.systemRowHeight + 16
        case .settings:
            return 2 + 26 + IslandLayout.sectionHeaderHeight + IslandLayout.settingsListHeight + 14
        }
    }

    /// Room for the assistant's answer: about 62 characters a line, at most five lines.
    var assistantAnswerHeight: CGFloat {
        let text = assistant.isWorking ? (assistant.question ?? "") : (assistant.errorMessage ?? assistant.reply ?? "")
        guard assistant.isWorking || !text.isEmpty else { return 0 }
        let lines = assistant.isWorking ? 1 : min(max(Int((Double(text.count) / 62).rounded(.up)), 1), 5)
        return 14 + CGFloat(lines) * IslandLayout.assistantLineHeight
    }

    private var outputPanelHeight: CGFloat {
        let rows = CGFloat(min(audio.devices.count, IslandLayout.maxVisibleDevices))
        return 6 + IslandLayout.sectionHeaderHeight + rows * IslandLayout.deviceRowHeight
    }

    // MARK: Interaction

    func setHovering(_ hovering: Bool) {
        guard hovering != isHovering else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.66)) { isHovering = hovering }

        if hovering {
            closeTask?.cancel()
            // Hovering the screenshot holds it in place instead of opening the island over it.
            if presentation == .screenshot {
                screenshotTask?.cancel()
            // The water reminder has its own buttons, so hovering it holds it instead of opening the island.
            } else if presentation == .waterReminder {
                waterReminderTask?.cancel()
            } else if settings.hoverToOpen && !isOpen {
                // Trackpad haptics only play while a finger touches the pad, so they go out
                // with the movement that reached the notch, not with the delayed open.
                performHaptic(.levelChange)
                openTask = schedule(after: 0.09) { $0.open() }
            }
        } else {
            openTask?.cancel()
            if isOpen && !isTyping && !assistant.isWorking {
                closeTask = schedule(after: 0.22) { $0.close() }
            }
            if isShowingScreenshot && !isDraggingScreenshot { scheduleScreenshotDismissal(after: 3) }
            if isShowingWaterReminder { scheduleWaterReminderDismissal(after: 6) }
        }
    }

    func open() {
        guard !isOpen else { return }
        brightness.refresh()
        hudTask?.cancel()
        peekTask?.cancel()
        postureAlertTask?.cancel()
        calendarReminderTask?.cancel()
        // Tapping the water reminder opens the Water tab, so the glass can be logged there.
        if isShowingWaterReminder {
            dismissWaterReminder(drank: false)
            if showsWaterTab { tab = .water }
        }
        screenshotTask?.cancel()
        if isShowingCalendarReminder && showsCalendarTab { tab = .calendar }
        hud = nil
        isPeeking = false
        isShowingPostureAlert = false
        isShowingCalendarReminder = false
        isShowingScreenshot = false
        if currentTab == .home { home.refresh() }
        if currentTab == .calendar { calendar.reload() }
        if currentTab == .clipboard { shelf.prune() }
        isOpen = true
    }

    // MARK: Shelf

    /// Files dragged onto the island open it on the shelf, ready for the drop.
    func setDropTargeted(_ targeted: Bool) {
        guard targeted != isDropTargeted else { return }
        isDropTargeted = targeted
        if targeted { showShelfForDrop() }
    }

    func showShelfForDrop() {
        guard acceptsFileDrops else { return }
        closeTask?.cancel()
        if isOpen {
            select(.clipboard)
        } else {
            tab = .clipboard
            open()
        }
    }

    /// Whether files dragged over the island can go on the shelf; not the island's own screenshot or shelf files.
    var acceptsFileDrops: Bool { showsShelf && !ShelfDragSource.isDragging && !isDraggingScreenshot }

    /// Keeps the dropped files for a few minutes.
    /// `force` is for promised files that arrive after the drop, when another drag may be under way.
    func dropFiles(_ urls: [URL], force: Bool = false) -> Bool {
        isDropTargeted = false
        guard force ? showsShelf : acceptsFileDrops, !urls.isEmpty else { return false }
        shelf.add(urls, for: Self.shelfDuration)
        if !isOpen { showShelfForDrop() }
        return true
    }

    /// How long files stay on the shelf.
    static let shelfDuration: TimeInterval = 5 * 60

    /// Puts a new screenshot or download on the shelf for a few minutes.
    func shelveNewFiles(_ urls: [URL]) {
        guard showsShelf, settings.shelveNewFiles else { return }
        shelf.add(urls, for: Self.shelfDuration)
    }

    func performHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard settings.hapticFeedback else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    func close() {
        guard isOpen else { return }
        isOpen = false
        isTyping = false
        tab = .media  // Always reopen on the first tab.
        isChoosingShortcuts = false
        isChoosingOutput = false
        if hasPendingScreenshot { showScreenshot() }
    }

    func setTyping(_ typing: Bool) {
        guard typing != isTyping else { return }
        isTyping = typing
        // Leaving the field with the pointer already outside closes the island, as hover-out would have.
        if !typing && isOpen && !isHovering && !assistant.isWorking {
            closeTask = schedule(after: 0.22) { $0.close() }
        }
    }

    /// The island takes the keyboard only while the calendar tab, with its assistant field, is open.
    var acceptsKeyboard: Bool { isOpen && currentTab == .calendar && calendar.access == .signedIn }

    func setChoosingShortcuts(_ choosing: Bool) {
        if choosing { home.refresh() }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { isChoosingShortcuts = choosing }
    }

    func setChoosingOutput(_ choosing: Bool) {
        if choosing { airPods.refresh(for: audio.currentDevice) }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) { isChoosingOutput = choosing }
    }

    func toggle() { isOpen ? close() : open() }

    func selectSettingsSection(_ page: SettingsPage) {
        guard page != islandSettingsSection else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { islandSettingsSection = page }
    }

    /// Opens the settings window, on the given page if there is one.
    func openSettings(_ page: SettingsPage? = nil) {
        if let page { settingsPage = page }
        onOpenSettings?()
    }

    /// Copies an older clipboard item again and, if allowed, pastes it into the app in front.
    func useClipboardItem(_ item: ClipboardItem) {
        clipboard.use(item, paste: settings.pasteFromClipboardHistory)
        close()
    }

    func select(_ tab: IslandTab) {
        if tab == .home { home.refresh() }
        if tab == .calendar { calendar.reload() }
        if tab == .clipboard { shelf.prune() }
        isChoosingShortcuts = false
        guard tab != self.tab else { return }
        // Settings opens on the part you came from.
        if tab == .settings {
            let page = currentTab.settingsPage
            islandSettingsSection = SettingsPage.islandSections.contains(page) ? page : .general
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            self.tab = tab
            isChoosingOutput = false
        }
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
        scheduleWaterReminderDismissal(after: 20)
    }

    private func scheduleWaterReminderDismissal(after seconds: Double) {
        waterReminderTask?.cancel()
        waterReminderTask = schedule(after: seconds) { $0.dismissWaterReminder(drank: false) }
    }

    func dismissWaterReminder(drank: Bool) {
        waterReminderTask?.cancel()
        if drank { water.drink() } else { water.snooze() }
        isShowingWaterReminder = false
    }

    func showScreenshot() {
        guard settings.showScreenshots else { return }
        hasPendingScreenshot = isOpen
        guard !isOpen else { return }
        isPeeking = false
        isShowingScreenshot = true
        scheduleScreenshotDismissal(after: 8)
    }

    func dismissScreenshot() {
        screenshotTask?.cancel()
        isShowingScreenshot = false
    }

    func beginScreenshotDrag() {
        screenshotTask?.cancel()
        isDraggingScreenshot = true
    }

    /// A drop somewhere else is done with the screenshot; a cancelled drag puts it back for a moment.
    func endScreenshotDrag(dropped: Bool) {
        isDraggingScreenshot = false
        if dropped { dismissScreenshot() } else { scheduleScreenshotDismissal(after: 3) }
    }

    private func scheduleScreenshotDismissal(after seconds: Double) {
        screenshotTask?.cancel()
        screenshotTask = schedule(after: seconds) { $0.isShowingScreenshot = false }
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
