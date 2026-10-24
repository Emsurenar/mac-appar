import Foundation

enum Sensitivity: String, CaseIterable, Identifiable {
    case low, normal, high

    var id: String { rawValue }

    /// P(bad) at or above which a check counts as bad.
    var threshold: Double {
        switch self {
        case .low: 0.65
        case .normal: 0.5
        case .high: 0.35
        }
    }

    var title: String {
        switch self {
        case .low: "Låg"
        case .normal: "Normal"
        case .high: "Hög"
        }
    }
}

enum AlertStyle: String, CaseIterable, Identifiable {
    case islandFirst, both, notificationOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .islandFirst: "Dynamic Island, annars notis"
        case .both: "Båda"
        case .notificationOnly: "Endast notis"
        }
    }
}

@MainActor @Observable
final class PostureSettings {
    /// Seconds between checks.
    var interval: Double { didSet { defaults.set(interval, forKey: Key.interval); onTimingChange?() } }
    /// Minutes of bad posture before a reminder.
    var alertMinutes: Double { didSet { defaults.set(alertMinutes, forKey: Key.alertMinutes) } }
    /// Fraction of bad checks in the window that triggers a reminder.
    var alertThreshold: Double { didSet { defaults.set(alertThreshold, forKey: Key.alertThreshold) } }
    var sensitivity: Sensitivity { didSet { defaults.set(sensitivity.rawValue, forKey: Key.sensitivity) } }
    var alertStyle: AlertStyle { didSet { defaults.set(alertStyle.rawValue, forKey: Key.alertStyle) } }
    var playSound: Bool { didSet { store(playSound, Key.playSound) } }
    var cameraID: String? { didSet { defaults.set(cameraID, forKey: Key.cameraID); onCameraChange?() } }
    var pauseDuringCalls: Bool { didSet { store(pauseDuringCalls, Key.pauseDuringCalls) } }
    var useAirPods: Bool { didSet { store(useAirPods, Key.useAirPods); onAirPodsChange?() } }
    /// Degrees down from neutral that the AirPods still count as a good head position.
    var maxNeckAngle: Double { didSet { defaults.set(maxNeckAngle, forKey: Key.maxNeckAngle) } }
    /// Minutes with the neck bent past `maxNeckAngle` before a reminder.
    var neckAlertMinutes: Double { didSet { defaults.set(neckAlertMinutes, forKey: Key.neckAlertMinutes) } }
    /// AirPods pitch (degrees) with the head held straight; nil uses the calibration.
    var neckNeutralPitch: Double? { didSet { defaults.set(neckNeutralPitch, forKey: Key.neckNeutralPitch) } }
    var showLiveCamera: Bool { didSet { store(showLiveCamera, Key.showLiveCamera) } }

    @ObservationIgnored var onTimingChange: (() -> Void)?
    @ObservationIgnored var onCameraChange: (() -> Void)?
    @ObservationIgnored var onAirPodsChange: (() -> Void)?

    private enum Key {
        static let interval = "interval"
        static let alertMinutes = "alertMinutes"
        static let alertThreshold = "alertThreshold"
        static let sensitivity = "sensitivity"
        static let alertStyle = "alertStyle"
        static let playSound = "playSound"
        static let cameraID = "cameraID"
        static let pauseDuringCalls = "pauseDuringCalls"
        static let useAirPods = "useAirPods"
        static let maxNeckAngle = "maxNeckAngle"
        static let neckAlertMinutes = "neckAlertMinutes"
        static let neckNeutralPitch = "neckNeutralPitch"
        static let showLiveCamera = "showLiveCamera"
    }

    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        defaults.register(defaults: [
            Key.interval: 10.0,
            Key.alertMinutes: 3.0,
            Key.alertThreshold: 0.9,
            Key.sensitivity: Sensitivity.normal.rawValue,
            Key.alertStyle: AlertStyle.islandFirst.rawValue,
            Key.playSound: true,
            Key.pauseDuringCalls: true,
            Key.useAirPods: true,
            Key.maxNeckAngle: 15.0,
            Key.neckAlertMinutes: 2.0,
            Key.showLiveCamera: false,
        ])
        interval = defaults.double(forKey: Key.interval)
        alertMinutes = defaults.double(forKey: Key.alertMinutes)
        alertThreshold = defaults.double(forKey: Key.alertThreshold)
        sensitivity = Sensitivity(rawValue: defaults.string(forKey: Key.sensitivity) ?? "") ?? .normal
        alertStyle = AlertStyle(rawValue: defaults.string(forKey: Key.alertStyle) ?? "") ?? .islandFirst
        playSound = defaults.bool(forKey: Key.playSound)
        cameraID = defaults.string(forKey: Key.cameraID)
        pauseDuringCalls = defaults.bool(forKey: Key.pauseDuringCalls)
        useAirPods = defaults.bool(forKey: Key.useAirPods)
        maxNeckAngle = defaults.double(forKey: Key.maxNeckAngle)
        neckAlertMinutes = defaults.double(forKey: Key.neckAlertMinutes)
        neckNeutralPitch = defaults.object(forKey: Key.neckNeutralPitch) as? Double
        showLiveCamera = defaults.bool(forKey: Key.showLiveCamera)
    }

    var alertDuration: TimeInterval { alertMinutes * 60 }
    var neckAlertDuration: TimeInterval { neckAlertMinutes * 60 }

    private func store(_ value: Bool, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
