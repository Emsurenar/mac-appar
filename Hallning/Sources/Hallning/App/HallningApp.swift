import AppKit
import SwiftUI

@main
struct HallningApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuPanel()
                .environment(model)
                .tint(.teal)
        } label: {
            MenuBarLabel()
                .environment(model)
        }
        .menuBarExtraStyle(.window)

        Window("Hållning", id: AppModel.WindowID.main) {
            MainWindow()
                .environment(model)
                .tint(.teal)
        }
        .defaultSize(width: 920, height: 700)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Window("Välkommen till Hållning", id: AppModel.WindowID.onboarding) {
            OnboardingView()
                .environment(model)
                .tint(.teal)
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
            .accessibilityLabel("Hållning")
            .task {
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
