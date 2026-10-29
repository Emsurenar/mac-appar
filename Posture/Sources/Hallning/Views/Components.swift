import AppKit
import SwiftUI

extension PostureStatus {
    var color: Color {
        switch self {
        case .good: .green
        case .bad: .orange
        case .uncertain: .yellow
        case .away, .idle, .cameraBusy: .secondary
        case .paused: .indigo
        case .noPermission, .error: .red
        }
    }

    /// The colour of the figure icon for this status.
    var figureColor: Color {
        switch self {
        case .good: .green
        case .bad: .orange
        case .uncertain: .yellow
        case .paused: .indigo
        case .noPermission, .error: .red
        default: .gray
        }
    }

    var symbol: String {
        switch self {
        case .good: "checkmark.seal.fill"
        case .bad: "exclamationmark.triangle.fill"
        case .uncertain: "questionmark.circle.fill"
        case .away: "person.fill.questionmark"
        case .idle: "sparkles"
        case .paused: "pause.circle.fill"
        case .cameraBusy: "video.fill"
        case .noPermission: "web.camera.fill"
        case .error: "exclamationmark.octagon.fill"
        }
    }

    /// A one-line explanation under the title.
    var subtitle: String {
        switch self {
        case .idle: "Calibrate to get started"
        case .good: "Keep it up"
        case .bad(let issue): issue.label
        case .uncertain: "This position matches nothing you calibrated"
        case .away: "No one in front of the camera"
        case .paused(let until):
            if let until, until < .distantFuture { "Resumes at \(until.formatted(date: .omitted, time: .shortened))" }
            else if until != nil { "Turn it on again to resume" } else { "The screen is locked or asleep" }
        case .cameraBusy: "Paused during a video call"
        case .noPermission: "Allow access in System Settings"
        case .error(let message): message
        }
    }
}

/// "just now", "12 s ago", "3 min ago".
func relativeTime(_ date: Date?, now: Date = Date()) -> String {
    guard let date else { return "never" }
    let seconds = Int(now.timeIntervalSince(date))
    if seconds < 5 { return "just now" }
    if seconds < 60 { return "\(seconds) s ago" }
    if seconds < 3600 { return "\(seconds / 60) min ago" }
    return date.formatted(date: .omitted, time: .shortened)
}

/// "1:20"
func countdown(_ seconds: TimeInterval) -> String {
    let total = max(Int(seconds.rounded(.up)), 0)
    return String(format: "%d:%02d", total / 60, total % 60)
}

func percent(_ value: Double?) -> String {
    guard let value else { return "–" }
    return "\(Int((value * 100).rounded()))%"
}

/// "every 10 s", "every minute"
func intervalText(_ seconds: Double) -> String {
    let s = Int(seconds.rounded())
    if s == 60 { return "every minute" }
    if s % 60 == 0 { return "every \(s / 60) min" }
    return "every \(s) s"
}

/// A rounded tile with a value and a caption.
struct StatTile: View {
    var title: String
    var value: String
    var symbol: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded).monospacedDigit())
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// The orange bar towards the next reminder.
struct ReminderProgress: View {
    var progress: Double
    var remaining: TimeInterval?
    var title = "Poor posture"

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                if let remaining {
                    Text("Reminder in \(countdown(remaining))")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.orange)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(Color.orange.gradient)
                        .frame(width: max(geometry.size.width * CGFloat(min(max(progress, 0), 1)), 6))
                }
            }
            .frame(height: 6)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: progress)
    }
}

/// The mirrored live camera image with the skeleton on top.
struct LiveCameraView: View {
    @Environment(AppModel.self) private var model
    var cornerRadius: CGFloat = 16

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(0.85))
            if let image = model.previewImage {
                let aspect = CGFloat(image.width) / CGFloat(max(image.height, 1))
                ZStack {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaleEffect(x: -1, y: 1)
                    SkeletonView(pose: model.livePose, color: skeletonColor)
                }
                .aspectRatio(aspect, contentMode: .fit)
            } else {
                ProgressView().controlSize(.small)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { model.beginPreview() }
        .onDisappear { model.endPreview() }
    }

    private var skeletonColor: Color {
        guard let result = model.liveResult else { return .teal }
        if result.isUncertain { return .yellow }
        return result.badProbability >= model.settings.sensitivity.threshold ? .orange : .green
    }
}

/// A feature on a welcome screen: a large tinted symbol, a title and a description.
struct FeatureRow: View {
    var symbol: String
    var tint: Color
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(systemName: symbol)
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension AppModel {
    /// "8° down"
    var neckText: String {
        guard let angle = neckAngle else { return "–" }
        return neckAngleText(angle)
    }

    /// The reminder bar under the status, titled after what is wrong.
    var reminderTitle: String {
        monitor.status.issue == .neckBent ? "Bent neck" : "Poor posture"
    }

    /// "Checked just now · every 10 s", or why nothing is being checked.
    func statusDetail(now: Date) -> String {
        switch monitor.status {
        case .paused, .idle, .noPermission, .error, .cameraBusy:
            return monitor.status.subtitle
        default:
            return "Checked \(relativeTime(monitor.lastCheck, now: now)) · \(intervalText(settings.interval))"
        }
    }

    /// The on/off switch: off pauses until it is turned on again.
    var monitoringBinding: Binding<Bool> {
        Binding(get: { self.monitor.isMonitoring },
                set: { $0 ? self.monitor.resume() : self.monitor.pause(for: .infinity) })
    }
}

/// "Level", "12° down", "4° up"
func neckAngleText(_ angle: Double) -> String {
    let degrees = Int(abs(angle).rounded())
    if degrees < 3 { return "Level" }
    return "\(degrees)° \(angle > 0 ? "down" : "up")"
}

/// The AirPods neck angle on a scale with the limit marked: green below it, orange past it.
struct NeckGauge: View {
    var angle: Double
    var limit: Double
    /// Off where a row above already shows the angle.
    var showsHeader = true

    private var scale: Double { max(30, limit * 2) }

    var body: some View {
        let isBent = angle >= limit
        let tint: Color = isBent ? .orange : .green
        VStack(alignment: .leading, spacing: 7) {
            if showsHeader {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Label("Neck", systemImage: "airpods.pro")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(neckAngleText(angle))
                    .font(.system(.callout, design: .rounded).weight(.semibold).monospacedDigit())
                    .foregroundStyle(isBent ? Color.orange : Color.primary)
                    .contentTransition(.numericText())
                Text("max \(Int(limit.rounded()))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            }
            GeometryReader { geometry in
                let width = geometry.size.width
                let fraction = min(max(angle, 0) / scale, 1)
                let limitX = width * min(limit / scale, 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(tint.gradient)
                        .frame(width: max(width * fraction, 6))
                }
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.primary.opacity(0.55))
                        .frame(width: 2, height: 12)
                        .offset(x: limitX - 1)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 12)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: angle)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Neck angle \(neckAngleText(angle)), limit \(Int(limit.rounded())) degrees")
    }
}
