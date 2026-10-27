import AppKit
import os

/// Notices new screenshots. macOS marks every capture with `kMDItemIsScreenCapture`. The service
/// watches the screenshot folder for files carrying that mark, and asks Spotlight too, for captures
/// saved somewhere else.
@MainActor @Observable
final class ScreenshotService {
    struct Screenshot: Equatable, Identifiable {
        let url: URL
        let date: Date
        var id: URL { url }
    }

    /// The newest screenshot taken since launch.
    private(set) var latest: Screenshot?
    private(set) var thumbnail: NSImage?

    @ObservationIgnored var onNewScreenshot: ((Screenshot) -> Void)?
    @ObservationIgnored private var query: NSMetadataQuery?
    @ObservationIgnored private var observer: NSObjectProtocol?
    @ObservationIgnored private var folderSource: DispatchSourceFileSystemObject?
    private nonisolated static let log = Logger(subsystem: "com.emresunar.DynamicIsland", category: "screenshots")
    @ObservationIgnored private var startDate = Date()

    func start() {
        guard query == nil else { return }
        startDate = Date()
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "kMDItemIsScreenCapture = 1")
        query.searchScopes = [NSMetadataQueryLocalComputerScope]
        observer = NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query,
                                                          queue: .main) { [weak self] note in
            let added = note.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
            let changed = note.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] ?? []
            let candidates = (added + changed).compactMap(Self.screenshot(from:))
            MainActor.assumeIsolated { self?.consider(candidates) }
        }
        query.start()
        self.query = query
        watchFolder()
    }

    func stop() {
        query?.stop()
        query = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        folderSource?.cancel()
        folderSource = nil
    }

    // MARK: Screenshot folder

    /// Where screenshots go: the folder picked in the Screenshot app, or the Desktop.
    nonisolated static func screenshotFolder() -> URL {
        if let path = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location"), !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }

    /// The mark macOS puts on its captures, and what Spotlight reads `kMDItemIsScreenCapture` from.
    nonisolated static func isScreenCapture(_ url: URL) -> Bool {
        getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) > 0
    }

    private func watchFolder() {
        let folder = Self.screenshotFolder()
        // The Desktop is protected: listing it asks for access once. Without that access Spotlight
        // leaves its files out too, so the query alone never sees a screenshot there.
        _ = try? FileManager.default.contentsOfDirectory(atPath: folder.path)
        let descriptor = Darwin.open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else {
            Self.log.error("Can't watch \(folder.path, privacy: .public)")
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.scan(folder)
                // The mark can land just after the file appears, so look once more a moment later.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    MainActor.assumeIsolated { self?.scan(folder) }
                }
            }
        }
        source.setCancelHandler { Darwin.close(descriptor) }
        source.resume()
        folderSource = source
    }

    private func scan(_ folder: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey],
                                                                  options: .skipsHiddenFiles)) ?? []
        let candidates = files.compactMap { url -> Screenshot? in
            guard let date = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
                  date >= startDate, Self.isScreenCapture(url) else { return nil }
            return Screenshot(url: url, date: date)
        }
        consider(candidates)
    }

    /// Picks the screenshot to show from the ones Spotlight just reported: the newest one taken
    /// after `start`, ignoring hidden files (macOS writes a hidden file first and renames it)
    /// and anything not newer than what is already shown.
    nonisolated static func newest(_ candidates: [Screenshot], after start: Date, current: Screenshot?) -> Screenshot? {
        candidates
            .filter { $0.date >= start && !$0.url.lastPathComponent.hasPrefix(".") }
            .filter { candidate in current.map { candidate.url != $0.url && candidate.date >= $0.date } ?? true }
            .max { $0.date < $1.date }
    }

    private nonisolated static func screenshot(from item: NSMetadataItem) -> Screenshot? {
        guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { return nil }
        let date = item.value(forAttribute: NSMetadataItemFSCreationDateKey) as? Date ?? Date()
        return Screenshot(url: URL(fileURLWithPath: path), date: date)
    }

    private func consider(_ candidates: [Screenshot]) {
        let existing = candidates.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        guard let shot = Self.newest(existing, after: startDate, current: latest) else { return }
        Self.log.info("New screenshot \(shot.url.lastPathComponent, privacy: .public)")
        latest = shot
        thumbnail = NSImage(contentsOf: shot.url)
        onNewScreenshot?(shot)
    }

    // MARK: Actions

    func open(_ shot: Screenshot) {
        NSWorkspace.shared.open(shot.url)
    }

    func revealInFinder(_ shot: Screenshot) {
        NSWorkspace.shared.activateFileViewerSelecting([shot.url])
    }

    /// Puts both the file and the image on the pasteboard, so it pastes into Finder and into chats.
    func copy(_ shot: Screenshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        var items: [NSPasteboardWriting] = [shot.url as NSURL]
        if let thumbnail { items.append(thumbnail) }
        pasteboard.writeObjects(items)
    }

    func moveToTrash(_ shot: Screenshot) {
        try? FileManager.default.trashItem(at: shot.url, resultingItemURL: nil)
        if latest == shot {
            latest = nil
            thumbnail = nil
        }
    }

    #if DEBUG
    func showPreview(_ image: NSImage) {
        latest = Screenshot(url: URL(fileURLWithPath: "/tmp/Screenshot.png"), date: Date())
        thumbnail = image
    }
    #endif
}
