import AppKit

/// Today's events from the user's Google Calendar, read with the Google Calendar API after
/// signing in with Google. Fires `onReminder` a set number of minutes before each timed event.
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
        /// The event in Google Calendar.
        var link: URL? = nil
        var calendarID: String = ""

        func isHappening(at date: Date) -> Bool { start <= date && date < end }
    }

    /// One calendar from the account, for picking which ones the island shows.
    struct Source: Identifiable, Equatable {
        let id: String
        let title: String
        let account: String
        let color: NSColor
    }

    enum Access: Equatable {
        case signedOut, signingIn, signedIn
    }

    private(set) var access: Access = .signedOut
    /// The Google account's email.
    private(set) var account: String?
    /// Why the last sign-in or refresh failed.
    private(set) var errorMessage: String?
    /// Timed events from now until the end of today, or tomorrow's when today is done.
    private(set) var events: [Event] = []
    private(set) var showsTomorrow = false
    /// The account's calendars.
    private(set) var sources: [Source] = []
    /// The event the reminder in the island is about.
    private(set) var reminder: Event?

    /// From a "Desktop app" OAuth client in Google Cloud Console.
    var clientID: String {
        didSet { UserDefaults.standard.set(clientID.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.clientID) }
    }
    var clientSecret: String {
        didSet { UserDefaults.standard.set(clientSecret.trimmingCharacters(in: .whitespacesAndNewlines), forKey: Key.clientSecret) }
    }
    var hasClientID: Bool { !credentials.clientID.isEmpty }

    var onReminder: ((Event) -> Void)?
    /// Minutes before an event that the reminder appears.
    var leadMinutes: @MainActor () -> Int = { 15 }
    /// Calendars the user turned off.
    var hiddenCalendars: @MainActor () -> Set<String> = { [] }

    @ObservationIgnored private let auth = GoogleAuth()
    @ObservationIgnored private var timer: Timer?
    /// Every timed event of today and tomorrow, from all calendars.
    @ObservationIgnored private var fetched: [Event] = []
    @ObservationIgnored private var lastFetch = Date.distantPast
    @ObservationIgnored private var fetchTask: Task<Void, Never>?
    @ObservationIgnored private var signInTask: Task<Void, Never>?
    /// Event and start, so a moved meeting gets a new reminder.
    @ObservationIgnored private var reminded: Set<String> = []

    private enum Key {
        static let clientID = "googleClientID"
        static let clientSecret = "googleClientSecret"
    }

    init() {
        clientID = UserDefaults.standard.string(forKey: Key.clientID) ?? ""
        clientSecret = UserDefaults.standard.string(forKey: Key.clientSecret) ?? ""
    }

    private var credentials: GoogleAuth.Credentials {
        .init(clientID: clientID.trimmingCharacters(in: .whitespacesAndNewlines),
              clientSecret: clientSecret.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func start() {
        guard timer == nil else { return }
        if access != .signingIn { access = auth.isSignedIn ? .signedIn : .signedOut }
        account = auth.account
        reload(maxAge: 0)
        // Updating also drops events that have ended and moves on to tomorrow at midnight.
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload(maxAge: 180) }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Opens Google's sign-in page in the browser.
    func signIn() {
        guard hasClientID else {
            errorMessage = "Add your Google client ID under Settings › Calendar first."
            return
        }
        guard access != .signingIn else { return }
        errorMessage = nil
        access = .signingIn
        signInTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await auth.signIn(credentials)
                access = .signedIn
                NSApp.activate()
                reload(maxAge: 0)
            } catch is CancellationError {
                access = .signedOut
            } catch {
                access = .signedOut
                errorMessage = error.localizedDescription
            }
            signInTask = nil
        }
    }

    func cancelSignIn() {
        signInTask?.cancel()
    }

    func signOut() {
        signInTask?.cancel()
        fetchTask?.cancel()
        fetchTask = nil
        auth.signOut()
        access = .signedOut
        account = nil
        errorMessage = nil
        clear()
    }

    /// Shows the cached events right away and fetches new ones when they are older than `maxAge` seconds.
    func reload(maxAge: TimeInterval = 60) {
        guard access == .signedIn else { return }
        update()
        guard fetchTask == nil, Date().timeIntervalSince(lastFetch) >= maxAge else { return }
        fetchTask = Task { [weak self] in
            await self?.fetch()
            self?.fetchTask = nil
        }
    }

    /// Opens the event's meeting link, or the event in Google Calendar when it has none.
    func join(_ event: Event) {
        if let url = event.meetingURL {
            NSWorkspace.shared.open(url)
        } else {
            open(event)
        }
        dismissReminder()
    }

    /// Opens the event in Google Calendar in the browser.
    func open(_ event: Event) {
        if let link = event.link {
            NSWorkspace.shared.open(link)
        } else {
            openCalendar(at: event.start)
        }
    }

    /// Opens Google Calendar in the browser on the day of `date`.
    func openCalendar(at date: Date = Date()) {
        let day = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let path = [day.year, day.month, day.day].compactMap { $0.map(String.init) }.joined(separator: "/")
        if let url = URL(string: "https://calendar.google.com/calendar/r/day/" + path) {
            NSWorkspace.shared.open(url)
        }
    }

    func dismissReminder() {
        reminder = nil
    }

    // MARK: Private

    private func clear() {
        fetched = []
        lastFetch = .distantPast
        if !events.isEmpty { events = [] }
        if !sources.isEmpty { sources = [] }
        reminder = nil
    }

    private func fetch() async {
        let now = Date()
        let today = Calendar.current.startOfDay(for: now)
        let dayAfter = Calendar.current.date(byAdding: .day, value: 2, to: today)!
        do {
            let token = try await auth.validAccessToken(credentials)
            let list: GoogleCalendarList = try await get("users/me/calendarList", [.init(name: "minAccessRole", value: "reader")],
                                                         token: token)
            let calendars = (list.items ?? []).filter { $0.hidden != true && $0.deleted != true }
            let account = calendars.first(where: { $0.primary == true })?.id ?? auth.account
            auth.setAccount(account)

            var events: [Event] = []
            for calendar in calendars {
                let color = calendar.backgroundColor.flatMap(NSColor.init(hex:)) ?? .systemBlue
                let path = "calendars/\(Self.pathEncoded(calendar.id))/events"
                let query: [URLQueryItem] = [
                    .init(name: "timeMin", value: Self.queryDate(today)),
                    .init(name: "timeMax", value: Self.queryDate(dayAfter)),
                    .init(name: "singleEvents", value: "true"),
                    .init(name: "orderBy", value: "startTime"),
                    .init(name: "maxResults", value: "100"),
                ]
                // One calendar that fails, like a broken subscription, shouldn't hide the rest.
                guard let page: GoogleEventList = try? await get(path, query, token: token) else { continue }
                events += (page.items ?? []).compactMap { Self.event(from: $0, calendarID: calendar.id, color: color) }
            }
            guard !Task.isCancelled, access == .signedIn else { return }

            let sources = calendars
                .sorted { ($0.primary == true ? 0 : 1, $0.title) < ($1.primary == true ? 0 : 1, $1.title) }
                .map { Source(id: $0.id, title: $0.title, account: account ?? "Google",
                              color: $0.backgroundColor.flatMap(NSColor.init(hex:)) ?? .systemBlue) }
            if sources != self.sources { self.sources = sources }
            if account != self.account { self.account = account }
            fetched = events.sorted { $0.start < $1.start }
            lastFetch = Date()
            if errorMessage != nil { errorMessage = nil }
            update()
        } catch GoogleAuth.AuthError.signedOut {
            access = .signedOut
            account = nil
            errorMessage = GoogleAuth.AuthError.signedOut.localizedDescription
            clear()
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            // Try again in about a minute.
            lastFetch = Date().addingTimeInterval(-120)
        }
    }

    private func get<T: Decodable>(_ path: String, _ query: [URLQueryItem], token: String) async throws -> T {
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/")!
        components.percentEncodedPath += path
        components.queryItems = query
        guard let url = components.url else { throw GoogleAuth.AuthError.badResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            if status == 401 { auth.invalidateAccessToken() }
            let message = (try? JSONDecoder().decode(GoogleErrorResponse.self, from: data))?.error.message
            throw GoogleAuth.AuthError.google("HTTP \(status)", message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Picks today's remaining events, or tomorrow's, from what was fetched.
    private func update() {
        let hidden = hiddenCalendars()
        let shown = fetched.filter { !hidden.contains($0.calendarID) }
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let dayAfter = calendar.date(byAdding: .day, value: 2, to: today)!

        // Runs every 20 seconds, so only touch the properties when something changed.
        let upcoming = shown.filter { $0.end > now && $0.start < tomorrow }
        let isTomorrow = upcoming.isEmpty
        let events = isTomorrow ? shown.filter { $0.end > tomorrow && $0.start < dayAfter } : upcoming
        if events != self.events { self.events = events }
        if isTomorrow != showsTomorrow { showsTomorrow = isTomorrow }
        tick()
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

    private static func event(from item: GoogleEvent, calendarID: String, color: NSColor) -> Event? {
        // All-day events have a date and no time; the island only lists timed ones.
        guard item.status != "cancelled", item.eventType != "workingLocation",
              let start = item.start?.dateTime.flatMap(parseDate),
              let end = item.end?.dateTime.flatMap(parseDate),
              !(item.attendees ?? []).contains(where: { $0.isSelf == true && $0.responseStatus == "declined" })
        else { return nil }
        let title = item.summary ?? ""
        let location = item.location ?? ""
        return Event(id: calendarID + "/" + (item.id ?? UUID().uuidString),
                     title: title.isEmpty ? "Untitled" : title,
                     start: start,
                     end: end,
                     location: location.isEmpty ? nil : location,
                     color: color,
                     meetingURL: meetingURL(in: item),
                     link: item.htmlLink.flatMap(URL.init(string:)),
                     calendarID: calendarID)
    }

    private static func meetingURL(in event: GoogleEvent) -> URL? {
        let hosts = ["meet.google.com", "zoom.us", "teams.microsoft.com", "teams.live.com", "facetime.apple.com"]
        func isMeeting(_ url: URL) -> Bool {
            guard let host = url.host?.lowercased() else { return false }
            return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
        }
        if let video = event.conferenceData?.entryPoints?.first(where: { $0.entryPointType == "video" })?.uri,
           let url = URL(string: video) {
            return url
        }
        if let link = event.hangoutLink.flatMap(URL.init(string:)) { return link }
        let text = [event.location, event.description].compactMap { $0 }.joined(separator: "\n")
        guard !text.isEmpty, let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        return detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap(\.url)
            .first(where: isMeeting)
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)
    }

    /// In UTC, so there is no "+" for the query to mangle.
    private static func queryDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func pathEncoded(_ id: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~@")
        return id.addingPercentEncoding(withAllowedCharacters: allowed) ?? id
    }

    #if DEBUG
    /// Fake events for the snapshot renderer.
    func showPreview(_ events: [Event]) {
        access = .signedIn
        self.events = events
        showsTomorrow = false
    }

    func showPreviewReminder(_ event: Event) {
        reminder = event
    }
    #endif
}

// MARK: - Google Calendar API

private struct GoogleCalendarList: Decodable {
    struct Item: Decodable {
        let id: String
        let summary: String?
        let summaryOverride: String?
        let backgroundColor: String?
        let primary: Bool?
        let hidden: Bool?
        let deleted: Bool?

        var title: String { summaryOverride ?? summary ?? id }
    }

    let items: [Item]?
}

private struct GoogleEventList: Decodable {
    let items: [GoogleEvent]?
}

private struct GoogleEvent: Decodable {
    struct Time: Decodable {
        let dateTime: String?
        let date: String?
    }

    struct Attendee: Decodable {
        let isSelf: Bool?
        let responseStatus: String?

        enum CodingKeys: String, CodingKey {
            case isSelf = "self"
            case responseStatus
        }
    }

    struct Conference: Decodable {
        struct EntryPoint: Decodable {
            let entryPointType: String?
            let uri: String?
        }

        let entryPoints: [EntryPoint]?
    }

    let id: String?
    let summary: String?
    let status: String?
    let eventType: String?
    let location: String?
    let description: String?
    let htmlLink: String?
    let hangoutLink: String?
    let start: Time?
    let end: Time?
    let attendees: [Attendee]?
    let conferenceData: Conference?
}

private struct GoogleErrorResponse: Decodable {
    struct Body: Decodable {
        let message: String?
    }

    let error: Body
}
