import AppKit
import os

/// Notices files that finish downloading into the Downloads folder.
@MainActor
final class DownloadsService {
    var onNewFiles: (([URL]) -> Void)?

    private var folderSource: DispatchSourceFileSystemObject?
    private var startDate = Date()
    private var seen: Set<URL> = []
    private nonisolated static let log = Logger(subsystem: "com.emresunar.DynamicIsland", category: "downloads")

    /// Browsers write here while a download runs, and rename the file when it's done.
    nonisolated static let partialExtensions: Set<String> = ["crdownload", "download", "part", "partial", "opdownload", "tmp"]

    nonisolated static func downloadsFolder() -> URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
    }

    /// Whether a file in the Downloads folder is a finished download, not one still being written.
    nonisolated static func isFinished(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        return !name.hasPrefix(".") && !partialExtensions.contains(url.pathExtension.lowercased())
    }

    func start() {
        guard folderSource == nil else { return }
        startDate = Date()
        let folder = Self.downloadsFolder()
        // Downloads is protected: listing it asks for access once.
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
                // Some browsers rename the finished file a moment after the last write.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    MainActor.assumeIsolated { self?.scan(folder) }
                }
            }
        }
        source.setCancelHandler { Darwin.close(descriptor) }
        source.resume()
        folderSource = source
    }

    func stop() {
        folderSource?.cancel()
        folderSource = nil
    }

    private func scan(_ folder: URL) {
        let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .creationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys,
                                                                  options: .skipsHiddenFiles)) ?? []
        let new = files.filter { url in
            guard Self.isFinished(url), !seen.contains(url),
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  let date = values.addedToDirectoryDate ?? values.creationDate else { return false }
            return date >= startDate
        }
        guard !new.isEmpty else { return }
        seen.formUnion(new)
        Self.log.info("New downloads: \(new.map(\.lastPathComponent).joined(separator: ", "), privacy: .public)")
        onNewFiles?(new)
    }
}
