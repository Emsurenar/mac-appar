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
            Key.homeFolderName: "Hem",
        ])
        hoverToOpen = defaults.bool(forKey: Key.hoverToOpen)
        hapticFeedback = defaults.bool(forKey: Key.hapticFeedback)
        showLiveActivity = defaults.bool(forKey: Key.showLiveActivity)
        showTrackChanges = defaults.bool(forKey: Key.showTrackChanges)
        showVolumeHUD = defaults.bool(forKey: Key.showVolumeHUD)
        showDeviceChanges = defaults.bool(forKey: Key.showDeviceChanges)
        replaceSystemHUD = defaults.bool(forKey: Key.replaceSystemHUD)
        showHomeTab = defaults.bool(forKey: Key.showHomeTab)
        homeFolderName = defaults.string(forKey: Key.homeFolderName) ?? "Hem"
    }

    private func store(_ value: Bool, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
