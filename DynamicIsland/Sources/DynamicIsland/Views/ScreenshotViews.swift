import AppKit
import SwiftUI

// MARK: - Shelf

/// The newest screenshot, popped out of the notch so it can be dragged straight into another app.
struct ScreenshotShelfView: View {
    @Environment(IslandModel.self) private var model
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        let screenshots = model.screenshots
        if let shot = screenshots.latest {
            VStack(spacing: 0) {
                Color.clear.frame(height: model.notch.height)
                HStack(spacing: 12) {
                    thumbnail(screenshots.thumbnail)
                        .overlay {
                            if !isSnapshot {
                                FileDragSource(url: shot.url, image: screenshots.thumbnail,
                                               onBegin: { model.beginScreenshotDrag() },
                                               onEnd: { model.endScreenshotDrag(dropped: $0) },
                                               onClick: { screenshots.open(shot) })
                            }
                        }
                        .help("Drag to use it, click to open it")
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Screenshot")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Drag it anywhere")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                    HStack(spacing: 2) {
                        action("doc.on.doc", "Copy") { screenshots.copy(shot); model.dismissScreenshot() }
                        action("folder", "Show in Finder") { screenshots.revealInFinder(shot); model.dismissScreenshot() }
                        action("trash", "Move to Trash") { screenshots.moveToTrash(shot); model.dismissScreenshot() }
                        action("xmark", "Dismiss") { model.dismissScreenshot() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
            }
            .padding(.horizontal, model.earRadius)
        }
    }

    private func thumbnail(_ image: NSImage?) -> some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.1))
            }
        }
        .frame(width: IslandLayout.screenshotThumbnailSize.width, height: IslandLayout.screenshotThumbnailSize.height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.white.opacity(0.18)))
    }

    private func action(_ symbol: String, _ help: String, _ perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
        }
        .buttonStyle(IslandButtonStyle(diameter: 28))
        .help(help)
    }
}

// MARK: - Drag source

/// Drags a file out of the island. AppKit runs the drag, so it keeps going after the pointer leaves
/// the island and the island hears when it ends.
struct FileDragSource: NSViewRepresentable {
    var url: URL
    var image: NSImage?
    var onBegin: () -> Void = {}
    /// Called with whether another app took the file.
    var onEnd: (Bool) -> Void = { _ in }
    var onClick: () -> Void = {}

    func makeNSView(context: Context) -> DragView { DragView() }

    func updateNSView(_ view: DragView, context: Context) {
        view.url = url
        view.image = image
        view.onBegin = onBegin
        view.onEnd = onEnd
        view.onClick = onClick
    }

    final class DragView: NSView, NSDraggingSource {
        var url: URL?
        var image: NSImage?
        var onBegin: () -> Void = {}
        var onEnd: (Bool) -> Void = { _ in }
        var onClick: () -> Void = {}
        private var mouseDown: NSEvent?

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            mouseDown = event
        }

        override func mouseDragged(with event: NSEvent) {
            guard let down = mouseDown, let url else { return }
            let dx = event.locationInWindow.x - down.locationInWindow.x
            let dy = event.locationInWindow.y - down.locationInWindow.y
            guard hypot(dx, dy) > 3 else { return }
            mouseDown = nil
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            item.setDraggingFrame(bounds, contents: image ?? NSWorkspace.shared.icon(forFile: url.path))
            onBegin()
            beginDraggingSession(with: [item], event: down, source: self)
        }

        override func mouseUp(with event: NSEvent) {
            if mouseDown != nil { onClick() }
            mouseDown = nil
        }

        func draggingSession(_ session: NSDraggingSession,
                             sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            // Copy, so dropping it somewhere never moves the original away.
            context == .outsideApplication ? .copy : []
        }

        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            onEnd(operation != [])
        }
    }
}
