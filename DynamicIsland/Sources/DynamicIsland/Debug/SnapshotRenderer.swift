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
            model.select(.controls)
            render("8-open-controls", model, directory)
            model.select(.home)
            try? await Task.sleep(for: .seconds(1.5))
            render("9-open-home-empty", model, directory)
            model.home.showPreviewShortcuts()
            render("10-open-home", model, directory)
            model.select(.media)
            model.close()
            NSApp.terminate(nil)
        }
    }

    private static func render(_ name: String, _ model: IslandModel, _ directory: URL) {
        let view = ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.35, green: 0.5, blue: 0.85), Color(red: 0.8, green: 0.55, blue: 0.75)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            IslandRootView().environment(model)
        }
        .frame(width: 640, height: 300)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: directory.appendingPathComponent("\(name).png"))
    }
}
#endif
