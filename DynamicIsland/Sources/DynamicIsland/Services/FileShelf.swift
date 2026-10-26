import AppKit
import UniformTypeIdentifiers

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
    /// Asks for the raw file-URL item: Finder hands that over reliably, unlike `loadObject(ofClass: URL.self)`.
    func add(from providers: [NSItemProvider]) {
        let type = UTType.fileURL.identifier
        for provider in providers where provider.hasItemConformingToTypeIdentifier(type) {
            provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, error in
                guard let url = Self.fileURL(from: item) else {
                    NSLog("Shelf: no file URL in drop (%@)", error?.localizedDescription ?? "unknown item")
                    return
                }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { self?.add([url]) }
                }
            }
        }
    }

    /// A dropped file-URL item comes as data, a URL or a string, depending on the source app.
    nonisolated static func fileURL(from item: Any?) -> URL? {
        let url: URL? = switch item {
        case let data as Data: URL(dataRepresentation: data, relativeTo: nil)
        case let url as URL: url
        case let string as String: URL(string: string)
        default: nil
        }
        guard let url, url.isFileURL else { return nil }
        return url
    }

    private func save() {
        defaults.set(files.map(\.path), forKey: Self.key)
    }
}
