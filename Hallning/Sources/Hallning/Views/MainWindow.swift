import SwiftUI

/// The panes of the main window, grouped like the System Settings sidebar.
enum MainSection: String, CaseIterable, Identifiable {
    case overview, calibration, reminders, airPods, camera, general

    var id: String { rawValue }

    static let groups: [[MainSection]] = [[.overview, .calibration], [.reminders, .airPods, .camera], [.general]]

    var title: String {
        switch self {
        case .overview: "Overview"
        case .calibration: "Calibration"
        case .reminders: "Reminders"
        case .airPods: "AirPods"
        case .camera: "Camera"
        case .general: "General"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "figure.stand"
        case .calibration: "person.fill.viewfinder"
        case .reminders: "bell.badge.fill"
        case .airPods: "airpods.pro"
        case .camera: "web.camera.fill"
        case .general: "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .overview: .teal
        case .calibration: .green
        case .reminders: .red
        case .airPods: .blue
        case .camera: Color(white: 0.45)
        case .general: .gray
        }
    }
}

struct MainWindow: View {
    @State private var section: MainSection?

    init(section: MainSection = .overview) {
        _section = State(initialValue: section)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                ForEach(Array(MainSection.groups.enumerated()), id: \.offset) { _, group in
                    Section {
                        ForEach(group) { item in
                            Label {
                                Text(item.title)
                            } icon: {
                                if item == .overview {
                                    FigureIcon(size: 20)
                                } else {
                                    SettingsIcon(item.symbol, color: item.color)
                                }
                            }
                            .tag(item)
                        }
                    }
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 215, max: 260)
        } detail: {
            Group {
                switch section ?? .overview {
                case .overview: OverviewPane()
                case .calibration: CalibrationPane()
                case .reminders: RemindersPane()
                case .airPods: AirPodsPane()
                case .camera: CameraPane()
                case .general: GeneralPane()
                }
            }
            .navigationTitle((section ?? .overview).title)
        }
        .frame(minWidth: 760, minHeight: 540)
    }
}

// MARK: - Overview

struct OverviewPane: View {
    @Environment(AppModel.self) private var model
    @State private var range: Range = .today

    enum Range: Hashable { case today, week }

    var body: some View {
        let monitor = model.monitor
        let status = monitor.status
        let today = model.history.today
        Form {
            Section {
                PaneHeader(title: status.title) {
                    FigureIcon(slouch: PostureFigure.slouch(for: status), color: status.figureColor, size: 40)
                } detail: {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(model.statusDetail(now: context.date))
                            .monospacedDigit()
                    }
                } trailing: {
                    Toggle("Posture", isOn: model.monitoringBinding)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }
                if status.isBad {
                    ReminderProgress(progress: monitor.progress, remaining: monitor.remaining, title: model.reminderTitle)
                        .padding(.vertical, 2)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(range == .today ? "Good posture today" : "Daily average")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(percent(range == .today ? today.goodFraction : weekAverage))
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                        Spacer()
                        Picker("Range", selection: $range) {
                            Text("Today").tag(Range.today)
                            Text("Last 7 Days").tag(Range.week)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                    Group {
                        if range == .today {
                            DayChart(bins: today.bins(minutes: 60, interval: model.settings.interval))
                        } else {
                            WeekChart(days: model.history.days(7))
                        }
                    }
                    .frame(height: 150)
                    if range == .today { PostureLegend() }
                }
                .padding(.vertical, 6)
            }

            Section("Today") {
                LabeledContent {
                    Text("\(today.alerts.count)")
                } label: {
                    IconLabel(title: "Reminders", symbol: "bell.fill", color: .red)
                }
                LabeledContent {
                    Text("\(Int(monitor.score.rounded()))")
                } label: {
                    IconLabel(title: "Score right now", symbol: "gauge.with.dots.needle.67percent", color: .teal)
                }
                if let angle = model.neckAngle {
                    VStack(spacing: 10) {
                        LabeledContent {
                            Text("\(neckAngleText(angle)) · max \(Int(model.settings.maxNeckAngle))°")
                                .foregroundStyle(monitor.isNeckBent ? Color.orange : Color.secondary)
                                .monospacedDigit()
                        } label: {
                            IconLabel(title: "Neck angle", symbol: "airpods.pro", color: .blue)
                        }
                        NeckGauge(angle: angle, limit: model.settings.maxNeckAngle, showsHeader: false)
                            .padding(.leading, 30)
                    }
                    .padding(.vertical, 2)
                }
            }

            Section("Most common issues") {
                let issues = today.sortedIssues
                if issues.isEmpty {
                    Text("No poor posture today.")
                        .foregroundStyle(.secondary)
                } else {
                    let top = issues.first?.count ?? 1
                    ForEach(issues.prefix(5)) { item in
                        IssueRow(item: item, maximum: top)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var weekAverage: Double? {
        let values = model.history.days(7).compactMap { $0.history?.goodFraction }
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

/// An issue with a bar for how often it happened today, like Screen Time's app list.
private struct IssueRow: View {
    var item: IssueCount
    var maximum: Int

    var body: some View {
        HStack(spacing: 10) {
            SettingsIcon(item.issue.symbol, color: .orange)
            Text(item.issue.label)
                .frame(width: 170, alignment: .leading)
            GeometryReader { geometry in
                Capsule()
                    .fill(Color.orange.opacity(0.85))
                    .frame(width: max(geometry.size.width * CGFloat(item.count) / CGFloat(max(maximum, 1)), 4), height: 6)
                    .frame(maxHeight: .infinity)
            }
            .frame(height: 20)
            Text(item.count == 1 ? "1 check" : "\(item.count) checks")
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
        }
    }
}

// MARK: - Calibration

struct CalibrationPane: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    private let columns = [GridItem(.adaptive(minimum: 92, maximum: 120), spacing: 12, alignment: .top)]

    var body: some View {
        Form {
            Section {
                PaneHeader(title: "Calibration") {
                    SettingsIcon("person.fill.viewfinder", color: .green, size: 40)
                } detail: {
                    Text(qualityText)
                } trailing: {
                    Button("Recalibrate…") {
                        openWindow(id: AppModel.WindowID.onboarding)
                        NSApp.activate()
                    }
                }
            }
            sampleSection(title: "Good postures", label: .good, color: .green)
            sampleSection(title: "Poor postures", label: .bad, color: .orange)
        }
        .formStyle(.grouped)
    }

    private var qualityText: String {
        let good = model.samples.filter { $0.label == .good }.count
        let corrections = model.samples.filter { $0.source == .feedback }.count
        let counts = "\(good) good and \(model.samples.count - good) poor postures" + (corrections > 0 ? ", \(corrections) from your corrections." : ".")
        guard model.isCalibrated else { return "Posture hasn't learned how you sit yet." }
        if model.isEvaluating { return counts + " Working out the accuracy…" }
        guard let evaluation = model.evaluation, evaluation.total > 0 else { return counts }
        return counts + " Recognises \(evaluation.correct) of \(evaluation.total) when each is left out in turn."
    }

    private func sampleSection(title: String, label: PostureLabel, color: Color) -> some View {
        let samples = model.samples.filter { $0.label == label }
        return Section {
            if samples.isEmpty {
                Text("None yet.").foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(samples) { sample in
                        SampleCell(sample: sample, color: color,
                                   missed: model.evaluation?.misses.contains(sample.id) == true) {
                            model.deleteSample(sample.id)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
        } header: {
            Text(title)
        } footer: {
            if samples.contains(where: { model.evaluation?.misses.contains($0.id) == true }) {
                Label("Marked postures were mistaken for the opposite when left out. Recalibrating them can help.",
                      systemImage: "exclamationmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
        VStack(spacing: 5) {
            PoseThumbnail(pose: sample.pose, color: color)
                .frame(height: 88)
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
                            .help("This posture was mistaken for the opposite when it was left out")
                    }
                }
            Text(caption)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
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
