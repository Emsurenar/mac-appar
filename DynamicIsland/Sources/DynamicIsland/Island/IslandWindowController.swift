import AppKit
import SwiftUI

/// A borderless panel that floats above the menu bar, on every Space and over
/// full-screen apps, without ever activating the app.
final class IslandPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // Borderless windows are otherwise pushed below the menu bar.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

private final class IslandHostingView<Content: View>: NSHostingView<Content> {
    /// Takes file drops for the shelf. Handled here in AppKit, because SwiftUI's drop target
    /// is lost when the island changes shape under the drag.
    weak var model: IslandModel?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { fileDragOperation(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { fileDragOperation(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { model?.setDropTargeted(false) }
    override func draggingEnded(_ sender: NSDraggingInfo) { model?.setDropTargeted(false) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { fileDragOperation(sender) != [] }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteboard = sender.draggingPasteboard
        let urls = pasteboard.readObjects(forClasses: [NSURL.self],
                                          options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        if !urls.isEmpty { return model?.dropFiles(urls) ?? false }
        // Photos, Mail attachments, images from a browser and the screenshot thumbnail only promise
        // a file: it's written into the shelf's own folder, and shelved once it's there.
        let promises = pasteboard.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil)
            as? [NSFilePromiseReceiver] ?? []
        guard !promises.isEmpty, let model, model.acceptsFileDrops else { return false }
        let folder = FileShelf.promisedFilesFolder()
        for promise in promises {
            promise.receivePromisedFiles(atDestination: folder, options: [:], operationQueue: ShelfDrop.promiseQueue) { url, error in
                guard error == nil else { return }
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { _ = model.dropFiles([url], force: true) }
                }
            }
        }
        model.setDropTargeted(false)
        return true
    }

    /// Copy over the island, nothing over the transparent rest of the window.
    private func fileDragOperation(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let model, model.acceptsFileDrops, let window,
              ShelfDrop.hasFiles(sender.draggingPasteboard) else { return [] }
        let point = window.convertPoint(toScreen: sender.draggingLocation)
        let inside = model.hoverZone.contains(point)
        model.setDropTargeted(inside)
        return inside ? .copy : []
    }
}

/// What the island takes as a file drop: file URLs, and files that apps only promise.
enum ShelfDrop {
    static let promiseQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        return queue
    }()

    /// Whether a drag carries files, or promises of files.
    static func hasFiles(_ pasteboard: NSPasteboard) -> Bool {
        pasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
            || pasteboard.canReadObject(forClasses: [NSFilePromiseReceiver.self], options: nil)
    }

    static let draggedTypes: [NSPasteboard.PasteboardType] =
        [.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
}

@MainActor
final class IslandWindowController {
    /// Large enough for the open island plus its shadow; the rest is transparent and click-through.
    private static let canvasSize = CGSize(width: 760, height: 440)

    private let model: IslandModel
    private let panel: IslandPanel
    private var monitors: [Any] = []
    /// The drag pasteboard's change count when the mouse went down, to tell a new file drag from an old one.
    private var dragCountAtMouseDown = NSPasteboard(name: .drag).changeCount
    private var handledDragCount: Int?

    init(model: IslandModel) {
        self.model = model
        panel = IslandPanel(contentRect: NSRect(origin: .zero, size: Self.canvasSize))

        let hostingView = IslandHostingView(rootView: IslandRootView().environment(model))
        hostingView.sizingOptions = []
        hostingView.frame = NSRect(origin: .zero, size: Self.canvasSize)
        hostingView.model = model
        hostingView.registerForDraggedTypes(ShelfDrop.draggedTypes)
        panel.contentView = hostingView

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }
        installMouseMonitors()
        observeHoverZone()
        #if DEBUG
        if CommandLine.arguments.contains("--trace") { trace() }
        #endif
    }

    #if DEBUG
    private func trace() {
        withObservationTracking {
            _ = model.presentation
            _ = model.media.isPlaying
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    print("presentation=\(self.model.presentation) playing=\(self.model.media.isPlaying) clickThrough=\(self.panel.ignoresMouseEvents)")
                    fflush(stdout)
                    self.trace()
                }
            }
        }
    }
    #endif

    func show() {
        reposition()
        panel.orderFrontRegardless()
    }

    private func reposition() {
        guard let screen = NotchMetrics.preferredScreen() else { return }
        let metrics = NotchMetrics(screen: screen)
        model.metrics = metrics
        let origin = CGPoint(x: (metrics.centerX - Self.canvasSize.width / 2).rounded(),
                             y: screen.frame.maxY - Self.canvasSize.height)
        panel.setFrame(NSRect(origin: origin, size: Self.canvasSize), display: true)
    }

    private func installMouseMonitors() {
        let movement: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: movement, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePointer() }
        }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: movement, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.updatePointer() }
            return event
        }) {
            monitors.append(local)
        }
        // A click anywhere else (delivered to another app) closes the island.
        if let clicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.dragCountAtMouseDown = NSPasteboard(name: .drag).changeCount
                guard !self.model.hoverZone.contains(NSEvent.mouseLocation) else { return }
                self.model.close()
            }
        }) {
            monitors.append(clicks)
        }
    }

    private func updatePointer() {
        // A file drag over the island keeps it hit-testable until the drag leaves or drops.
        let inside = model.hoverZone.contains(NSEvent.mouseLocation) || model.isDropTargeted
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
        model.setHovering(inside)
        if inside { openForFileDrag() }
    }

    /// Files dragged from another app onto the notch open the shelf, even without hover to open.
    private func openForFileDrag() {
        guard NSEvent.pressedMouseButtons & 1 != 0 else { return }
        let pasteboard = NSPasteboard(name: .drag)
        let count = pasteboard.changeCount
        guard count != dragCountAtMouseDown, count != handledDragCount,
              ShelfDrop.hasFiles(pasteboard) else { return }
        handledDragCount = count
        model.showShelfForDrop()
    }

    /// Re-evaluates the pointer whenever the island changes shape under it.
    private func observeHoverZone() {
        withObservationTracking {
            _ = model.hoverZone
        } onChange: { [weak self] in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.updatePointer()
                    self?.observeHoverZone()
                }
            }
        }
    }
}
