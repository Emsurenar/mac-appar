#if DEBUG
import AppKit
import SwiftUI

/// Debug aid: `DynamicIsland --snapshots <dir>` renders every island state to PNG and quits.
@MainActor
enum SnapshotRenderer {
    static func run(model: IslandModel, directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        Task {
            try? await Task.sleep(for: .seconds(3))
            model.media.showPreview(title: "Golden Hour Over the Harbor", artist: "Lumen Avenue",
                                    duration: 213, elapsed: 173, artwork: previewArtwork())
            render("1-closed", model, directory)
            render("2-compact", model, directory)
            model.showTrackPeek()
            render("3-peek", model, directory)
            model.showHUD(.volume)
            render("4-hud-volume", model, directory)
            model.showHUD(.brightness)
            render("5-hud-brightness", model, directory)
            model.showHUD(.outputDevice)
            render("6-hud-device", model, directory)
            model.open()
            render("7-open-media", model, directory)
            renderHero("0-hero", model, directory)
            model.setChoosingOutput(true)
            model.airPods.showPreview()
            render("8-open-output", model, directory)
            model.setChoosingOutput(false)
            model.select(.home)
            try? await Task.sleep(for: .seconds(1.5))
            model.open()  // The hover tracker may have closed it while waiting.
            render("9-open-home-empty", model, directory)
            model.home.showPreviewShortcuts()
            render("10-open-home", model, directory)
            // On: 0 (light orange), 3 (dark purple). Running: 1. Idle light: 2. Failed: 4.
            model.home.showPreviewColors(["#FF9500", "#0A84FF", "#FFD60A", "#5E2CA5", "#FFCC00", "#FF375F", nil])
            render("10c-open-home-colors", model, directory)
            model.home.showPreviewColors([])
            model.setChoosingShortcuts(true)
            model.home.showPreviewShortcuts(limit: 5)
            render("10b-home-picker", model, directory)
            model.setChoosingShortcuts(false)
            model.close()
            model.posture.showPreview(.init(status: "bad", issue: "neckBent", title: "Lift your head",
                                            progress: 0.7, score: 42, todayGood: 0.78, headPitch: 22, airpods: true,
                                            interval: 10, lastCheck: Date().addingTimeInterval(-6), pausedUntil: nil))
            render("11-posture-compact", model, directory)
            model.posture.showPreviewAlert(.init(issue: "neckBent", title: "Lift your head",
                                                 body: "", minutes: 2))
            model.showPostureAlert()
            try? await Task.sleep(for: .seconds(0.5))
            render("12-posture-alert", model, directory)
            model.open()
            model.select(.posture)
            render("13-open-posture-bad", model, directory)
            model.posture.showPreview(.init(status: "good", issue: nil, title: "Good posture",
                                            progress: 0, score: 91, todayGood: 0.86, headPitch: 2, airpods: true,
                                            interval: 10, lastCheck: Date(), pausedUntil: nil))
            render("14-open-posture-good", model, directory)
            model.close()
            let now = Date()
            let events: [CalendarService.Event] = [
                .init(id: "1", title: "Standup", start: now.addingTimeInterval(-600), end: now.addingTimeInterval(300),
                      location: nil, color: .systemGreen, meetingURL: URL(string: "https://meet.google.com/abc-defg-hij")),
                .init(id: "2", title: "Möte med Erik", start: now.addingTimeInterval(900), end: now.addingTimeInterval(4500),
                      location: "Konferensrum 3", color: .systemBlue, meetingURL: nil),
                .init(id: "3", title: "Lunch", start: now.addingTimeInterval(7200), end: now.addingTimeInterval(10800),
                      location: nil, color: .systemOrange, meetingURL: nil),
            ]
            model.calendar.showPreview(events)
            model.calendar.showPreviewReminder(events[1])
            model.showCalendarReminder()
            try? await Task.sleep(for: .seconds(0.5))
            render("15-calendar-reminder", model, directory)
            model.open()
            model.select(.calendar)
            model.calendar.showPreview(events)  // Opening the tab reloads the real calendar.
            render("16-open-calendar", model, directory)
            model.select(.media)
            model.close()
            model.water.showPreview(glasses: 3)
            model.showWaterReminder()
            try? await Task.sleep(for: .seconds(0.5))
            render("17-water-reminder", model, directory)
            model.dismissWaterReminder(drank: false)
            model.water.showPreview(glasses: 5)
            model.open()
            model.select(.water)
            render("19-open-water", model, directory)
            model.select(.media)
            model.close()
            model.clipboard.showPreview([
                (.text("https://github.com/Emsurenar/mac-appar"), "com.apple.Safari", 1),
                (.text("Meet you at the station at 18:30?"), "com.apple.MobileSMS", 6),
                (.text("swift build -c release"), "com.apple.Terminal", 14),
                (.text("Konferensrum 3, plan 4"), "com.apple.iCal", 32),
            ])
            model.shelf.showPreview(previewShelfFiles(in: directory))
            model.open()
            model.select(.clipboard)
            render("20-open-clipboard", model, directory)
            model.select(.system)
            try? await Task.sleep(for: .seconds(2.5))  // CPU needs two samples.
            model.open()
            render("21-open-system", model, directory)
            model.select(.media)
            model.close()
            model.screenshots.showPreview(previewScreenshot())
            model.showScreenshot()
            try? await Task.sleep(for: .seconds(0.5))
            render("18-screenshot", model, directory)
            model.dismissScreenshot()
            NSApp.terminate(nil)
        }
    }

    /// A stand-in album cover: a sunset over water.
    private static func previewArtwork() -> NSImage {
        let view = ZStack {
            VStack(spacing: 0) {
                LinearGradient(colors: [Color(red: 1, green: 0.7, blue: 0.4), Color(red: 0.98, green: 0.42, blue: 0.3)],
                               startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: [Color(red: 0.32, green: 0.28, blue: 0.62), Color(red: 0.16, green: 0.18, blue: 0.42)],
                               startPoint: .top, endPoint: .bottom)
            }
            Circle().fill(Color(red: 1, green: 0.93, blue: 0.75)).frame(width: 150, height: 150)
                .offset(y: -10).frame(width: 300, height: 300, alignment: .center)
                .mask(VStack(spacing: 0) { Rectangle(); Color.clear })
            VStack(spacing: 12) {
                ForEach(0..<5) { index in
                    Capsule().fill(.white.opacity(0.5)).frame(width: 90 - CGFloat(index) * 12, height: 3)
                }
            }
            .offset(y: 60)
        }
        .frame(width: 300, height: 300)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.nsImage ?? NSImage()
    }

    /// A stand-in screenshot: the wallpaper with a window on it.
    private static func previewScreenshot() -> NSImage {
        let view = ZStack {
            Wallpaper()
            RoundedRectangle(cornerRadius: 10).fill(.white.opacity(0.9)).padding(40)
        }
        .frame(width: 480, height: 300)
        return ImageRenderer(content: view).nsImage ?? NSImage()
    }

    /// Empty files with telling names, so the shelf shows real file icons.
    private static func previewShelfFiles(in directory: URL) -> [URL] {
        let folder = directory.appendingPathComponent(".shelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return ["Quarterly report.pdf", "Holiday.jpg", "Slides.key"].map { name in
            let url = folder.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: Data()) }
            return url
        }
    }

    /// One state on a wallpaper-like background, sized to the island.
    private static func render(_ name: String, _ model: IslandModel, _ directory: URL) {
        let height = max(model.size.height + 64, 110)
        let view = ZStack(alignment: .top) {
            Wallpaper()
            IslandRootView().environment(model).environment(\.isSnapshot, true)
        }
        .frame(width: 640, height: height)
        write(view, scale: 2, to: directory.appendingPathComponent("\(name).png"))
    }

    /// The open island hanging over a menu bar.
    private static func renderHero(_ name: String, _ model: IslandModel, _ directory: URL) {
        let view = ZStack(alignment: .top) {
            Wallpaper()
            MenuBar(height: model.notch.height)
            IslandRootView().environment(model).environment(\.isSnapshot, true)
        }
        .frame(width: 1000, height: 240)
        write(view, scale: 2, to: directory.appendingPathComponent("\(name).png"))
    }

    private static func write(_ view: some View, scale: CGFloat, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}

private struct Wallpaper: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.12, green: 0.24, blue: 0.62), Color(red: 0.46, green: 0.3, blue: 0.8),
                                    Color(red: 0.93, green: 0.56, blue: 0.68)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.28), .clear], center: .init(x: 0.7, y: 0.9),
                           startRadius: 0, endRadius: 520)
        }
    }
}

private struct MenuBar: View {
    var height: CGFloat

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: "apple.logo").font(.system(size: 15, weight: .medium))
            Text("Finder").fontWeight(.bold)
            ForEach(["File", "Edit"], id: \.self) { Text($0) }
            Spacer()
            HStack(spacing: 18) {
                Image(systemName: "wifi")
                Image(systemName: "switch.2")
                Text("Sat 9:41")
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .frame(height: height)
    }
}
#endif
