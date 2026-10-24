import AppKit
@preconcurrency import UserNotifications

/// Posture reminders through Notification Center, with "Pausa 30 min" and "Fel – jag satt bra".
final class NotificationService: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    enum Action {
        case pause, falseAlarm, open
    }

    static let category = "posture-alert"
    private static let pauseAction = "pause30"
    private static let falseAlarmAction = "falseAlarm"

    /// Called on the main actor.
    var onAction: (@MainActor (Action) -> Void)?

    private var center: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    func configure() {
        center.delegate = self
        let pause = UNNotificationAction(identifier: Self.pauseAction, title: "Pausa 30 min", options: [])
        let falseAlarm = UNNotificationAction(identifier: Self.falseAlarmAction, title: "Fel – jag satt bra", options: [])
        let category = UNNotificationCategory(identifier: Self.category, actions: [pause, falseAlarm],
                                              intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func postAlert(issue: PostureIssue, minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = issue.title
        content.body = "Du har suttit med dålig hållning i \(minutes) \(minutes == 1 ? "minut" : "minuter"). " + issue.advice
        content.sound = .default
        content.categoryIdentifier = Self.category
        content.threadIdentifier = Self.category
        let request = UNNotificationRequest(identifier: "posture-\(UUID().uuidString)", content: content, trigger: nil)
        center.add(request)
    }

    /// The gentle sound used when the reminder only shows in the island.
    func playSoftSound() {
        (NSSound(named: NSSound.Name("Tink")) ?? NSSound(named: NSSound.Name("Pop")))?.play()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let action: Action? = switch response.actionIdentifier {
        case Self.pauseAction: .pause
        case Self.falseAlarmAction: .falseAlarm
        case UNNotificationDefaultActionIdentifier: .open
        default: nil
        }
        let handler = onAction
        if let action, let handler {
            DispatchQueue.main.async { MainActor.assumeIsolated { handler(action) } }
        }
        completionHandler()
    }
}
