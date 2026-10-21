import AppKit
import CryptoKit

/// Checks GitHub for a newer release and, when you ask it to, installs it. Nothing is downloaded or
/// installed without a click.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    static let repository = "Emsurenar/unknot"
    static let repositoryURL = URL(string: "https://github.com/\(repository)")!
    static let releasesURL = URL(string: "https://github.com/\(repository)/releases/latest")!
    static let issuesURL = URL(string: "https://github.com/\(repository)/issues")!

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    enum Status: Equatable {
        case idle, checking, upToDate, failed
        case available(String)
        case installing(String)
        case installFailed(String)
    }

    @Published private(set) var status = Status.idle

    var availableVersion: String? {
        switch status {
        case .available(let version), .installing(let version): return version
        default: return nil
        }
    }

    private let lastCheckKey = "lastUpdateCheck"
    private var download: (url: URL, sha256: String?)?
    private var latestVersion: String?

    /// Checks at most once a day, if the user allows it.
    func checkIfDue() {
        guard Preferences.shared.checkForUpdates else { return }
        let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        if Date().timeIntervalSince(last) > 24 * 60 * 60 { check() }
    }

    func check() {
        guard status != .checking, availableVersion == nil else { return }
        status = .checking
        Task {
            do {
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest")!)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 15
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                struct Asset: Decodable { let name: String; let browser_download_url: URL; let digest: String? }
                struct Release: Decodable { let tag_name: String; let assets: [Asset] }
                let release = try JSONDecoder().decode(Release.self, from: data)
                let latest = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                if let zip = release.assets.first(where: { $0.name == "Unknot.zip" }) {
                    // GitHub publishes a SHA-256 for each asset, written "sha256:<hex>"
                    download = (zip.browser_download_url, zip.digest.flatMap { $0.hasPrefix("sha256:") ? String($0.dropFirst(7)) : nil })
                }
                latestVersion = latest
                status = Self.isVersion(latest, newerThan: Self.currentVersion) ? .available(latest) : .upToDate
                UserDefaults.standard.set(Date(), forKey: lastCheckKey)
            } catch {
                status = .failed
            }
        }
    }

    func openReleasePage() {
        NSWorkspace.shared.open(Self.releasesURL)
    }

    /// Asks before installing, from the menu bar.
    func offerUpdate() {
        guard let version = availableVersion else { return }
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = L("Unknot %@ is available", version)
        alert.informativeText = L("You have %@. The update is downloaded from GitHub and Unknot restarts. Your settings stay as they are.",
                                  Self.currentVersion)
        alert.addButton(withTitle: L("Install and Restart"))
        alert.addButton(withTitle: L("Release Notes"))
        alert.addButton(withTitle: L("Later"))
        switch alert.runModal() {
        case .alertFirstButtonReturn: install()
        case .alertSecondButtonReturn: openReleasePage()
        default: break
        }
    }

    /// Downloads the new version, checks it, puts it in place of this one and restarts.
    func install() {
        guard let version = latestVersion, Self.isVersion(version, newerThan: Self.currentVersion) else { return }
        if case .installing = status { return }
        guard let download, AppMover.isInApplicationsFolder,
              FileManager.default.isWritableFile(atPath: Bundle.main.bundleURL.deletingLastPathComponent().path) else {
            // Somewhere we can't replace ourselves: let the person download it instead
            openReleasePage()
            return
        }
        status = .installing(version)
        Task {
            do {
                let app = try await Self.fetch(download.url, sha256: download.sha256, expecting: version)
                _ = try FileManager.default.replaceItemAt(Bundle.main.bundleURL, withItemAt: app)
                AppMover.relaunch(from: Bundle.main.bundleURL)
            } catch {
                status = .installFailed(error.localizedDescription)
            }
        }
    }

    enum UpdateError: LocalizedError {
        case checksum, notUnknot, process(String)
        var errorDescription: String? {
            switch self {
            case .checksum: return L("The download was damaged. Please try again.")
            case .notUnknot: return L("The download didn't contain the expected version of Unknot.")
            case .process(let tool): return L("Couldn't unpack the update (%@).", tool)
            }
        }
    }

    /// Downloads and unpacks a release into a temporary folder and returns the app inside, once it has
    /// checked that it's the version we expect.
    nonisolated static func fetch(_ url: URL, sha256: String?, expecting version: String) async throws -> URL {
        let (file, response) = try await URLSession.shared.download(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        if let sha256 {
            let digest = SHA256.hash(data: try Data(contentsOf: file)).map { String(format: "%02x", $0) }.joined()
            guard digest == sha256.lowercased() else { throw UpdateError.checksum }
        }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Unknot-update-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try run("/usr/bin/ditto", ["-x", "-k", file.path, folder.path])
        let app = folder.appendingPathComponent("Unknot.app")
        guard let bundle = Bundle(url: app),
              bundle.bundleIdentifier == Bundle.main.bundleIdentifier,
              bundle.infoDictionary?["CFBundleShortVersionString"] as? String == version else { throw UpdateError.notUnknot }
        try run("/usr/bin/codesign", ["--verify", "--deep", app.path])
        return app
    }

    private nonisolated static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.process(URL(fileURLWithPath: tool).lastPathComponent) }
    }

    nonisolated static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let lhs = a.split(separator: ".").map { Int($0) ?? 0 }
        let rhs = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(lhs.count, rhs.count) {
            let x = i < lhs.count ? lhs[i] : 0
            let y = i < rhs.count ? rhs[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
