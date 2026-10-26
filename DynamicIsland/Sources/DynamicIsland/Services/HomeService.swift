import AppKit
import SwiftUI

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
/// native macOS apps, but any shortcut — "Control Home" ones included — can be run from here.
@MainActor @Observable
final class HomeService {
    /// Every shortcut in the Shortcuts app, for choosing which ones get a tile.
    private(set) var allShortcuts: [HomeShortcut] = []
    /// Shortcuts the user picked in the island, in the order they were added.
    private(set) var pinnedIDs: [String]
    /// Shortcuts in the folder from settings; they get a tile automatically.
    private(set) var folderShortcuts: [HomeShortcut] = []
    private(set) var folderExists = false
    private(set) var runStates: [String: HomeRunState] = [:]
    /// Last on/off state reported by a shortcut's output ("på"/"av", "on"/"off" …).
    private(set) var toggleStates: [String: Bool]
    /// Tile colors the user picked, as sRGB hex ("#FF9500") by shortcut id.
    private(set) var tileColors: [String: String]

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var isRefreshing = false
    @ObservationIgnored private static let toggleStatesKey = "homeToggleStates"
    @ObservationIgnored private static let pinnedKey = "pinnedShortcuts"
    @ObservationIgnored private static let tileColorsKey = "homeTileColors"

    init(settings: AppSettings) {
        self.settings = settings
        toggleStates = UserDefaults.standard.dictionary(forKey: Self.toggleStatesKey) as? [String: Bool] ?? [:]
        pinnedIDs = UserDefaults.standard.stringArray(forKey: Self.pinnedKey) ?? []
        tileColors = UserDefaults.standard.dictionary(forKey: Self.tileColorsKey) as? [String: String] ?? [:]
    }

    /// The tiles: picked shortcuts first, then the rest of the folder.
    var shortcuts: [HomeShortcut] {
        let pinned = pinnedIDs.compactMap { id in allShortcuts.first { $0.id == id } }
        return pinned + folderShortcuts.filter { !pinnedIDs.contains($0.id) }
    }

    func isPinned(_ shortcut: HomeShortcut) -> Bool { pinnedIDs.contains(shortcut.id) }
    func isInFolder(_ shortcut: HomeShortcut) -> Bool { folderShortcuts.contains { $0.id == shortcut.id } }

    func color(for shortcut: HomeShortcut) -> NSColor? {
        tileColors[shortcut.id].flatMap(NSColor.init(hex:))
    }

    /// Sets the tile's color; nil goes back to the plain gray tile.
    func setColor(_ color: NSColor?, for shortcut: HomeShortcut) {
        tileColors[shortcut.id] = color?.hexString
        UserDefaults.standard.set(tileColors, forKey: Self.tileColorsKey)
    }

    /// A binding for `ColorPicker`; gray until a color is picked.
    func colorBinding(for shortcut: HomeShortcut) -> Binding<Color> {
        Binding(
            get: { Color(nsColor: self.color(for: shortcut) ?? .systemGray) },
            set: { self.setColor(NSColor($0), for: shortcut) }
        )
    }

    /// Opens the system color panel (with its color wheel) for one tile; changes apply live.
    func chooseColor(for shortcut: HomeShortcut) {
        TileColorPanel.shared.show(initial: color(for: shortcut)) { [weak self] color in
            self?.setColor(color, for: shortcut)
        }
    }

    func togglePin(_ shortcut: HomeShortcut) {
        if let index = pinnedIDs.firstIndex(of: shortcut.id) {
            pinnedIDs.remove(at: index)
        } else {
            pinnedIDs.append(shortcut.id)
        }
        UserDefaults.standard.set(pinnedIDs, forKey: Self.pinnedKey)
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let wanted = settings.homeFolderName.trimmingCharacters(in: .whitespaces)
        Task.detached {
            let all = Self.execute(["list", "--show-identifiers"]).output.split(separator: "\n")
                .compactMap { Self.parse(String($0)) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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
            await MainActor.run { [all, found] in
                self.isRefreshing = false
                self.folderExists = folder != nil
                if all != self.allShortcuts { self.allShortcuts = all }
                if found != self.folderShortcuts { self.folderShortcuts = found }
                // Forget picks whose shortcut has been deleted.
                let known = Set(all.map(\.id))
                if !all.isEmpty, self.pinnedIDs.contains(where: { !known.contains($0) }) {
                    self.pinnedIDs.removeAll { !known.contains($0) }
                    UserDefaults.standard.set(self.pinnedIDs, forKey: Self.pinnedKey)
                }
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
    func showPreviewShortcuts(limit: Int = .max) {
        allShortcuts = ["💡 Living Room", "Kitchen Light", "Good Night", "Front Door", "Heating", "Arrive Home", "Focus Music"]
            .prefix(limit)
            .map { HomeShortcut(id: UUID().uuidString, name: $0) }
        pinnedIDs = allShortcuts.dropLast().map(\.id)
        folderShortcuts = []
        let tiles = shortcuts
        toggleStates = Dictionary(uniqueKeysWithValues: [0, 3].filter { $0 < tiles.count }.map { (tiles[$0].id, true) })
        runStates = tiles.count > 4 ? [tiles[1].id: .running, tiles[4].id: .failed] : [:]
    }

    /// Colors the preview tiles without saving them; nil clears them again.
    func showPreviewColors(_ hexes: [String?]) {
        tileColors = Dictionary(uniqueKeysWithValues: zip(shortcuts, hexes).compactMap { tile, hex in
            hex.map { (tile.id, $0) }
        })
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

/// Drives the shared `NSColorPanel` for a tile picked from the island.
@MainActor
final class TileColorPanel: NSObject {
    static let shared = TileColorPanel()
    private var onChange: ((NSColor) -> Void)?

    func show(initial: NSColor?, onChange: @escaping (NSColor) -> Void) {
        let panel = NSColorPanel.shared
        // Set the color before taking over the panel, so it doesn't fire for the old one.
        detach()
        panel.showsAlpha = false
        panel.mode = .wheel
        if let initial { panel.color = initial }
        self.onChange = onChange
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        panel.isContinuous = true
        NotificationCenter.default.addObserver(self, selector: #selector(panelWillClose(_:)),
                                               name: NSWindow.willCloseNotification, object: panel)
        NSApp.activate()
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    /// Lets go of the panel, so color wells elsewhere (Settings) don't also recolor the tile.
    func detach() {
        guard onChange != nil else { return }
        onChange = nil
        let panel = NSColorPanel.shared
        // NSColorPanel has no target getter; detach only runs while the panel is ours.
        panel.setTarget(nil)
        panel.setAction(nil)
        NotificationCenter.default.removeObserver(self, name: NSWindow.willCloseNotification, object: panel)
    }

    @objc private func colorDidChange(_ panel: NSColorPanel) {
        onChange?(panel.color)
    }

    @objc private func panelWillClose(_ note: Notification) {
        detach()
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                  green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255,
                  alpha: 1)
    }

    var hexString: String? {
        guard let rgb = usingColorSpace(.sRGB) else { return nil }
        let channels = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
            .map { Int((min(max($0, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", channels[0], channels[1], channels[2])
    }

    /// Whether black text reads better than white on this color.
    var isLight: Bool {
        guard let rgb = usingColorSpace(.sRGB) else { return false }
        return 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent > 0.62
    }
}
