#if DEBUG
import AppKit
import SwiftUI

/// Debug aid: `Hallning --snapshots <dir>` renders the windows to PNG in light and dark
/// mode and quits. Run it from a debug build of the app bundle.
@MainActor
enum SnapshotRenderer {
    private typealias CreateImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?

    private static let createImage: CreateImage? = {
        guard let handle = dlopen(nil, RTLD_NOW), let symbol = dlsym(handle, "CGWindowListCreateImage") else { return nil }
        return unsafeBitCast(symbol, to: CreateImage.self)
    }()

    static func run(model: AppModel, directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        Task {
            try? await Task.sleep(for: .seconds(1))
            NSApp.activate()
            for appearance in [NSAppearance.Name.aqua, .darkAqua] {
                let suffix = appearance == .aqua ? "light" : "dark"
                model.monitor.showPreview(.good, neckAngle: 8)
                for section in MainSection.allCases {
                    await render(MainWindow(section: section), model: model, size: CGSize(width: 900, height: 660),
                                 titled: true, appearance: appearance, to: directory.appendingPathComponent("main-\(section.rawValue)-\(suffix).png"))
                }
                await render(MenuPanel(), model: model, size: nil, titled: false, appearance: appearance,
                             to: directory.appendingPathComponent("menu-good-\(suffix).png"))
                model.monitor.showPreview(.bad(.neckBent), neckAngle: 22, progress: 0.6, remaining: 48)
                await render(MenuPanel(), model: model, size: nil, titled: false, appearance: appearance,
                             to: directory.appendingPathComponent("menu-bad-\(suffix).png"))
                await render(MainWindow(section: .overview), model: model, size: CGSize(width: 900, height: 660),
                             titled: true, appearance: appearance, to: directory.appendingPathComponent("main-overview-bad-\(suffix).png"))
                for step in [OnboardingFlow.Step.welcome, .permissions, .placement, .good] {
                    await render(OnboardingView(initialStep: step), model: model, size: nil, titled: true, appearance: appearance,
                                 to: directory.appendingPathComponent("onboarding-\(step)-\(suffix).png"))
                }
            }
            NSApp.terminate(nil)
        }
    }

    private static func render<V: View>(_ view: V, model: AppModel, size: CGSize?, titled: Bool,
                                        appearance: NSAppearance.Name, to url: URL) async {
        let hosting = NSHostingView(rootView: view.environment(model))
        let frame = CGRect(origin: CGPoint(x: 80, y: 80), size: size ?? hosting.fittingSize)
        let style: NSWindow.StyleMask = titled ? [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView] : [.borderless]
        let window = NSWindow(contentRect: frame, styleMask: style, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: appearance)
        window.titlebarAppearsTransparent = !titled
        window.contentView = hosting
        if titled { window.makeKeyAndOrderFront(nil) } else { window.orderFrontRegardless() }
        try? await Task.sleep(for: .seconds(1.2))
        // SwiftUI only draws into the window server, so capture the window from there.
        // CGWindowListCreateImage is gone from the SDK but still captures our own windows.
        if let capture = createImage,
           let image = capture(.null, 1 << 3, CGWindowID(window.windowNumber), (1 << 0) | (1 << 3))?.takeRetainedValue() {
            try? NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])?.write(to: url)
        }
        window.orderOut(nil)
        window.close()
    }
}
#endif
