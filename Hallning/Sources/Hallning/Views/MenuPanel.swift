import SwiftUI

/// The menu bar window.
struct MenuPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        let monitor = model.monitor
        VStack(alignment: .leading, spacing: 14) {
            StatusHeader()

            if monitor.status.isBad {
                ReminderProgress(progress: monitor.progress, remaining: monitor.remaining)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if model.isCalibrated {
                HStack(spacing: 8) {
                    StatTile(title: "Bra i dag", value: percent(model.history.today.goodFraction),
                             symbol: "figure.stand", tint: .green)
                    StatTile(title: "Påminnelser", value: "\(model.history.today.alerts.count)",
                             symbol: "bell.fill", tint: .orange)
                    StatTile(title: model.neckAngle == nil ? "Inga AirPods" : "Nacke",
                             value: model.neckText, symbol: "airpods.pro", tint: .teal)
                }

                DayChart(bins: model.history.today.bins(minutes: 15, interval: model.settings.interval), compact: true)
                    .frame(height: 64)

                feedback
            } else {
                calibrationPrompt
            }

            Divider()
            footer
        }
        .padding(16)
        .frame(width: 320)
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: monitor.status)
    }

    private var calibrationPrompt: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lär Hållning hur du sitter")
                .font(.headline)
            Text("Under kalibreringen visar du 10 bra och 10 dåliga hållningar. Det tar ungefär tre minuter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Kalibrera…") { show(AppModel.WindowID.onboarding) }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
        }
    }

    @ViewBuilder
    private var feedback: some View {
        let status = model.monitor.status
        if status == .good || status.isBad || status == .uncertain, model.monitor.lastResult?.vectors.isEmpty == false {
            HStack(spacing: 8) {
                Text("Stämmer inte?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Det här är bra") { model.giveFeedback(.good) }
                    .disabled(status == .good)
                Button("Dålig hållning") { model.giveFeedback(.bad) }
                    .disabled(status.isBad)
            }
            .buttonStyle(.glass)
            .controlSize(.small)
        }
    }

    private var footer: some View {
        HStack {
            Button("Öppna Hållning…") { show(model.isCalibrated ? AppModel.WindowID.main : AppModel.WindowID.onboarding) }
            Spacer()
            PauseMenu()
            Button("Avsluta") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .font(.callout)
    }

    private func show(_ id: String) {
        openWindow(id: id)
        NSApp.activate()
    }
}

/// The figure ring, the status and when the last check happened.
struct StatusHeader: View {
    @Environment(AppModel.self) private var model
    var ringSize: CGFloat = 56

    var body: some View {
        let monitor = model.monitor
        let status = monitor.status
        HStack(spacing: 14) {
            FigureRing(progress: model.history.today.goodFraction ?? 0,
                       slouch: PostureFigure.slouch(for: status),
                       color: status.color, size: ringSize)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.system(size: 17, weight: .semibold))
                    .contentTransition(.opacity)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(detail(now: context.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
            if status.isPaused {
                Button { model.monitor.resume() } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.glass)
                .help("Fortsätt")
            } else if model.isCalibrated {
                Button { model.monitor.checkNow() } label: {
                    Image(systemName: monitor.isChecking ? "camera.fill" : "arrow.clockwise")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .disabled(monitor.isChecking)
                .help("Kontrollera nu")
            }
        }
    }

    private func detail(now: Date) -> String {
        let monitor = model.monitor
        switch monitor.status {
        case .paused, .idle, .noPermission, .error, .cameraBusy:
            return monitor.status.subtitle
        default:
            return "Kontrolleras \(intervalText(model.settings.interval)) · \(relativeTime(monitor.lastCheck, now: now))"
        }
    }
}

struct PauseMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu("Pausa") {
            Button("15 minuter") { model.monitor.pause(for: 15 * 60) }
            Button("30 minuter") { model.monitor.pause(for: 30 * 60) }
            Button("1 timme") { model.monitor.pause(for: 3600) }
            Button("Resten av dagen") { model.monitor.pause(for: nil) }
            if model.monitor.status.isPaused {
                Divider()
                Button("Fortsätt nu") { model.monitor.resume() }
            }
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .fixedSize()
    }
}
