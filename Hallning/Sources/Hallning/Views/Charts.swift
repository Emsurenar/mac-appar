import Charts
import SwiftUI

struct TimeBin: Identifiable {
    var start: Date
    var end: Date
    /// Approximate minutes of good and bad posture.
    var good: Double
    var bad: Double

    var id: Date { start }
}

extension DayHistory {
    /// Groups the per-minute buckets into bins of `minutes`, converting checks to minutes.
    func bins(minutes: Int, interval: Double, on day: Date = Date()) -> [TimeBin] {
        let start = Calendar.current.startOfDay(for: day)
        let perCheck = interval / 60
        var bins: [Int: TimeBin] = [:]
        for bucket in buckets {
            let index = bucket.minute / minutes
            let binStart = start.addingTimeInterval(Double(index * minutes) * 60)
            var bin = bins[index] ?? TimeBin(start: binStart, end: binStart.addingTimeInterval(Double(minutes) * 60), good: 0, bad: 0)
            bin.good += Double(bucket.good) * perCheck
            bin.bad += Double(bucket.bad) * perCheck
            bins[index] = bin
        }
        return bins.keys.sorted().compactMap { bins[$0] }
    }
}

/// Good and poor minutes per hour over the day, like the Screen Time chart.
struct DayChart: View {
    var bins: [TimeBin]
    var compact = false
    var day = Date()

    var body: some View {
        let start = Calendar.current.startOfDay(for: day)
        let end = start.addingTimeInterval(24 * 3600)
        Chart {
            ForEach(bins) { bin in
                BarMark(x: .value("Hour", bin.start, unit: .hour), y: .value("Minutes", bin.good))
                    .foregroundStyle(by: .value("Posture", "Good"))
                    .cornerRadius(compact ? 1.5 : 2.5, style: .continuous)
                BarMark(x: .value("Hour", bin.start, unit: .hour), y: .value("Minutes", bin.bad))
                    .foregroundStyle(by: .value("Posture", "Poor"))
                    .cornerRadius(compact ? 1.5 : 2.5, style: .continuous)
            }
        }
        .chartForegroundStyleScale(["Good": Color.green, "Poor": Color.orange])
        .chartLegend(.hidden)
        .chartXScale(domain: start...end)
        .chartYScale(domain: 0...60)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                if !compact { AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3])) }
                AxisValueLabel(format: .dateTime.hour(.twoDigits(amPM: .omitted)), anchor: .topLeading)
                    .font(.system(size: compact ? 9 : 10))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: compact ? [0] : [0, 30, 60]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: compact ? [] : [2, 3]))
                if !compact {
                    AxisValueLabel { Text("\(value.as(Int.self) ?? 0)m").font(.system(size: 10)) }
                }
            }
        }
        .overlay {
            if bins.isEmpty {
                Text("No data yet today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Share of good posture per day, with the average as a dashed line.
struct WeekChart: View {
    var days: [DayEntry]

    var body: some View {
        let values = days.compactMap { $0.history?.goodFraction }
        let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        Chart {
            ForEach(days) { day in
                if let fraction = day.history?.goodFraction {
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Good posture", fraction * 100), width: .ratio(0.55))
                        .foregroundStyle(Color.green)
                        .cornerRadius(3, style: .continuous)
                }
            }
            if let average {
                RuleMark(y: .value("Average", average * 100))
                    .foregroundStyle(Color.green.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("avg").font(.system(size: 10, weight: .medium)).foregroundStyle(.green)
                    }
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(position: .trailing, values: [0, 50, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%").font(.system(size: 10)) }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    .font(.system(size: 10))
            }
        }
    }
}

/// The legend under the day chart.
struct PostureLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            item("Good", .green)
            item("Poor", .orange)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
    }

    private func item(_ title: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
        }
    }
}

struct IssueCount: Identifiable {
    var issue: PostureIssue
    var count: Int

    var id: PostureIssue { issue }
}

extension DayHistory {
    var sortedIssues: [IssueCount] {
        issues.compactMap { key, count in PostureIssue(rawValue: key).map { IssueCount(issue: $0, count: count) } }
            .sorted { $0.count > $1.count }
    }
}
