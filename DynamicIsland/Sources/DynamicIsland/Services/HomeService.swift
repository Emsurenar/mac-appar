import AppKit

struct HomeShortcut: Identifiable, Equatable {
    let id: String
    let name: String
    /// The name without a leading emoji.
    let title: String
    let emoji: String?
    let symbol: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
        if let first = name.first, first.unicodeScalars.first?.properties.isEmojiPresentation == true {
            emoji = String(first)
            title = String(name.dropFirst()).trimmingCharacters(in: .whitespaces)
        } else {
            emoji = nil
            title = name
        }
        symbol = Self.symbol(for: name)
    }

    /// Picks an SF Symbol from words in the shortcut's name (Swedish and English).
    private static func symbol(for name: String) -> String {
        let name = name.lowercased()
        let table: [([String], String)] = [
            (["golvlampa", "floor lamp"], "lamp.floor.fill"),
            (["bordslampa", "desk lamp", "table lamp"], "lamp.desk.fill"),
            (["taklampa", "ceiling"], "light.recessed.fill"),
            (["lampa", "lampor", "ljus", "belysning", "light", "lamp"], "lightbulb.fill"),
            (["garage"], "door.garage.closed"),
            (["lås", "dörr", "lock", "door"], "lock.fill"),
            (["värme", "termostat", "temperatur", "element", "heat", "thermostat"], "thermometer.medium"),
            (["fläkt", "fan", "ventilation"], "fan.fill"),
            (["luftrenare", "purifier"], "air.purifier.fill"),
            (["gardin", "persienn", "rullgardin", "blind", "curtain"], "blinds.horizontal.closed"),
            (["uttag", "kontakt", "plug", "outlet"], "poweroutlet.type.f.fill"),
            (["tv", "film", "movie"], "tv.fill"),
            (["högtalare", "musik", "speaker", "music"], "hifispeaker.fill"),
            (["kaffe", "coffee"], "cup.and.saucer.fill"),
            (["natt", "sov", "night", "sleep", "bed"], "moon.stars.fill"),
            (["morgon", "vakna", "morning"], "sun.horizon.fill"),
            (["middag", "dinner", "kök", "kitchen"], "fork.knife"),
            (["läs", "read"], "book.fill"),
            (["borta", "lämna", "leave", "away"], "figure.walk.departure"),
            (["hemma", "kom hem", "arrive"], "house.fill"),
        ]
        return table.first { words, _ in words.contains { name.contains($0) } }?.1 ?? "sparkles"
    }
}

enum HomeRunState: Equatable {
    case idle, running, succeeded, failed
}

/// Apple Home through the user's Shortcuts: HomeKit itself is unavailable to
/// native macOS apps, but shortcuts using "Control Home" can be run from here.
@MainActor @Observable
final class HomeService {
    private(set) var shortcuts: [HomeShortcut] = []
    private(set) var folderExists = false
    private(set) var runStates: [String: HomeRunState] = [:]
    /// Last on/off state reported by a shortcut's output ("på"/"av", "on"/"off" …).
    private(set) var toggleStates: [String: Bool]

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var isRefreshing = false
    @ObservationIgnored private static let toggleStatesKey = "homeToggleStates"

    init(settings: AppSettings) {
        self.settings = settings
        toggleStates = UserDefaults.standard.dictionary(forKey: Self.toggleStatesKey) as? [String: Bool] ?? [:]
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let wanted = settings.homeFolderName.trimmingCharacters(in: .whitespaces)
        Task.detached {
            // `shortcuts list --folder-name` silently lists everything for an unknown
            // folder, so look the folder up first.
            let folders = Self.execute(["list", "--folders"]).output.split(separator: "\n").map(String.init)
            let folder = folders.first { $0.compare(wanted, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
            var found: [HomeShortcut] = []
            if let folder {
                for line in Self.execute(["list", "--folder-name", folder, "--show-identifiers"]).output.split(separator: "\n") {
                    if let shortcut = Self.parse(String(line)) { found.append(shortcut) }
                }
            }
            await MainActor.run { [found] in
                self.isRefreshing = false
                self.folderExists = folder != nil
                if found != self.shortcuts { self.shortcuts = found }
            }
        }
    }

    func run(_ shortcut: HomeShortcut) {
        guard runStates[shortcut.id] != .running else { return }
        runStates[shortcut.id] = .running
        Task.detached {
            let output = FileManager.default.temporaryDirectory.appendingPathComponent("island-\(UUID().uuidString).txt")
            let result = Self.execute(["run", shortcut.id, "--output-path", output.path, "--output-type", "public.plain-text"])
            let text = (try? String(contentsOf: output, encoding: .utf8)) ?? ""
            try? FileManager.default.removeItem(at: output)
            await MainActor.run {
                self.finish(shortcut, succeeded: result.status == 0, output: text)
            }
        }
    }

    func reveal(_ shortcut: HomeShortcut) {
        Task.detached { _ = Self.execute(["view", shortcut.name]) }
    }

    static func openShortcutsApp() { openApp("com.apple.shortcuts") }
    static func openHomeApp() { openApp("com.apple.Home") }

    #if DEBUG
    func showPreviewShortcuts() {
        shortcuts = ["💡 Living Room", "Kitchen Light", "Good Night", "Front Door", "Heating", "Arrive Home"].enumerated().map {
            HomeShortcut(id: UUID().uuidString, name: $0.element)
        }
        toggleStates = [shortcuts[0].id: true, shortcuts[3].id: true]
        runStates = [shortcuts[1].id: .running, shortcuts[4].id: .failed]
    }
    #endif

    private func finish(_ shortcut: HomeShortcut, succeeded: Bool, output: String) {
        runStates[shortcut.id] = succeeded ? .succeeded : .failed
        if succeeded, let state = Self.toggleState(from: output) {
            toggleStates[shortcut.id] = state
            UserDefaults.standard.set(toggleStates, forKey: Self.toggleStatesKey)
        }
        Task {
            try? await Task.sleep(for: .seconds(succeeded ? 1.4 : 2.4))
            if runStates[shortcut.id] != .running { runStates[shortcut.id] = .idle }
        }
    }

    private static func toggleState(from output: String) -> Bool? {
        switch output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "på", "on", "true", "1", "ja", "yes", "öppen", "upplåst", "open", "unlocked": true
        case "av", "off", "false", "0", "nej", "no", "stängd", "låst", "closed", "locked": false
        default: nil
        }
    }

    private nonisolated static func parse(_ line: String) -> HomeShortcut? {
        // "Name (UUID)"
        guard line.hasSuffix(")"), let open = line.range(of: " (", options: .backwards) else { return nil }
        let id = String(line[open.upperBound..<line.index(before: line.endIndex)])
        guard UUID(uuidString: id) != nil else { return nil }
        return HomeShortcut(id: id, name: String(line[..<open.lowerBound]))
    }

    private nonisolated static func execute(_ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }

    private static func openApp(_ bundleIdentifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
