import Foundation

@MainActor @Observable
final class AppSettings {
    var hoverToOpen: Bool { didSet { store(hoverToOpen, Key.hoverToOpen) } }
    var hapticFeedback: Bool { didSet { store(hapticFeedback, Key.hapticFeedback) } }
    var showLiveActivity: Bool { didSet { store(showLiveActivity, Key.showLiveActivity) } }
    var showTrackChanges: Bool { didSet { store(showTrackChanges, Key.showTrackChanges) } }
    var showVolumeHUD: Bool { didSet { store(showVolumeHUD, Key.showVolumeHUD) } }
    var showDeviceChanges: Bool { didSet { store(showDeviceChanges, Key.showDeviceChanges) } }
    var showHomeTab: Bool { didSet { store(showHomeTab, Key.showHomeTab) } }
    var showPostureTab: Bool { didSet { store(showPostureTab, Key.showPostureTab) } }
    var showPostureAlerts: Bool { didSet { store(showPostureAlerts, Key.showPostureAlerts) } }
    var showPostureLiveActivity: Bool { didSet { store(showPostureLiveActivity, Key.showPostureLiveActivity) } }
    /// Run the Posture app that comes with the island.
    var runPosture: Bool { didSet { store(runPosture, Key.runPosture) } }
    /// Run the Unknot app that comes with the island.
    var runUnknot: Bool { didSet { store(runUnknot, Key.runUnknot) } }
    var showCalendarTab: Bool { didSet { store(showCalendarTab, Key.showCalendarTab) } }
    var showCalendarReminders: Bool { didSet { store(showCalendarReminders, Key.showCalendarReminders) } }
    var showShelfTab: Bool { didSet { store(showShelfTab, Key.showShelfTab) } }
    var showClipboardTab: Bool { didSet { store(showClipboardTab, Key.showClipboardTab) } }
    var showSystemTab: Bool { didSet { store(showSystemTab, Key.showSystemTab) } }
    /// Picking an item from the clipboard history also pastes it, not just copies it.
    var pasteFromClipboardHistory: Bool { didSet { store(pasteFromClipboardHistory, Key.pasteFromClipboardHistory) } }
    var showScreenshots: Bool { didSet { store(showScreenshots, Key.showScreenshots) } }
    /// Minutes before an event that its reminder appears.
    var calendarLeadMinutes: Int { didSet { defaults.set(calendarLeadMinutes, forKey: Key.calendarLeadMinutes) } }
    /// Identifiers of the calendars the island leaves out.
    var hiddenCalendarIDs: Set<String> {
        didSet { defaults.set(Array(hiddenCalendarIDs), forKey: Key.hiddenCalendarIDs) }
    }
    var showWaterReminders: Bool { didSet { store(showWaterReminders, Key.showWaterReminders) } }
    /// Minutes at the Mac between water reminders.
    var waterIntervalMinutes: Int { didSet { defaults.set(waterIntervalMinutes, forKey: Key.waterIntervalMinutes) } }
    var waterDailyGoal: Int { didSet { defaults.set(waterDailyGoal, forKey: Key.waterDailyGoal) } }
    var showWaterTab: Bool { didSet { store(showWaterTab, Key.showWaterTab) } }
    /// Millilitres in one glass, to show the day's total.
    var waterGlassSize: Int { didSet { defaults.set(waterGlassSize, forKey: Key.waterGlassSize) } }
    /// The welcome window has been shown and closed once.
    var hasSeenWelcome: Bool { didSet { store(hasSeenWelcome, Key.hasSeenWelcome) } }
    var homeFolderName: String { didSet { defaults.set(homeFolderName, forKey: Key.homeFolderName) } }
    var replaceSystemHUD: Bool {
        didSet {
            store(replaceSystemHUD, Key.replaceSystemHUD)
            onReplaceSystemHUDChange?()
        }
    }

    @ObservationIgnored var onReplaceSystemHUDChange: (() -> Void)?

    private enum Key {
        static let hoverToOpen = "hoverToOpen"
        static let hasSeenWelcome = "hasSeenWelcome"
        static let hapticFeedback = "hapticFeedback"
        static let showLiveActivity = "showLiveActivity"
        static let showTrackChanges = "showTrackChanges"
        static let showVolumeHUD = "showVolumeHUD"
        static let showDeviceChanges = "showDeviceChanges"
        static let replaceSystemHUD = "replaceSystemHUD"
        static let showHomeTab = "showHomeTab"
        static let homeFolderName = "homeFolderName"
        static let showPostureTab = "showPostureTab"
        static let showPostureAlerts = "showPostureAlerts"
        static let showPostureLiveActivity = "showPostureLiveActivity"
        static let runPosture = "runPosture"
        static let runUnknot = "runUnknot"
        static let showCalendarTab = "showCalendarTab"
        static let showCalendarReminders = "showCalendarReminders"
        static let showScreenshots = "showScreenshots"
        static let calendarLeadMinutes = "calendarLeadMinutes"
        static let hiddenCalendarIDs = "hiddenCalendarIDs"
        static let showShelfTab = "showShelfTab"
        static let showWaterReminders = "showWaterReminders"
        static let waterIntervalMinutes = "waterIntervalMinutes"
        static let waterDailyGoal = "waterDailyGoal"
        static let showWaterTab = "showWaterTab"
        static let waterGlassSize = "waterGlassSize"
        static let showClipboardTab = "showClipboardTab"
        static let showSystemTab = "showSystemTab"
        static let pasteFromClipboardHistory = "pasteFromClipboardHistory"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Tests pass their own suite, so they never touch the real settings.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.hoverToOpen: true,
            Key.hasSeenWelcome: false,
            Key.hapticFeedback: true,
            Key.showLiveActivity: true,
            Key.showTrackChanges: true,
            Key.showVolumeHUD: true,
            Key.showDeviceChanges: true,
            Key.replaceSystemHUD: false,
            Key.showHomeTab: true,
            Key.homeFolderName: "Home",
            Key.showPostureTab: true,
            Key.showPostureAlerts: true,
            Key.showPostureLiveActivity: true,
            Key.runPosture: true,
            Key.runUnknot: true,
            Key.showCalendarTab: true,
            Key.showCalendarReminders: true,
            Key.showScreenshots: true,
            Key.calendarLeadMinutes: 15,
            Key.showShelfTab: true,
            Key.showWaterReminders: true,
            Key.waterIntervalMinutes: 45,
            Key.waterDailyGoal: 8,
            Key.showWaterTab: true,
            Key.waterGlassSize: 250,
            Key.showClipboardTab: true,
            Key.showSystemTab: true,
            Key.pasteFromClipboardHistory: true,
        ])
        hoverToOpen = defaults.bool(forKey: Key.hoverToOpen)
        hasSeenWelcome = defaults.bool(forKey: Key.hasSeenWelcome)
        hapticFeedback = defaults.bool(forKey: Key.hapticFeedback)
        showLiveActivity = defaults.bool(forKey: Key.showLiveActivity)
        showTrackChanges = defaults.bool(forKey: Key.showTrackChanges)
        showVolumeHUD = defaults.bool(forKey: Key.showVolumeHUD)
        showDeviceChanges = defaults.bool(forKey: Key.showDeviceChanges)
        replaceSystemHUD = defaults.bool(forKey: Key.replaceSystemHUD)
        showHomeTab = defaults.bool(forKey: Key.showHomeTab)
        showPostureTab = defaults.bool(forKey: Key.showPostureTab)
        showPostureAlerts = defaults.bool(forKey: Key.showPostureAlerts)
        showPostureLiveActivity = defaults.bool(forKey: Key.showPostureLiveActivity)
        runPosture = defaults.bool(forKey: Key.runPosture)
        runUnknot = defaults.bool(forKey: Key.runUnknot)
        showCalendarTab = defaults.bool(forKey: Key.showCalendarTab)
        showCalendarReminders = defaults.bool(forKey: Key.showCalendarReminders)
        showShelfTab = defaults.bool(forKey: Key.showShelfTab)
        showScreenshots = defaults.bool(forKey: Key.showScreenshots)
        calendarLeadMinutes = defaults.integer(forKey: Key.calendarLeadMinutes)
        showClipboardTab = defaults.bool(forKey: Key.showClipboardTab)
        showSystemTab = defaults.bool(forKey: Key.showSystemTab)
        pasteFromClipboardHistory = defaults.bool(forKey: Key.pasteFromClipboardHistory)
        hiddenCalendarIDs = Set(defaults.stringArray(forKey: Key.hiddenCalendarIDs) ?? [])
        showWaterReminders = defaults.bool(forKey: Key.showWaterReminders)
        waterIntervalMinutes = defaults.integer(forKey: Key.waterIntervalMinutes)
        waterDailyGoal = defaults.integer(forKey: Key.waterDailyGoal)
        showWaterTab = defaults.bool(forKey: Key.showWaterTab)
        waterGlassSize = defaults.integer(forKey: Key.waterGlassSize)
        homeFolderName = defaults.string(forKey: Key.homeFolderName) ?? "Home"
    }

    private func store(_ value: Bool, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
