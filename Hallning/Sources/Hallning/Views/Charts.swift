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

/// Good and bad minutes over the day as stacked bars.
struct DayChart: View {
    var bins: [TimeBin]
    var compact = false

    var body: some View {
        Chart {
            ForEach(bins) { bin in
                RectangleMark(xStart: .value("Start", bin.start), xEnd: .value("Slut", bin.end),
                              yStart: .value("Minuter", 0.0), yEnd: .value("Minuter", bin.good))
                    .foregroundStyle(by: .value("Hållning", "Bra"))
                    .cornerRadius(2)
                RectangleMark(xStart: .value("Start", bin.start), xEnd: .value("Slut", bin.end),
                              yStart: .value("Minuter", bin.good), yEnd: .value("Minuter", bin.good + bin.bad))
                    .foregroundStyle(by: .value("Hållning", "Dålig"))
                    .cornerRadius(2)
            }
        }
        .chartForegroundStyleScale(["Bra": Color.green, "Dålig": Color.orange])
        .chartLegend(compact ? .hidden : .automatic)
        .chartYAxis(compact ? .hidden : .automatic)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: compact ? 3 : 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .overlay {
            if bins.isEmpty {
                Text("Ingen data än i dag")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Share of good posture per day.
struct WeekChart: View {
    var days: [DayEntry]

    var body: some View {
        Chart {
            ForEach(days) { day in
                if let fraction = day.history?.goodFraction {
                    BarMark(x: .value("Dag", day.date, unit: .day), y: .value("Bra hållning", fraction * 100))
                        .foregroundStyle(fraction >= 0.8 ? Color.green.gradient : (fraction >= 0.6 ? Color.yellow.gradient : Color.orange.gradient))
                        .cornerRadius(5)
                        .annotation(position: .top) {
                            Text("\(Int((fraction * 100).rounded()))")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                }
            }
        }
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisGridLine()
                AxisValueLabel { Text("\(value.as(Int.self) ?? 0) %") }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
            }
        }
    }
}

/// Today's issues as horizontal bars.
struct IssuesChart: View {
    var issues: [IssueCount]

    var body: some View {
        Chart {
            ForEach(issues) { item in
                BarMark(x: .value("Antal", item.count), y: .value("Problem", item.issue.label))
                    .foregroundStyle(Color.orange.gradient)
                    .cornerRadius(4)
            }
        }
        .chartXAxis(.hidden)
        .frame(height: CGFloat(max(issues.count, 1)) * 28)
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
