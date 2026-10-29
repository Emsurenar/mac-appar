import SwiftUI

/// The menu bar window, laid out like a Control Center module: a title with an on/off
/// switch, the current state, grey section titles and rows that highlight under the pointer.
struct MenuPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @State private var showsPauseOptions = false

    var body: some View {
        let monitor = model.monitor
        let status = monitor.status
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Posture")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Toggle("Posture", isOn: model.monitoringBinding)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .disabled(!model.isCalibrated)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)

            if model.isCalibrated {
                statusRow(status)
                if status.isBad {
                    ReminderProgress(progress: monitor.progress, remaining: monitor.remaining, title: model.reminderTitle)
                        .padding(.horizontal, 8)
                        .padding(.top, 10)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                MenuDivider()
                MenuSectionTitle(title: "Today")
                today
                    .padding(.horizontal, 8)
                    .padding(.top, 6)

                if let angle = model.neckAngle {
                    MenuDivider()
                    NeckGauge(angle: angle, limit: model.settings.maxNeckAngle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                }

                MenuDivider()
                pauseRows
                feedbackRow(status)
            } else {
                calibrationPrompt
            }

            MenuDivider()
            MenuRow("Posture Settings…") {
                show(model.isCalibrated ? AppModel.WindowID.main : AppModel.WindowID.onboarding)
            }
            MenuRow("Quit Posture") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .frame(width: 300)
        .animation(.spring(response: 0.4, dampingFraction: 0.86), value: status)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: showsPauseOptions)
    }

    private func statusRow(_ status: PostureStatus) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(status.figureColor.gradient)
                PostureFigure(slouch: PostureFigure.slouch(for: status))
                    .fill(.white)
                    .padding(6)
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(status.title)
                    .font(.system(size: 13, weight: .medium))
                    .contentTransition(.opacity)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(model.statusDetail(now: context.date))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
    }

    private var today: some View {
        let history = model.history.today
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(percent(history.goodFraction))
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("good posture")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(history.alerts.count == 1 ? "1 reminder" : "\(history.alerts.count) reminders")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            DayChart(bins: history.bins(minutes: 60, interval: model.settings.interval), compact: true)
                .frame(height: 56)
        }
    }

    @ViewBuilder
    private var pauseRows: some View {
        if model.monitor.isMonitoring {
            MenuRow(title: "Pause", symbol: "pause.fill", action: { showsPauseOptions.toggle() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(showsPauseOptions ? 90 : 0))
            }
            if showsPauseOptions {
                VStack(spacing: 0) {
                    MenuRow("For 15 Minutes") { pause(15 * 60) }
                    MenuRow("For 30 Minutes") { pause(30 * 60) }
                    MenuRow("For 1 Hour") { pause(3600) }
                    MenuRow("Until Tomorrow") { pause(nil) }
                }
                .padding(.leading, 24)
                .transition(.opacity)
            }
        } else {
            MenuRow("Resume", symbol: "play.fill") { model.monitor.resume() }
        }
    }

    /// "Not right?": lets the user correct the latest check.
    @ViewBuilder
    private func feedbackRow(_ status: PostureStatus) -> some View {
        if model.monitor.lastResult?.vectors.isEmpty == false {
            if status == .good {
                MenuRow("Mark as Poor Posture", symbol: "hand.thumbsdown") { model.giveFeedback(.bad) }
            } else if status.isBad && status.issue != .neckBent {
                MenuRow("Mark as Good Posture", symbol: "hand.thumbsup") { model.giveFeedback(.good) }
            }
        }
    }

    private var calibrationPrompt: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Teach Posture how you sit")
                .font(.system(size: 13, weight: .medium))
            Text("Show 10 good and 10 poor postures. It takes about three minutes.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Calibrate…") { show(AppModel.WindowID.onboarding) }
                .buttonStyle(.glassProminent)
                .padding(.top, 8)
        }
        .padding(.horizontal, 8)
    }

    private func pause(_ duration: TimeInterval?) {
        showsPauseOptions = false
        model.monitor.pause(for: duration)
    }

    private func show(_ id: String) {
        openWindow(id: id)
        NSApp.activate()
    }
}
