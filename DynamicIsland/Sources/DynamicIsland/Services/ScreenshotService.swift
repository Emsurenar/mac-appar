import AppKit

/// Notices new screenshots through Spotlight, which tags every capture with `kMDItemIsScreenCapture`
/// wherever it is saved, so a changed screenshot folder needs no setting.
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
    }

    func stop() {
        query?.stop()
        query = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
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
