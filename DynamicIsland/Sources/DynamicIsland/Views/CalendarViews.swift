import SwiftUI

// MARK: - Tab

/// The rest of today's events, or tomorrow's once today is done.
struct CalendarTab: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        let calendar = model.calendar
        Group {
            if calendar.access != .granted {
                accessPrompt
            } else if calendar.events.isEmpty {
                emptyState
            } else {
                eventList
            }
        }
        .padding(.top, 4)
    }

    private var eventList: some View {
        let calendar = model.calendar
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(calendar.showsTomorrow ? "Tomorrow" : "Today")
                Spacer()
                Button("Open Calendar") { calendar.openCalendarApp() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.45))
            .frame(height: IslandLayout.sectionHeaderHeight, alignment: .bottom)

            Group {
                if calendar.events.count > IslandLayout.maxCalendarRows {
                    ScrollView(.vertical) { rows }
                        .scrollIndicators(.never)
                } else {
                    rows
                }
            }
            .frame(height: CGFloat(min(calendar.events.count, IslandLayout.maxCalendarRows)) * IslandLayout.calendarRowHeight,
                   alignment: .top)
            .padding(.horizontal, -6)
        }
    }

    private var rows: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(spacing: 0) {
                ForEach(model.calendar.events) { event in
                    EventRow(event: event, now: context.date,
                             onSelect: { model.calendar.openCalendarApp() },
                             onJoin: { model.calendar.join(event) })
                }
            }
        }
    }

    private var accessPrompt: some View {
        let isDenied = model.calendar.access == .denied
        return CalendarMessage(
            title: "Show your calendar here",
            detail: isDenied ? "Allow Dynamic Island under Privacy › Calendars."
                : "Add Google under System Settings › Internet Accounts.",
            action: .init(title: isDenied ? "Open Settings" : "Allow Access") { model.calendar.requestAccess() }
        )
    }

    private var emptyState: some View {
        CalendarMessage(
            title: model.calendar.showsTomorrow ? "Nothing tomorrow either" : "Nothing more today",
            detail: "Upcoming events show up here.",
            action: .init(title: "Open Calendar") { model.calendar.openCalendarApp() }
        )
    }
}

private struct CalendarMessage: View {
    struct Action {
        let title: String
        let perform: () -> Void
    }

    var title: String
    var detail: String
    var action: Action

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.14)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            Button(action.title, action: action.perform)
                .buttonStyle(CapsuleButtonStyle())
        }
        .frame(height: IslandLayout.calendarEmptyHeight - 34)
    }
}

private struct EventRow: View {
    let event: CalendarService.Event
    let now: Date
    let onSelect: () -> Void
    let onJoin: () -> Void
    @State private var isHovering = false

    var body: some View {
        let isNow = event.isHappening(at: now)
        Button(action: onSelect) {
            HStack(spacing: 10) {
                Capsule()
                    .fill(Color(nsColor: event.color))
                    .frame(width: 4, height: 28)
                    .padding(.leading, 4)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                }
                .lineLimit(1)
                Spacer(minLength: 8)
                if let label = relativeLabel(isNow: isNow) {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(isNow ? Color(nsColor: event.color) : .white.opacity(0.75))
                }
                if event.meetingURL != nil {
                    Button("Join", action: onJoin)
                        .buttonStyle(CapsuleButtonStyle(isProminent: isNow || startsSoon))
                }
            }
            .padding(.horizontal, 6)
            .frame(height: IslandLayout.calendarRowHeight)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white.opacity(isHovering ? 0.08 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Show in Calendar")
    }

    private var startsSoon: Bool { event.start.timeIntervalSince(now) <= 5 * 60 }

    private var subtitle: String {
        let time = "\(event.start.formatted(date: .omitted, time: .shortened))–\(event.end.formatted(date: .omitted, time: .shortened))"
        guard let location = event.location, event.meetingURL == nil || !location.contains("://") else { return time }
        return time + " · " + location
    }

    private func relativeLabel(isNow: Bool) -> String? {
        if isNow { return "Now" }
        let minutes = Int((event.start.timeIntervalSince(now) / 60).rounded(.up))
        return minutes < 60 ? "in \(minutes) min" : nil
    }
}

// MARK: - Reminder

/// Shown a few minutes before an event starts.
struct CalendarReminderView: View {
    @Environment(IslandModel.self) private var model
    @State private var ring = false

    var body: some View {
        if let event = model.calendar.reminder {
            let color = Color(nsColor: event.color)
            VStack(spacing: 0) {
                Color.clear.frame(height: model.notch.height)
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(color))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        TimelineView(.periodic(from: .now, by: 15)) { context in
                            Text(detail(for: event, now: context.date))
                                .font(.system(size: 12).monospacedDigit())
                                .foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                    if event.meetingURL != nil {
                        Button("Join") { model.calendar.join(event) }
                            .buttonStyle(CapsuleButtonStyle(isProminent: true))
                    } else {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(color)
                            .symbolEffect(.bounce, value: ring)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .padding(.horizontal, model.earRadius)
            .onAppear { ring = true }
        }
    }

    private func detail(for event: CalendarService.Event, now: Date) -> String {
        let seconds = event.start.timeIntervalSince(now)
        let start = event.start.formatted(date: .omitted, time: .shortened)
        let end = event.end.formatted(date: .omitted, time: .shortened)
        let when = seconds <= 30 ? "Starting now" : "In \(Int((seconds / 60).rounded(.up))) min"
        return "\(when) · \(start)–\(end)"
    }
}

// MARK: - Buttons

struct CapsuleButtonStyle: ButtonStyle {
    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(isProminent ? .black : .white)
            .padding(.horizontal, 10)
            .frame(height: 22)
            .background(Capsule().fill(Color.white.opacity(isProminent ? (configuration.isPressed ? 0.75 : 1)
                                                                       : (configuration.isPressed ? 0.28 : 0.16))))
            .contentShape(Capsule())
    }
}
