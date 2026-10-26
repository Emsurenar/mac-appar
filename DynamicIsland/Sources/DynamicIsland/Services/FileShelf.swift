import AppKit

/// Files dropped on the island. They stay on the shelf, also across launches, until they're dragged out.
/// The shelf only keeps references: the files themselves never move.
@MainActor @Observable
final class FileShelf {
    private(set) var files: [URL] = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let fileExists: (URL) -> Bool
    private static let key = "shelfFiles"

    /// Tests pass their own suite and file check, so they never touch the real shelf or disk.
    init(defaults: UserDefaults = .standard,
         fileExists: @escaping (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) {
        self.defaults = defaults
        self.fileExists = fileExists
        files = (defaults.stringArray(forKey: Self.key) ?? []).map { URL(fileURLWithPath: $0) }
        prune()
    }

    var isEmpty: Bool { files.isEmpty }

    /// Adds file URLs at the end; ones already on the shelf keep their place.
    func add(_ urls: [URL]) {
        let new = urls.filter(\.isFileURL).map(\.standardizedFileURL)
        var changed = false
        for url in new where !files.contains(url) {
            files.append(url)
            changed = true
        }
        if changed { save() }
    }

    func remove(_ url: URL) {
        files.removeAll { $0 == url }
        save()
    }

    func removeAll() {
        files.removeAll()
        save()
    }

    /// Drops files that were deleted or moved since they were shelved.
    func prune() {
        let existing = files.filter(fileExists)
        guard existing != files else { return }
        files = existing
        save()
    }

    /// Reads the file URLs from a drop and adds them as they arrive.
    func add(from providers: [NSItemProvider]) {
        for provider in providers where provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                guard let url else { return }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.add([url]) }
                }
            }
        }
    }

    private func save() {
        defaults.set(files.map(\.path), forKey: Self.key)
    }
}
