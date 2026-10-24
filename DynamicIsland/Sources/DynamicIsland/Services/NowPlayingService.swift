import AppKit
import SwiftUI

/// System-wide Now Playing state (Music, Spotify, Safari, Chrome, Podcasts …).
///
/// MediaRemote only answers Apple-signed processes since macOS 15.4, so the
/// actual work happens in `NowPlayingBridge` running inside `/usr/bin/perl`.
@MainActor @Observable
final class NowPlayingService {
    private(set) var title = ""
    private(set) var artist = ""
    private(set) var album = ""
    private(set) var duration: Double = 0
    private(set) var isPlaying = false
    private(set) var artwork: NSImage?
    /// Bumped whenever the artwork changes so views can cross-fade.
    private(set) var artworkVersion = 0
    /// A vivid color sampled from the artwork, used for the equalizer.
    private(set) var accentColor = Color.white
    private(set) var bundleIdentifier: String?
    private(set) var appIcon: NSImage?

    @ObservationIgnored var onTrackChange: (() -> Void)?

    @ObservationIgnored private var elapsedAnchor: Double = 0
    @ObservationIgnored private var anchorDate = Date()
    @ObservationIgnored private var rate: Double = 1
    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var input: FileHandle?
    @ObservationIgnored private var isStopping = false
    @ObservationIgnored private var restartDelay: Double = 1
    @ObservationIgnored private var hasReceivedSnapshot = false

    var hasMedia: Bool { !title.isEmpty }
    var subtitle: String { artist.isEmpty ? album : artist }

    func elapsed(at date: Date = Date()) -> Double {
        var value = elapsedAnchor
        if isPlaying { value += date.timeIntervalSince(anchorDate) * rate }
        return duration > 0 ? min(max(value, 0), duration) : max(value, 0)
    }

    // MARK: Commands

    func togglePlayPause() {
        guard hasMedia else { return }
        // Optimistic update keeps the button snappy; the bridge confirms shortly after.
        elapsedAnchor = elapsed()
        anchorDate = Date()
        isPlaying.toggle()
        send("toggle")
    }

    func nextTrack() { send("next") }
    func previousTrack() { send("prev") }

    func seek(to seconds: Double) {
        elapsedAnchor = seconds
        anchorDate = Date()
        send("seek \(seconds)")
    }

    func openPlayer() {
        guard let bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: Bridge process

    private static let loader = """
        use DynaLoader;
        my $lib = DynaLoader::dl_load_file($ARGV[0], 0) or die DynaLoader::dl_error();
        my $sym = DynaLoader::dl_find_symbol($lib, "bridge_main") or die "bridge_main missing";
        DynaLoader::dl_install_xsub("main::bridge_main", $sym)->();
        """

    func start() {
        guard process == nil,
              let bridge = Bundle.main.url(forResource: "libNowPlayingBridge", withExtension: "dylib") else { return }
        isStopping = false

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = ["-e", Self.loader, bridge.path]
        let output = Pipe()
        let input = Pipe()
        process.standardOutput = output
        process.standardInput = input
        process.standardError = FileHandle.nullDevice

        let buffer = LineBuffer()
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else {
                handle.readabilityHandler = nil
                return
            }
            let snapshots = buffer.append(chunk).compactMap(Snapshot.init(json:))
            guard !snapshots.isEmpty else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    snapshots.forEach { self?.apply($0) }
                }
            }
        }
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.bridgeDidExit() }
            }
        }

        do {
            try process.run()
            self.process = process
            self.input = input.fileHandleForWriting
        } catch {
            bridgeDidExit()
        }
    }

    func stop() {
        isStopping = true
        process?.terminate()
        process = nil
    }

    private func bridgeDidExit() {
        process = nil
        input = nil
        guard !isStopping else { return }
        let delay = restartDelay
        restartDelay = min(restartDelay * 2, 30)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            MainActor.assumeIsolated { self?.start() }
        }
    }

    private func send(_ command: String) {
        guard let input, let data = (command + "\n").data(using: .utf8) else { return }
        try? input.write(contentsOf: data)
    }

    private func apply(_ snapshot: Snapshot) {
        restartDelay = 1
        let isFirst = !hasReceivedSnapshot
        hasReceivedSnapshot = true

        guard !snapshot.isEmpty else {
            title = ""; artist = ""; album = ""
            duration = 0; isPlaying = false
            setArtwork(nil)
            bundleIdentifier = nil; appIcon = nil
            return
        }

        let trackChanged = snapshot.title != title || snapshot.artist != artist
        title = snapshot.title
        artist = snapshot.artist
        album = snapshot.album
        duration = snapshot.duration
        isPlaying = snapshot.isPlaying
        rate = snapshot.rate > 0 ? snapshot.rate : 1
        elapsedAnchor = snapshot.elapsed
        anchorDate = snapshot.timestamp ?? Date()

        if snapshot.bundleIdentifier != bundleIdentifier {
            bundleIdentifier = snapshot.bundleIdentifier
            appIcon = snapshot.bundleIdentifier
                .flatMap { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
                .map { NSWorkspace.shared.icon(forFile: $0.path) }
        }

        switch snapshot.artwork {
        case .unchanged: break
        case .cleared: setArtwork(nil)
        case .data(let data): setArtwork(NSImage(data: data))
        }

        if trackChanged && !isFirst && hasMedia { onTrackChange?() }
    }

    private func setArtwork(_ image: NSImage?) {
        artwork = image
        artworkVersion += 1
        accentColor = image.flatMap(Self.vividColor(of:)) ?? .white
    }

    /// Picks the most vivid of a handful of sampled pixels, like the iOS
    /// Dynamic Island does for its waveform.
    private static func vividColor(of image: NSImage) -> Color? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let side = 12
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let context = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var best: (score: CGFloat, color: NSColor)?
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let color = NSColor(srgbRed: CGFloat(pixels[i]) / 255, green: CGFloat(pixels[i + 1]) / 255,
                                blue: CGFloat(pixels[i + 2]) / 255, alpha: 1)
            let score = color.saturationComponent * (0.4 + color.brightnessComponent)
            if color.brightnessComponent > 0.2, score > (best?.score ?? -1) { best = (score, color) }
        }
        guard let base = best?.color else { return nil }
        let saturation = base.saturationComponent < 0.15 ? 0 : min(base.saturationComponent * 1.1, 0.85)
        return Color(nsColor: NSColor(hue: base.hueComponent, saturation: saturation,
                                      brightness: max(base.brightnessComponent, 0.85), alpha: 1))
    }
}

// MARK: - Bridge protocol

private struct Snapshot: Sendable {
    enum Artwork: Sendable { case unchanged, cleared, data(Data) }

    var isEmpty = false
    var title = ""
    var artist = ""
    var album = ""
    var duration: Double = 0
    var elapsed: Double = 0
    var rate: Double = 0
    var timestamp: Date?
    var isPlaying = false
    var bundleIdentifier: String?
    var artwork = Artwork.unchanged

    init?(json: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { return nil }
        if (object["empty"] as? NSNumber)?.boolValue == true {
            isEmpty = true
            return
        }
        title = object["title"] as? String ?? ""
        artist = object["artist"] as? String ?? ""
        album = object["album"] as? String ?? ""
        duration = (object["duration"] as? NSNumber)?.doubleValue ?? 0
        elapsed = (object["elapsed"] as? NSNumber)?.doubleValue ?? 0
        rate = (object["rate"] as? NSNumber)?.doubleValue ?? 0
        timestamp = (object["timestamp"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
        isPlaying = (object["playing"] as? NSNumber)?.boolValue ?? false
        bundleIdentifier = object["bundle"] as? String
        if let encoded = object["artwork"] as? String {
            artwork = Data(base64Encoded: encoded).map(Artwork.data) ?? .cleared
        }
    }
}

private final class LineBuffer: @unchecked Sendable {
    private var data = Data()

    func append(_ chunk: Data) -> [Data] {
        data.append(chunk)
        var lines: [Data] = []
        while let newline = data.firstIndex(of: 0x0A) {
            lines.append(Data(data[data.startIndex..<newline]))
            data.removeSubrange(data.startIndex...newline)
        }
        return lines
    }
}
