import AppKit
import SwiftUI

@main
struct HallningApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
                .environment(model)
        } label: {
            MenuBarLabel()
                .environment(model)
        }
        .menuBarExtraStyle(.window)

        Window("Posture", id: AppModel.WindowID.main) {
            MainWindow()
                .environment(model)
        }
        .defaultSize(width: 920, height: 700)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Window("Welcome to Posture", id: AppModel.WindowID.onboarding) {
            OnboardingView()
                .environment(model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
    }
}

/// The menu bar icon. It also opens windows on request, since only views can do that.
private struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(nsImage: PostureFigure.menuBarImage(slouch: PostureFigure.slouch(for: model.monitor.status)))
            .accessibilityLabel("Posture")
            .task {
                #if DEBUG
                if AppModel.isSnapshotting, let flag = CommandLine.arguments.firstIndex(of: "--snapshots"),
                   flag + 1 < CommandLine.arguments.count {
                    SnapshotRenderer.run(model: model, directory: URL(fileURLWithPath: CommandLine.arguments[flag + 1]))
                    return
                }
                #endif
                // First launch: go straight to onboarding.
                guard !model.isCalibrated else { return }
                try? await Task.sleep(for: .seconds(0.6))
                show(AppModel.WindowID.onboarding)
            }
            .onChange(of: model.windowRequest) { _, request in
                if let request { show(request.id) }
            }
    }

    private func show(_ id: String) {
        openWindow(id: id)
        NSApp.activate()
    }
}
