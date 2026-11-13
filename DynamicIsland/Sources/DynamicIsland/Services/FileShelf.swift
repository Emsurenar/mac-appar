import AppKit

/// Files on the island's shelf: ones dropped on the island, and new screenshots, recordings and downloads.
/// Each file stays for a few minutes, also when it's dragged out, moved, deleted or the app restarts,
/// unless it's removed by hand. The shelf keeps a copy of each file (an APFS clone, so it costs no space),
/// and hands that out once the original is gone. The originals themselves are never touched.
@MainActor @Observable
final class FileShelf {
    private(set) var files: [URL] = []
    /// When each file leaves the shelf.
    private(set) var expiries: [URL: Date] = [:]
    /// The shelf's own copy of each file, for when the original is moved or deleted.
    private(set) var copies: [URL: URL] = [:]

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let fileExists: (URL) -> Bool
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let copier: ShelfCopier
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    private static let key = "shelfFiles"
    private static let expiriesKey = "shelfExpiries"
    private static let copiesKey = "shelfCopies"

    /// Tests pass their own suite, file check, copier and clock, so they never touch the real shelf or disk.
    init(defaults: UserDefaults = .standard,
         copier: ShelfCopier = .disk,
         fileExists: @escaping (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
         now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.copier = copier
        self.fileExists = fileExists
        self.now = now
        let storedCopies = defaults.dictionary(forKey: Self.copiesKey) as? [String: String] ?? [:]
        copies = Dictionary(uniqueKeysWithValues: storedCopies.map {
            (URL(fileURLWithPath: $0.key), URL(fileURLWithPath: $0.value))
        })
        let stored = defaults.dictionary(forKey: Self.expiriesKey) as? [String: Double] ?? [:]
        expiries = Dictionary(uniqueKeysWithValues: stored.map {
            (URL(fileURLWithPath: $0.key), Date(timeIntervalSinceReferenceDate: $0.value))
        })
        // Files from before the shelf had a time limit have no expiry, and leave now.
        files = (defaults.stringArray(forKey: Self.key) ?? []).map { URL(fileURLWithPath: $0) }
            .filter { expiries[$0] != nil }
        prune()
        copier.purge(Set(copies.values))
    }

    var isEmpty: Bool { files.isEmpty }

    /// Where promised files (from Photos, Mail, a browser) are written when they're dropped.
    /// It's in the temporary folder, so macOS cleans it up after the files have left the shelf.
    nonisolated static func promisedFilesFolder() -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Shelf", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// Adds file URLs at the end for `duration`. Ones already on the shelf keep their place, and their time starts over.
    func add(_ urls: [URL], for duration: TimeInterval) {
        let new = urls.filter(\.isFileURL).map(\.standardizedFileURL)
        guard !new.isEmpty else { return }
        let expiry = now().addingTimeInterval(duration)
        for url in new {
            if !files.contains(url) { files.append(url) }
            expiries[url] = expiry
            // A file shelved again (a new download under the same name) gets a fresh copy.
            if let old = copies.removeValue(forKey: url) { copier.discard(old) }
            keepCopy(of: url)
        }
        save()
        scheduleExpiry()
    }

    func remove(_ url: URL) {
        files.removeAll { $0 == url }
        expiries[url] = nil
        if let copy = copies.removeValue(forKey: url) { copier.discard(copy) }
        save()
        scheduleExpiry()
    }

    func removeAll() {
        files.removeAll()
        expiries.removeAll()
        copies.values.forEach(copier.discard)
        copies.removeAll()
        save()
        scheduleExpiry()
    }

    /// Where the file is now: the original while it's there, otherwise the shelf's copy.
    func location(of url: URL) -> URL {
        if fileExists(url) { return url }
        if let copy = copies[url], fileExists(copy) { return copy }
        return url
    }

    private func keepCopy(of url: URL) {
        let copier = copier
        Task.detached(priority: .utility) {
            guard let copy = copier.copy(url) else { return }
            await MainActor.run { [weak self] in
                // The file may have left the shelf while it was being copied.
                guard let self, self.files.contains(url), self.copies[url] == nil else { return copier.discard(copy) }
                self.copies[url] = copy
                self.save()
            }
        }
    }

    #if DEBUG
    /// Shows these files without saving them, for `--snapshots`.
    func showPreview(_ urls: [URL]) {
        files = urls
        expiries = Dictionary(uniqueKeysWithValues: urls.map { ($0, now().addingTimeInterval(300)) })
    }
    #endif

    /// Drops files that were deleted or moved since they were shelved, and ones whose time is up.
    func prune() {
        let date = now()
        let kept = files.filter { url in
            let isThere = fileExists(url) || copies[url].map(fileExists) ?? false
            return isThere && expiries[url].map { $0 > date } ?? false
        }
        let keptExpiries = expiries.filter { kept.contains($0.key) }
        let keptCopies = copies.filter { kept.contains($0.key) }
        guard kept != files || keptExpiries != expiries || keptCopies != copies else { return scheduleExpiry() }
        copies.filter { !kept.contains($0.key) }.values.forEach(copier.discard)
        files = kept
        expiries = keptExpiries
        copies = keptCopies
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
        defaults.set(Dictionary(uniqueKeysWithValues: copies.map { ($0.key.path, $0.value.path) }), forKey: Self.copiesKey)
    }
}

/// Makes and throws away the shelf's own copies of files.
struct ShelfCopier: Sendable {
    /// Copies a file, returning where the copy is, or nil if it couldn't.
    var copy: @Sendable (URL) -> URL?
    var discard: @Sendable (URL) -> Void
    /// Deletes every copy except these, left over from files that left the shelf while the app was closed.
    var purge: @Sendable (Set<URL>) -> Void

    /// Keeps no copies, for tests.
    static let none = ShelfCopier(copy: { _ in nil }, discard: { _ in }, purge: { _ in })

    /// Copies into the app's caches folder. On the same APFS disk a copy is a clone: instant, and it takes no space.
    static let disk = ShelfCopier(
        copy: { url in
            let manager = FileManager.default
            let shelfFolder = ShelfCopier.diskFolder()
            let folder = shelfFolder.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let destination = folder.appendingPathComponent(url.lastPathComponent)
            // Copying a big file from another disk takes real time and space, so only small ones are.
            let keys: Set<URLResourceKey> = [.volumeIdentifierKey, .totalFileAllocatedSizeKey, .isDirectoryKey]
            let values = try? url.resourceValues(forKeys: keys)
            let shelfDisk = try? shelfFolder.resourceValues(forKeys: [.volumeIdentifierKey]).volumeIdentifier
            let sameDisk = values?.volumeIdentifier.map { $0.isEqual(shelfDisk) } ?? false
            if !sameDisk, values?.isDirectory == true || (values?.totalFileAllocatedSize ?? 0) > 1_000_000_000 { return nil }
            do {
                try manager.createDirectory(at: folder, withIntermediateDirectories: true)
                try manager.copyItem(at: url, to: destination)
                return destination
            } catch {
                try? manager.removeItem(at: folder)
                return nil
            }
        },
        discard: { copy in
            let folder = copy.deletingLastPathComponent()
            guard folder.deletingLastPathComponent().standardizedFileURL == ShelfCopier.diskFolder().standardizedFileURL else { return }
            try? FileManager.default.removeItem(at: folder)
        },
        purge: { keep in
            let keepFolders = Set(keep.map { $0.deletingLastPathComponent().standardizedFileURL })
            let folders = (try? FileManager.default.contentsOfDirectory(at: ShelfCopier.diskFolder(), includingPropertiesForKeys: nil)) ?? []
            for folder in folders where !keepFolders.contains(folder.standardizedFileURL) {
                try? FileManager.default.removeItem(at: folder)
            }
        })

    nonisolated static func diskFolder() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = caches.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.emresunar.DynamicIsland", isDirectory: true)
            .appendingPathComponent("Shelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }
}
