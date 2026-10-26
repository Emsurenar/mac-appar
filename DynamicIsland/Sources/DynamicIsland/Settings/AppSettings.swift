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
    var showCalendarTab: Bool { didSet { store(showCalendarTab, Key.showCalendarTab) } }
    var showCalendarReminders: Bool { didSet { store(showCalendarReminders, Key.showCalendarReminders) } }
    /// Minutes before an event that its reminder appears.
    var calendarLeadMinutes: Int { didSet { defaults.set(calendarLeadMinutes, forKey: Key.calendarLeadMinutes) } }
    /// Identifiers of the calendars the island leaves out.
    var hiddenCalendarIDs: Set<String> {
        didSet { defaults.set(Array(hiddenCalendarIDs), forKey: Key.hiddenCalendarIDs) }
    }
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
        static let showCalendarTab = "showCalendarTab"
        static let showCalendarReminders = "showCalendarReminders"
        static let calendarLeadMinutes = "calendarLeadMinutes"
        static let hiddenCalendarIDs = "hiddenCalendarIDs"
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            Key.hoverToOpen: true,
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
            Key.showCalendarTab: true,
            Key.showCalendarReminders: true,
            Key.calendarLeadMinutes: 15,
        ])
        hoverToOpen = defaults.bool(forKey: Key.hoverToOpen)
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
        showCalendarTab = defaults.bool(forKey: Key.showCalendarTab)
        showCalendarReminders = defaults.bool(forKey: Key.showCalendarReminders)
        calendarLeadMinutes = defaults.integer(forKey: Key.calendarLeadMinutes)
        hiddenCalendarIDs = Set(defaults.stringArray(forKey: Key.hiddenCalendarIDs) ?? [])
        homeFolderName = defaults.string(forKey: Key.homeFolderName) ?? "Home"
    }

    private func store(_ value: Bool, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
