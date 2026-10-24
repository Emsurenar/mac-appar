import Foundation

enum SampleKind: String, Codable, Sendable {
    case good, bad, uncertain, away
}

/// Counts of checks during one minute of the day.
struct MinuteBucket: Codable, Equatable, Sendable {
    var minute: Int
    var good = 0
    var bad = 0
    var uncertain = 0
}

struct AlertRecord: Codable, Equatable, Identifiable, Sendable {
    var id = UUID()
    var date: Date
    var issue: PostureIssue
}

struct DayHistory: Codable, Equatable, Sendable {
    /// "yyyy-MM-dd" in local time.
    var day: String
    var buckets: [MinuteBucket] = []
    var alerts: [AlertRecord] = []
    var issues: [String: Int] = [:]

    var good: Int { buckets.reduce(0) { $0 + $1.good } }
    var bad: Int { buckets.reduce(0) { $0 + $1.bad } }

    /// Share of good checks, or nil without data.
    var goodFraction: Double? {
        let total = good + bad
        return total > 0 ? Double(good) / Double(total) : nil
    }
}

struct DayEntry: Identifiable {
    var date: Date
    var history: DayHistory?

    var id: Date { date }
}

/// One JSON file per day in Application Support/Hallning/History, kept for 30 days.
@MainActor @Observable
final class HistoryStore {
    private(set) var today: DayHistory

    @ObservationIgnored private var cache: [String: DayHistory] = [:]
    @ObservationIgnored private let calendar = Calendar.current

    private static var directory: URL { CalibrationStore.directory.appendingPathComponent("History", isDirectory: true) }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init() {
        let key = Self.dayFormatter.string(from: Date())
        today = Self.read(key) ?? DayHistory(day: key)
        prune()
    }

    func record(_ kind: SampleKind, issue: PostureIssue?, at date: Date = Date()) {
        rollOver(date)
        guard kind != .away else { return }
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        var bucket: MinuteBucket
        if let last = today.buckets.last, last.minute == minute {
            bucket = today.buckets.removeLast()
        } else {
            bucket = MinuteBucket(minute: minute)
        }
        switch kind {
        case .good: bucket.good += 1
        case .bad: bucket.bad += 1
        case .uncertain: bucket.uncertain += 1
        case .away: break
        }
        today.buckets.append(bucket)
        if kind == .bad, let issue { today.issues[issue.rawValue, default: 0] += 1 }
        save(today)
    }

    func recordAlert(_ issue: PostureIssue, at date: Date = Date()) {
        rollOver(date)
        today.alerts.append(AlertRecord(date: date, issue: issue))
        save(today)
    }

    /// The last `count` days, oldest first, including today.
    func days(_ count: Int) -> [DayEntry] {
        let start = calendar.startOfDay(for: Date())
        var result: [DayEntry] = []
        for offset in (0..<count).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: start) else { continue }
            let key = Self.dayFormatter.string(from: date)
            var history: DayHistory?
            if key == today.day {
                history = today
            } else if let cached = cache[key] {
                history = cached
            } else {
                history = Self.read(key)
                if let history { cache[key] = history }
            }
            result.append(DayEntry(date: date, history: history))
        }
        return result
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: Self.directory)
        cache.removeAll()
        today = DayHistory(day: Self.dayFormatter.string(from: Date()))
    }

    private func rollOver(_ date: Date) {
        let key = Self.dayFormatter.string(from: date)
        guard key != today.day else { return }
        cache[today.day] = today
        today = Self.read(key) ?? DayHistory(day: key)
        prune()
    }

    private func save(_ history: DayHistory) {
        do {
            try FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
            let data = try CalibrationStore.encoder.encode(history)
            try data.write(to: Self.directory.appendingPathComponent("\(history.day).json"), options: .atomic)
        } catch {
            NSLog("Hållning: could not save history: \(error)")
        }
    }

    private static func read(_ key: String) -> DayHistory? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent("\(key).json")) else { return nil }
        return try? CalibrationStore.decoder.decode(DayHistory.self, from: data)
    }

    private func prune() {
        guard let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()),
              let files = try? FileManager.default.contentsOfDirectory(at: Self.directory, includingPropertiesForKeys: nil) else { return }
        let oldest = Self.dayFormatter.string(from: cutoff)
        for file in files where file.pathExtension == "json" && file.deletingPathExtension().lastPathComponent < oldest {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
