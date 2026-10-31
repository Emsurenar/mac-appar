import AppKit

/// Files on the island's shelf: ones dropped on the island, and new screenshots and downloads. Each file
/// stays for a few minutes, also when it's dragged out or the app restarts, unless it's removed by hand.
/// The shelf only keeps references: the files themselves never move.
@MainActor @Observable
final class FileShelf {
    private(set) var files: [URL] = []
    /// When each file leaves the shelf.
    private(set) var expiries: [URL: Date] = [:]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let fileExists: (URL) -> Bool
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    private static let key = "shelfFiles"
    private static let expiriesKey = "shelfExpiries"

    /// Tests pass their own suite, file check and clock, so they never touch the real shelf or disk.
    init(defaults: UserDefaults = .standard,
         fileExists: @escaping (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
         now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.fileExists = fileExists
        self.now = now
        let stored = defaults.dictionary(forKey: Self.expiriesKey) as? [String: Double] ?? [:]
        expiries = Dictionary(uniqueKeysWithValues: stored.map {
            (URL(fileURLWithPath: $0.key), Date(timeIntervalSinceReferenceDate: $0.value))
        })
        // Files from before the shelf had a time limit have no expiry, and leave now.
        files = (defaults.stringArray(forKey: Self.key) ?? []).map { URL(fileURLWithPath: $0) }
            .filter { expiries[$0] != nil }
        prune()
    }

    var isEmpty: Bool { files.isEmpty }

    /// Adds file URLs at the end for `duration`. Ones already on the shelf keep their place, and their time starts over.
    func add(_ urls: [URL], for duration: TimeInterval) {
        let new = urls.filter(\.isFileURL).map(\.standardizedFileURL)
        guard !new.isEmpty else { return }
        let expiry = now().addingTimeInterval(duration)
        for url in new {
            if !files.contains(url) { files.append(url) }
            expiries[url] = expiry
        }
        save()
        scheduleExpiry()
    }

    func remove(_ url: URL) {
        files.removeAll { $0 == url }
        expiries[url] = nil
        save()
        scheduleExpiry()
    }

    func removeAll() {
        files.removeAll()
        expiries.removeAll()
        save()
        scheduleExpiry()
    }

    /// Drops files that were deleted or moved since they were shelved, and ones whose time is up.
    func prune() {
        let date = now()
        let kept = files.filter { url in fileExists(url) && expiries[url].map { $0 > date } ?? false }
        let keptExpiries = expiries.filter { kept.contains($0.key) }
        guard kept != files || keptExpiries != expiries else { return scheduleExpiry() }
        files = kept
        expiries = keptExpiries
        save()
        scheduleExpiry()
    }

    /// Wakes up when the next file is due.
    private func scheduleExpiry() {
        expiryTask?.cancel()
        guard let next = expiries.values.min() else { return }
        let delay = max(next.timeIntervalSince(now()), 0) + 0.5
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.prune()
        }
    }

    private func save() {
        defaults.set(files.map(\.path), forKey: Self.key)
        defaults.set(Dictionary(uniqueKeysWithValues: expiries.map { ($0.key.path, $0.value.timeIntervalSinceReferenceDate) }),
                     forKey: Self.expiriesKey)
    }
}
