import SwiftUI

enum MainSection: String, CaseIterable, Identifiable {
    case overview, calibration, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .calibration: "Calibration"
        case .settings: "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "chart.bar.xaxis"
        case .calibration: "person.fill.viewfinder"
        case .settings: "gearshape"
        }
    }
}

struct MainWindow: View {
    @State private var section: MainSection? = .overview

    var body: some View {
        NavigationSplitView {
            List(MainSection.allCases, selection: $section) { section in
                Label(section.title, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            switch section ?? .overview {
            case .overview: OverviewView()
            case .calibration: CalibrationView()
            case .settings: SettingsView()
            }
        }
        .frame(minWidth: 760, minHeight: 540)
    }
}

// MARK: - Overview

struct OverviewView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings
        let today = model.history.today
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                card {
                    VStack(alignment: .leading, spacing: 12) {
                        StatusHeader(ringSize: 72)
                        if model.monitor.status.isBad {
                            ReminderProgress(progress: model.monitor.progress, remaining: model.monitor.remaining,
                                             title: model.reminderTitle)
                        }
                        HStack(spacing: 10) {
                            StatTile(title: "Good posture today", value: percent(today.goodFraction), symbol: "figure.stand", tint: .green)
                            StatTile(title: "Score right now", value: "\(Int(model.monitor.score.rounded()))", symbol: "sparkles", tint: .teal)
                            StatTile(title: "Reminders today", value: "\(today.alerts.count)", symbol: "bell.fill", tint: .orange)
                            StatTile(title: model.neckAngle == nil ? "No AirPods – camera only" : "Neck (AirPods)",
                                     value: model.neckText, symbol: "airpods.pro",
                                     tint: model.monitor.isNeckBent ? .orange : .blue)
                        }
                        if let angle = model.neckAngle {
                            NeckGauge(angle: angle, limit: model.settings.maxNeckAngle)
                                .padding(.top, 2)
                        }
                    }
                }

                card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Live").font(.headline)
                            Spacer()
                            Toggle("Show camera", isOn: $settings.showLiveCamera)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        if settings.showLiveCamera {
                            LiveCameraView()
                                .frame(height: 280)
                            Text("The image is only shown here and is never saved.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                card {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Today").font(.headline)
                        DayChart(bins: today.bins(minutes: 15, interval: model.settings.interval))
                            .frame(height: 180)
                    }
                }

                HStack(alignment: .top, spacing: 18) {
                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Last 7 days").font(.headline)
                            WeekChart(days: model.history.days(7))
                                .frame(height: 150)
                        }
                    }
                    card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Today's issues").font(.headline)
                            let issues = today.sortedIssues
                            if issues.isEmpty {
                                Text("No poor posture today.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                            } else {
                                IssuesChart(issues: Array(issues.prefix(5)))
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Overview")
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Calibration

struct CalibrationView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: model.isCalibrated ? "checkmark.seal.fill" : "person.fill.viewfinder")
                        .font(.system(size: 30))
                        .foregroundStyle(model.isCalibrated ? Color.green : Color.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Model quality").font(.headline)
                        Text(qualityText)
                            .foregroundStyle(.secondary)
                        let good = model.samples.filter { $0.label == .good }.count
                        let bad = model.samples.count - good
                        Text("\(good) good and \(bad) poor postures · \(model.samples.filter { $0.source == .feedback }.count) from your corrections")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Recalibrate…") {
                        openWindow(id: AppModel.WindowID.onboarding)
                        NSApp.activate()
                    }
                    .buttonStyle(.glassProminent)
                }

                sampleGrid(title: "Good postures", label: .good, color: .green)
                sampleGrid(title: "Poor postures", label: .bad, color: .orange)
            }
            .padding(24)
        }
        .navigationTitle("Calibration")
    }

    private var qualityText: String {
        guard model.isCalibrated else { return "Not calibrated yet." }
        if model.isEvaluating { return "Working out the accuracy…" }
        guard let evaluation = model.evaluation, evaluation.total > 0 else { return "The accuracy could not be calculated." }
        return "Accuracy: \(evaluation.correct) of \(evaluation.total) poses (tested by leaving out one pose at a time)."
    }

    @ViewBuilder
    private func sampleGrid(title: String, label: PostureLabel, color: Color) -> some View {
        let samples = model.samples.filter { $0.label == label }
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            if samples.isEmpty {
                Text("None yet.").foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(samples) { sample in
                        SampleCell(sample: sample, color: color,
                                   missed: model.evaluation?.misses.contains(sample.id) == true) {
                            model.deleteSample(sample.id)
                        }
                    }
                }
            }
        }
    }
}

private struct SampleCell: View {
    let sample: CalibrationSample
    let color: Color
    let missed: Bool
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 6) {
            PoseThumbnail(pose: sample.pose, color: color)
                .frame(height: 96)
                .overlay(alignment: .topTrailing) {
                    if isHovering {
                        Button(action: onDelete) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .symbolRenderingMode(.hierarchical)
                        }
                        .buttonStyle(.plain)
                        .padding(5)
                        .help("Delete")
                    }
                }
                .overlay(alignment: .topLeading) {
                    if missed {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.yellow)
                            .padding(5)
                            .help("This pose was misclassified when it was left out")
                    }
                }
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private var caption: String {
        if let issue = sample.issue { return issue.label }
        if sample.source == .feedback { return "Correction" }
        return sample.promptIndex >= 0 && sample.promptIndex < OnboardingPrompt.good.count
            ? OnboardingPrompt.good[sample.promptIndex].title : "Good"
    }
}
