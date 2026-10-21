import AppKit

/// Checks GitHub for a newer release. Nothing is downloaded or installed automatically.
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
    }

    @Published private(set) var status = Status.idle

    var availableVersion: String? {
        if case .available(let version) = status { return version }
        return nil
    }

    private let lastCheckKey = "lastUpdateCheck"

    /// Checks at most once a day, if the user allows it.
    func checkIfDue() {
        guard Preferences.shared.checkForUpdates else { return }
        let last = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? .distantPast
        if Date().timeIntervalSince(last) > 24 * 60 * 60 { check() }
    }

    func check() {
        guard status != .checking else { return }
        status = .checking
        Task {
            do {
                var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest")!)
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.timeoutInterval = 15
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                struct Release: Decodable { let tag_name: String }
                let tag = try JSONDecoder().decode(Release.self, from: data).tag_name
                let latest = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
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
