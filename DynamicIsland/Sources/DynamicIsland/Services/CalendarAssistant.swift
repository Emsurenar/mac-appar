import Foundation

/// Answers questions about the calendar and adds, moves and removes events, from a line typed in
/// the calendar tab ("Lägg till möte med Ruben imorgon kl 17", "When did I last see Sara?").
/// Gemini or Claude does the understanding with tool use; the tools run here against the
/// Google Calendar API as the signed-in user.
@MainActor @Observable
final class CalendarAssistant {
    enum Provider: String, CaseIterable, Identifiable {
        case gemini, claude
        var id: Self { self }
        var name: String { self == .gemini ? "Gemini" : "Claude" }
    }

    private(set) var isWorking = false
    /// The last answer, shown under the field.
    private(set) var reply: String?
    private(set) var errorMessage: String?
    /// What the user asked, shown above the answer.
    private(set) var question: String?

    var provider: Provider {
        didSet {
            UserDefaults.standard.set(provider.rawValue, forKey: "assistantProvider")
            clear()
        }
    }
    /// From Google AI Studio, kept in a file only this user can read.
    var geminiKey: String {
        didSet { Self.saveKey(geminiKey.trimmingCharacters(in: .whitespacesAndNewlines), file: "gemini-api-key") }
    }
    /// From console.anthropic.com, kept in a file only this user can read.
    var claudeKey: String {
        didSet { Self.saveKey(claudeKey.trimmingCharacters(in: .whitespacesAndNewlines), file: "claude-api-key") }
    }

    private var key: String {
        (provider == .gemini ? geminiKey : claudeKey).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    var hasAPIKey: Bool { !key.isEmpty }

    @ObservationIgnored private let calendar: CalendarService
    /// The conversation, sent back as is (thinking and thought signatures included), so follow-ups
    /// ("make it 18 instead") work. One shape per provider.
    @ObservationIgnored private var messages: [[String: Any]] = []
    @ObservationIgnored private var contents: [[String: Any]] = []
    @ObservationIgnored private var lastActivity = Date.distantPast
    @ObservationIgnored private var task: Task<Void, Never>?
    /// The first Gemini model that answers, from newest alias to a fixed version.
    @ObservationIgnored private var geminiModels = ["gemini-pro-latest", "gemini-flash-latest", "gemini-2.5-pro"]

    static let claudeModel = "claude-opus-5-5"

    init(calendar: CalendarService) {
        self.calendar = calendar
        geminiKey = Self.loadKey(file: "gemini-api-key")
        claudeKey = Self.loadKey(file: "claude-api-key")
        let saved = UserDefaults.standard.string(forKey: "assistantProvider").flatMap(Provider.init(rawValue:))
        // Without a choice, whichever has a key, Gemini first.
        provider = saved ?? (Self.loadKey(file: "claude-api-key").isEmpty || !Self.loadKey(file: "gemini-api-key").isEmpty
                             ? .gemini : .claude)
    }

    func ask(_ text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isWorking else { return }
        guard hasAPIKey else {
            errorMessage = "Add a \(provider.name) API key under Settings › Calendar."
            return
        }
        // A new topic after a pause starts a new conversation.
        if Date().timeIntervalSince(lastActivity) > 10 * 60 {
            messages = []
            contents = []
        }
        question = text
        reply = nil
        errorMessage = nil
        isWorking = true
        switch provider {
        case .claude: messages.append(["role": "user", "content": text])
        case .gemini: contents.append(["role": "user", "parts": [["text": text]]])
        }
        let provider = provider
        task = Task { [weak self] in
            switch provider {
            case .claude: await self?.runClaude()
            case .gemini: await self?.runGemini()
            }
            self?.isWorking = false
            self?.lastActivity = Date()
        }
    }

    func cancel() {
        task?.cancel()
    }

    /// Clears the answer and starts the next question fresh.
    func clear() {
        task?.cancel()
        messages = []
        contents = []
        reply = nil
        errorMessage = nil
        question = nil
    }

    // MARK: Claude

    private func runClaude() async {
        do {
            for _ in 0..<10 {
                try Task.checkCancellation()
                let response = try await send()
                let content = response["content"] as? [[String: Any]] ?? []
                let stopReason = response["stop_reason"] as? String
                if stopReason == "refusal" {
                    // Start the next question fresh.
                    messages = []
                    errorMessage = "Claude can't help with that one."
                    return
                }
                // Sent back unchanged, thinking blocks included.
                messages.append(["role": "assistant", "content": content])
                let toolUses = content.filter { $0["type"] as? String == "tool_use" }
                if stopReason == "tool_use", !toolUses.isEmpty {
                    var results: [[String: Any]] = []
                    for use in toolUses {
                        let id = use["id"] as? String ?? ""
                        let name = use["name"] as? String ?? ""
                        let input = use["input"] as? [String: Any] ?? [:]
                        do {
                            let output = try await runTool(name, input)
                            results.append(["type": "tool_result", "tool_use_id": id, "content": output])
                        } catch {
                            results.append(["type": "tool_result", "tool_use_id": id, "is_error": true,
                                            "content": error.localizedDescription])
                        }
                    }
                    messages.append(["role": "user", "content": results])
                    continue
                }
                let text = content.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
                    .joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                reply = text.isEmpty ? "Done." : text
                return
            }
            errorMessage = "That took too many steps. Try asking more simply."
        } catch is CancellationError {
            messages = []
        } catch {
            errorMessage = error.localizedDescription
            // A half-finished tool exchange can't be continued.
            messages = []
        }
    }

    private struct APIError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private func send() async throws -> [String: Any] {
        let body: [String: Any] = [
            "model": Self.claudeModel,
            "max_tokens": 16000,
            "thinking": ["type": "adaptive"],
            "output_config": ["effort": "medium"],
            "fallbacks": "default",
            "system": systemPrompt(),
            "tools": Self.tools,
            "messages": messages,
        ]
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard (200..<300).contains(status) else {
            let message = (json["error"] as? [String: Any])?["message"] as? String
            switch status {
            case 401: throw APIError(message: "The Claude API key doesn't work. Check it under Settings › Calendar.")
            case 429, 529: throw APIError(message: "Claude is busy right now. Try again in a moment.")
            default: throw APIError(message: message ?? "Claude answered with HTTP \(status).")
            }
        }
        return json
    }

    // MARK: Gemini

    private func runGemini() async {
        do {
            for _ in 0..<10 {
                try Task.checkCancellation()
                let response = try await sendGemini()
                guard let candidate = (response["candidates"] as? [[String: Any]])?.first,
                      let content = candidate["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]], !parts.isEmpty else {
                    contents = []
                    let candidate = (response["candidates"] as? [[String: Any]])?.first
                    let reason = candidate?["finishReason"] as? String
                        ?? (response["promptFeedback"] as? [String: Any])?["blockReason"] as? String
                    errorMessage = "Gemini gave no answer\(reason.map { " (\($0))" } ?? ""). Try saying it another way."
                    return
                }
                // Sent back unchanged, thought signatures included.
                contents.append(["role": "model", "parts": parts])
                let calls = parts.compactMap { $0["functionCall"] as? [String: Any] }
                if !calls.isEmpty {
                    var responses: [[String: Any]] = []
                    for call in calls {
                        let name = call["name"] as? String ?? ""
                        var result: [String: Any] = ["name": name]
                        if let id = call["id"] { result["id"] = id }
                        do {
                            let output = try await runTool(name, call["args"] as? [String: Any] ?? [:])
                            let parsed = try? JSONSerialization.jsonObject(with: Data(output.utf8))
                            result["response"] = ["result": parsed ?? output]
                        } catch {
                            result["response"] = ["error": error.localizedDescription]
                        }
                        responses.append(["functionResponse": result])
                    }
                    contents.append(["role": "user", "parts": responses])
                    continue
                }
                let text = parts.filter { $0["thought"] as? Bool != true }
                    .compactMap { $0["text"] as? String }
                    .joined().trimmingCharacters(in: .whitespacesAndNewlines)
                reply = text.isEmpty ? "Done." : text
                return
            }
            errorMessage = "That took too many steps. Try asking more simply."
        } catch is CancellationError {
            contents = []
        } catch {
            errorMessage = error.localizedDescription
            contents = []
        }
    }

    private func sendGemini() async throws -> [String: Any] {
        let declarations = Self.tools.map { tool -> [String: Any] in
            var declaration: [String: Any] = ["name": tool["name"] ?? "", "description": tool["description"] ?? ""]
            if let schema = tool["input_schema"] as? [String: Any],
               let properties = schema["properties"] as? [String: Any], !properties.isEmpty {
                declaration["parameters"] = schema
            }
            return declaration
        }
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": systemPrompt()]]],
            "contents": contents,
            "tools": [["functionDeclarations": declarations]],
        ]
        let data = try JSONSerialization.data(withJSONObject: body)
        while let model = geminiModels.first {
            var request = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!)
            request.httpMethod = "POST"
            request.timeoutInterval = 120
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            request.httpBody = data
            let (responseData, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let json = (try? JSONSerialization.jsonObject(with: responseData)) as? [String: Any] ?? [:]
            if (200..<300).contains(status) { return json }
            let error = json["error"] as? [String: Any]
            let message = error?["message"] as? String
            // This alias isn't served (any more): try the next model.
            if status == 404 && geminiModels.count > 1 {
                geminiModels.removeFirst()
                continue
            }
            switch status {
            case 400 where (message ?? "").localizedCaseInsensitiveContains("API key"):
                throw APIError(message: "The Gemini API key doesn't work. Check it under Settings › Calendar.")
            case 429:
                throw APIError(message: "Gemini's quota is used up for now. Turn on billing for the key's project, or try again in a minute.")
            case 500...599:
                throw APIError(message: "Gemini is busy right now. Try again in a moment.")
            default:
                throw APIError(message: message ?? "Gemini answered with HTTP \(status).")
            }
        }
        throw APIError(message: "No Gemini model answered.")
    }

    private func systemPrompt() -> String {
        let now = Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE yyyy-MM-dd HH:mm xxx"
        let account = calendar.account.map { " The user's Google account is \($0)." } ?? ""
        return """
        You are the calendar assistant inside Dynamic Island, a small panel in the MacBook's notch. \
        The user types one line: a question about their Google Calendar or something to add, move, change or remove. \
        Use the tools to look things up and make the change, then answer.

        Now: \(formatter.string(from: now)), time zone \(TimeZone.current.identifier).\(account)

        How to work:
        - Resolve relative dates ("imorgon", "on Friday", "next week") from now, in the user's time zone. \
        Give times to the tools as RFC 3339 with the offset.
        - A new event without an end lasts one hour. Name it the way the user said it, e.g. "Möte med Ruben". \
        Add it to the primary calendar unless the user names another.
        - Before changing or removing an event, find it with search_events. If several events could be the one meant, \
        don't guess: list them briefly and ask which. If none matches, say so.
        - For "when did I last meet / see X", search the past (time_max = now, newest first, about three years back) \
        with X's name, which matches titles, descriptions, locations and attendees. Then try without the query \
        if the name could be spelled differently. Answer with the date and the event.
        - Only remove what the user clearly asked to remove.

        How to answer:
        - In the user's language (often Swedish), in one to three short sentences of plain text. No Markdown, no lists \
        with symbols. The panel is small.
        - After a change, say what you did with the day and time, e.g. "Lagt till Möte med Ruben imorgon fredag 17–18."
        """
    }

    // MARK: Tools

    private static let tools: [[String: Any]] = [
        [
            "name": "search_events",
            "description": "Finds events in the user's calendars between two times, optionally matching free text "
                + "(title, description, location, attendee names and emails). Returns at most 40 events with their "
                + "calendar_id and event_id, oldest first unless newest_first is true. Use it for questions about the "
                + "schedule and to find an event before updating or deleting it.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "time_min": ["type": "string", "description": "Start of the range, RFC 3339 with offset."],
                    "time_max": ["type": "string", "description": "End of the range, RFC 3339 with offset."],
                    "query": ["type": "string", "description": "Optional free text to match, like a name."],
                    "newest_first": ["type": "boolean", "description": "Return the latest events first."],
                    "calendar_id": ["type": "string", "description": "Only this calendar. Default: all calendars."],
                ],
                "required": ["time_min", "time_max"],
            ],
        ],
        [
            "name": "create_event",
            "description": "Adds an event to the user's calendar and returns it.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "title": ["type": "string"],
                    "start": ["type": "string", "description": "RFC 3339 with offset, or YYYY-MM-DD for an all-day event."],
                    "end": ["type": "string", "description": "RFC 3339 with offset, or YYYY-MM-DD (exclusive) for an all-day event."],
                    "location": ["type": "string"],
                    "description": ["type": "string"],
                    "attendee_emails": ["type": "array", "items": ["type": "string"],
                                        "description": "Only email addresses the user gave or that appear on earlier events."],
                    "calendar_id": ["type": "string", "description": "Default: primary."],
                ],
                "required": ["title", "start", "end"],
            ],
        ],
        [
            "name": "update_event",
            "description": "Changes an event found with search_events. Only the fields given change.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "calendar_id": ["type": "string"],
                    "event_id": ["type": "string"],
                    "title": ["type": "string"],
                    "start": ["type": "string", "description": "RFC 3339 with offset, or YYYY-MM-DD for all-day."],
                    "end": ["type": "string", "description": "RFC 3339 with offset, or YYYY-MM-DD for all-day."],
                    "location": ["type": "string"],
                    "description": ["type": "string"],
                ],
                "required": ["calendar_id", "event_id"],
            ],
        ],
        [
            "name": "delete_event",
            "description": "Removes an event found with search_events.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "calendar_id": ["type": "string"],
                    "event_id": ["type": "string"],
                ],
                "required": ["calendar_id", "event_id"],
            ],
        ],
        [
            "name": "list_calendars",
            "description": "Lists the user's calendars with their ids and whether the user can add events to them.",
            "input_schema": ["type": "object", "properties": [String: Any]()],
        ],
    ]

    private struct ToolError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    private func runTool(_ name: String, _ input: [String: Any]) async throws -> String {
        func string(_ key: String) -> String? {
            (input[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
        func required(_ key: String) throws -> String {
            guard let value = string(key) else { throw ToolError(message: "Missing \(key).") }
            return value
        }

        switch name {
        case "list_calendars":
            let list = try await calendar.call("GET", "users/me/calendarList") as? [String: Any]
            let items = (list?["items"] as? [[String: Any]] ?? []).map { item -> [String: Any] in
                ["calendar_id": item["id"] ?? "", "title": item["summaryOverride"] ?? item["summary"] ?? "",
                 "primary": item["primary"] ?? false,
                 "can_add_events": ["owner", "writer"].contains(item["accessRole"] as? String ?? "")]
            }
            return try Self.json(items)

        case "search_events":
            let timeMin = try required("time_min")
            let timeMax = try required("time_max")
            var calendarIDs: [String]
            if let id = string("calendar_id") {
                calendarIDs = [id]
            } else {
                let list = try await calendar.call("GET", "users/me/calendarList") as? [String: Any]
                calendarIDs = (list?["items"] as? [[String: Any]] ?? [])
                    .filter { $0["hidden"] as? Bool != true }
                    .compactMap { $0["id"] as? String }
            }
            var events: [[String: Any]] = []
            for id in calendarIDs {
                var query: [URLQueryItem] = [
                    .init(name: "timeMin", value: timeMin), .init(name: "timeMax", value: timeMax),
                    .init(name: "singleEvents", value: "true"), .init(name: "orderBy", value: "startTime"),
                    .init(name: "maxResults", value: "250"),
                ]
                if let text = string("query") { query.append(.init(name: "q", value: text)) }
                // One calendar that fails, like a holiday subscription, shouldn't hide the rest.
                guard let page = try? await calendar.call("GET", "calendars/\(CalendarService.encodedID(id))/events",
                                                          query: query) as? [String: Any] else { continue }
                events += (page["items"] as? [[String: Any]] ?? [])
                    .filter { $0["status"] as? String != "cancelled" }
                    .map { Self.summary(of: $0, calendarID: id) }
            }
            let newestFirst = input["newest_first"] as? Bool ?? false
            events.sort {
                let a = $0["start"] as? String ?? "", b = $1["start"] as? String ?? ""
                return newestFirst ? Self.date(a) > Self.date(b) : Self.date(a) < Self.date(b)
            }
            let total = events.count
            events = Array(events.prefix(40))
            return try Self.json(["count": total, "events": events])

        case "create_event":
            var body = try Self.eventBody(title: required("title"), start: required("start"), end: required("end"),
                                          location: string("location"), description: string("description"))
            if let emails = input["attendee_emails"] as? [String], !emails.isEmpty {
                body["attendees"] = emails.map { ["email": $0] }
            }
            let id = string("calendar_id") ?? "primary"
            let created = try await calendar.call("POST", "calendars/\(CalendarService.encodedID(id))/events", json: body)
            calendar.refreshNow()
            return try Self.json(Self.summary(of: created as? [String: Any] ?? [:], calendarID: id))

        case "update_event":
            let calendarID = try required("calendar_id")
            let eventID = try required("event_id")
            var body: [String: Any] = [:]
            if let title = string("title") { body["summary"] = title }
            if let location = string("location") { body["location"] = location }
            if let description = string("description") { body["description"] = description }
            if let start = string("start") { body["start"] = Self.time(start) }
            if let end = string("end") { body["end"] = Self.time(end) }
            guard !body.isEmpty else { throw ToolError(message: "Nothing to change.") }
            let path = "calendars/\(CalendarService.encodedID(calendarID))/events/\(CalendarService.encodedID(eventID))"
            let updated = try await calendar.call("PATCH", path, json: body)
            calendar.refreshNow()
            return try Self.json(Self.summary(of: updated as? [String: Any] ?? [:], calendarID: calendarID))

        case "delete_event":
            let calendarID = try required("calendar_id")
            let eventID = try required("event_id")
            let path = "calendars/\(CalendarService.encodedID(calendarID))/events/\(CalendarService.encodedID(eventID))"
            _ = try await calendar.call("DELETE", path)
            calendar.refreshNow()
            return "Deleted."

        default:
            throw ToolError(message: "Unknown tool \(name).")
        }
    }

    private static func eventBody(title: String, start: String, end: String, location: String?,
                                  description: String?) -> [String: Any] {
        var body: [String: Any] = ["summary": title, "start": time(start), "end": time(end)]
        if let location { body["location"] = location }
        if let description { body["description"] = description }
        return body
    }

    /// "2026-11-06" is an all-day date; anything longer a time.
    private static func time(_ value: String) -> [String: Any] {
        value.count == 10
            ? ["date": value]
            : ["dateTime": value, "timeZone": TimeZone.current.identifier]
    }

    /// The fields Claude needs, without the noise of the full resource.
    private static func summary(of event: [String: Any], calendarID: String) -> [String: Any] {
        func when(_ key: String) -> String {
            let time = event[key] as? [String: Any]
            return time?["dateTime"] as? String ?? time?["date"] as? String ?? ""
        }
        var result: [String: Any] = [
            "calendar_id": calendarID,
            "event_id": event["id"] ?? "",
            "title": event["summary"] ?? "(no title)",
            "start": when("start"),
            "end": when("end"),
        ]
        if let location = event["location"] as? String, !location.isEmpty { result["location"] = location }
        if let description = event["description"] as? String, !description.isEmpty {
            result["description"] = String(description.prefix(300))
        }
        let attendees = (event["attendees"] as? [[String: Any]] ?? []).compactMap { attendee -> String? in
            guard attendee["self"] as? Bool != true else { return nil }
            let name = attendee["displayName"] as? String
            let email = attendee["email"] as? String
            return [name, email.map { "<\($0)>" }].compactMap { $0 }.joined(separator: " ").nilIfEmpty
        }
        if !attendees.isEmpty { result["attendees"] = attendees }
        return result
    }

    private static func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: value) ?? .distantPast
    }

    private static func json(_ value: Any) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    // MARK: Key files

    private static func keyURL(_ file: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dynamic Island", isDirectory: true)
            .appendingPathComponent(file)
    }

    private static func loadKey(file: String) -> String {
        ((try? String(contentsOf: keyURL(file), encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func saveKey(_ key: String, file: String) {
        let url = keyURL(file)
        let manager = FileManager.default
        guard !key.isEmpty else {
            try? manager.removeItem(at: url)
            return
        }
        try? manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !manager.fileExists(atPath: url.path) {
            manager.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        try? manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        if let handle = try? FileHandle(forWritingTo: url) {
            try? handle.truncate(atOffset: 0)
            try? handle.write(contentsOf: Data(key.utf8))
            try? handle.close()
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
