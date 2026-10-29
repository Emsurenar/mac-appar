import AppKit
import SwiftUI

// MARK: - Section

/// Files dropped on the island, in a row at the top of the clipboard tab.
/// Drag one out to use it, and it leaves the shelf.
struct ShelfSection: View {
    @Environment(IslandModel.self) private var model
    @Environment(\.isSnapshot) private var isSnapshot

    var body: some View {
        Group {
            if model.shelf.isEmpty {
                emptyState
            } else {
                fileRow
            }
        }
    }

    private var fileRow: some View {
        let shelf = model.shelf
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Files")
                Spacer()
                Button("Clear") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { shelf.removeAll() }
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.45))
            .frame(height: IslandLayout.sectionHeaderHeight, alignment: .bottom)

            Group {
                if isSnapshot {
                    tiles
                } else {
                    ScrollView(.horizontal) { tiles }
                        .scrollIndicators(.never)
                }
            }
            .frame(height: IslandLayout.shelfTileHeight + 8)
            .padding(.horizontal, -6)
            .animation(.spring(response: 0.4, dampingFraction: 0.78), value: shelf.files)
        }
    }

    private var tiles: some View {
        HStack(spacing: 6) {
            ForEach(model.shelf.files, id: \.self) { url in
                ShelfFileTile(url: url)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyState: some View {
        let isTargeted = model.isDropTargeted
        return HStack(spacing: 8) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 14, weight: .medium))
                .symbolEffect(.bounce, value: isTargeted)
            Text(isTargeted ? "Drop to keep it here" : "Drag files onto the notch to keep them here")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(.white.opacity(isTargeted ? 1 : 0.55))
        .frame(maxWidth: .infinity)
        .frame(height: IslandLayout.shelfDropStripHeight)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.white.opacity(isTargeted ? 0.5 : 0.18), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(isTargeted ? 0.08 : 0)))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isTargeted)
    }
}

// MARK: - File tile

private struct ShelfFileTile: View {
    let url: URL
    @Environment(IslandModel.self) private var model
    @Environment(\.isSnapshot) private var isSnapshot
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 40, height: 40)
            Text(url.lastPathComponent)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .frame(height: 26, alignment: .top)
        }
        .frame(width: IslandLayout.shelfTileWidth, height: IslandLayout.shelfTileHeight)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(isHovering ? 0.1 : 0)))
        .overlay {
            if !isSnapshot {
                ShelfDragArea(url: url) {
                    model.close()
                } onDraggedOut: {
                    model.shelf.remove(url)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button { model.shelf.remove(url) } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(.white.opacity(0.25)))
                }
                .buttonStyle(.plain)
                .offset(x: -2, y: 2)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
                .help("Remove from the shelf")
            }
        }
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isHovering = hovering }
        }
        .help(url.path)
    }
}

// MARK: - Dragging out

/// The tile's mouse handling in AppKit, since SwiftUI can't tell whether a drag landed anywhere.
/// A drag hands the file to wherever it's dropped; a double click opens it.
private struct ShelfDragArea: NSViewRepresentable {
    let url: URL
    let onBegin: () -> Void
    let onDraggedOut: () -> Void

    init(url: URL, onBegin: @escaping () -> Void, onDraggedOut: @escaping () -> Void) {
        self.url = url
        self.onBegin = onBegin
        self.onDraggedOut = onDraggedOut
    }

    func makeNSView(context: Context) -> DragAreaView { DragAreaView() }

    func updateNSView(_ view: DragAreaView, context: Context) {
        view.url = url
        view.onBegin = onBegin
        view.onDraggedOut = onDraggedOut
    }

    final class DragAreaView: NSView {
        var url: URL?
        var onBegin: (() -> Void)?
        var onDraggedOut: (() -> Void)?
        private var mouseDownLocation: NSPoint?

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            mouseDownLocation = event.locationInWindow
            if event.clickCount == 2, let url { NSWorkspace.shared.open(url) }
        }

        override func mouseDragged(with event: NSEvent) {
            guard let url, let start = mouseDownLocation else { return }
            let distance = hypot(event.locationInWindow.x - start.x, event.locationInWindow.y - start.y)
            guard distance > 4 else { return }
            mouseDownLocation = nil

            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            item.setDraggingFrame(NSRect(x: (bounds.width - 40) / 2, y: bounds.height - 44, width: 40, height: 40),
                                  contents: icon)
            // The view goes away when the island closes, so the session gets a source that outlives it.
            let source = ShelfDragSource(onDraggedOut: onDraggedOut)
            ShelfDragSource.current = source
            beginDraggingSession(with: [item], event: event, source: source)
            onBegin?()
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            guard let url else { return nil }
            let menu = NSMenu()
            menu.addItem(ShelfMenuItem("Open") { NSWorkspace.shared.open(url) })
            menu.addItem(ShelfMenuItem("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) })
            menu.addItem(.separator())
            menu.addItem(ShelfMenuItem("Remove from Shelf") { [weak self] in self?.onDraggedOut?() })
            return menu
        }
    }
}

/// Removes the file from the shelf once it lands somewhere that takes it.
@MainActor
final class ShelfDragSource: NSObject, NSDraggingSource {
    /// The drag in progress, kept alive for the length of the session.
    static var current: ShelfDragSource?
    static var isDragging: Bool { current != nil }

    private let onDraggedOut: (() -> Void)?

    init(onDraggedOut: (() -> Void)?) {
        self.onDraggedOut = onDraggedOut
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        // Copy, never move: the original file stays where it was.
        context == .outsideApplication ? [.copy, .generic] : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation != [] { onDraggedOut?() }
        Self.current = nil
    }
}

private final class ShelfMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func run() { handler() }
}
