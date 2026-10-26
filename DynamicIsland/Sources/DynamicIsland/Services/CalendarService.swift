import AppKit
import EventKit

/// Today's events from the macOS Calendar app, which also holds Google, iCloud and Exchange
/// accounts added under System Settings › Internet Accounts. Fires `onReminder` a set number
/// of minutes before each timed event.
@MainActor @Observable
final class CalendarService {
    struct Event: Identifiable, Equatable {
        let id: String
        let title: String
        let start: Date
        let end: Date
        let location: String?
        let color: NSColor
        /// A Google Meet, Zoom or Teams link found on the event.
        let meetingURL: URL?

        func isHappening(at date: Date) -> Bool { start <= date && date < end }
    }

    enum Access: Equatable {
        case unknown, granted, denied
    }

    private(set) var access: Access = .unknown
    /// Timed events from now until the end of today, or tomorrow's when today is done.
    private(set) var events: [Event] = []
    private(set) var showsTomorrow = false
    /// The event the reminder in the island is about.
    private(set) var reminder: Event?

    var onReminder: ((Event) -> Void)?
    /// Minutes before an event that the reminder appears.
    var leadMinutes: @MainActor () -> Int = { 15 }

    @ObservationIgnored private let store = EKEventStore()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var changeObserver: NSObjectProtocol?
    /// Event and start, so a moved meeting gets a new reminder.
    @ObservationIgnored private var reminded: Set<String> = []

    func start() {
        guard timer == nil else { return }
        updateAccess()
        if access == .granted { reload() }
        changeObserver = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store,
                                                                queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
        // Reloading also drops events that have ended and moves on to tomorrow at midnight.
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let changeObserver { NotificationCenter.default.removeObserver(changeObserver) }
        changeObserver = nil
    }

    func requestAccess() {
        if access == .denied {
            openPrivacySettings()
            return
        }
        Task {
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            access = granted ? .granted : .denied
            if granted { reload() }
        }
    }

    func reload() {
        updateAccess()
        guard access == .granted else {
            if !events.isEmpty { events = [] }
            return
        }
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: today)!

        // Runs every 20 seconds, so only touch the properties when something changed.
        let upcoming = fetch(from: now, to: tomorrow)
        let isTomorrow = upcoming.isEmpty
        let events = isTomorrow ? fetch(from: tomorrow, to: dayAfter) : upcoming
        if events != self.events { self.events = events }
        if isTomorrow != showsTomorrow { showsTomorrow = isTomorrow }
        tick()
    }

    /// Opens the event's meeting link, or the day in Calendar when it has none.
    func join(_ event: Event) {
        if let url = event.meetingURL {
            NSWorkspace.shared.open(url)
        } else {
            openCalendarApp()
        }
        dismissReminder()
    }

    func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func dismissReminder() {
        reminder = nil
    }

    // MARK: Private

    private func updateAccess() {
        let access: Access = switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .unknown
        default: .denied
        }
        if access != self.access { self.access = access }
    }

    private func fetch(from start: Date, to end: Date) -> [Event] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .filter { !$0.isAllDay && $0.status != .canceled && !Self.isDeclined($0) }
            .sorted { $0.compareStartDate(with: $1) == .orderedAscending }
            .map { event in
                let title = event.title ?? ""
                return Event(id: event.calendarItemIdentifier,
                             title: title.isEmpty ? "Untitled" : title,
                             start: event.startDate,
                             end: event.endDate,
                             location: (event.location ?? "").isEmpty ? nil : event.location,
                             color: event.calendar?.color ?? .systemBlue,
                             meetingURL: Self.meetingURL(in: event))
            }
    }

    /// Shows the reminder for the first event that starts within the lead time.
    private func tick() {
        let now = Date()
        let lead = TimeInterval(leadMinutes() * 60)
        guard let event = events.first(where: { $0.start > now && $0.start.timeIntervalSince(now) <= lead }) else { return }
        let key = "\(event.id)@\(event.start.timeIntervalSince1970)"
        guard !reminded.contains(key) else { return }
        reminded.insert(key)
        reminder = event
        onReminder?(event)
    }

    private static func isDeclined(_ event: EKEvent) -> Bool {
        event.attendees?.contains { $0.isCurrentUser && $0.participantStatus == .declined } ?? false
    }

    private static func meetingURL(in event: EKEvent) -> URL? {
        let hosts = ["meet.google.com", "zoom.us", "teams.microsoft.com", "teams.live.com", "facetime.apple.com"]
        func isMeeting(_ url: URL) -> Bool {
            guard let host = url.host?.lowercased() else { return false }
            return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
        }
        if let url = event.url, isMeeting(url) { return url }
        let text = [event.location, event.notes].compactMap { $0 }.joined(separator: "\n")
        guard !text.isEmpty, let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap(\.url)
            .first(where: isMeeting)
    }

    #if DEBUG
    /// Fake events for the snapshot renderer.
    func showPreview(_ events: [Event]) {
        access = .granted
        self.events = events
        showsTomorrow = false
    }

    func showPreviewReminder(_ event: Event) {
        reminder = event
    }
    #endif
}
