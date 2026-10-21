import SwiftUI

enum Brand {
    static func accent(_ dark: Bool) -> Color { dark ? Color(hex: 0xF28466) : Color(hex: 0xDE6447) }
}

enum BreakOutcome { case completed, snoozed }

/// One stretch break: a few exercises shown one after another, then a short cheer.
@MainActor
final class ReminderSession: NSObject, ObservableObject {
    let exercises: [Exercise]
    let buddy: Buddy
    let cheer = L(cheers.randomElement()!)
    let nextMinutes: Int
    let snoozeMinutes: Int
    let total: Double
    @Published var elapsed = 0.0
    @Published private(set) var finished = false
    /// Freezes the buddy animation at a given time (used for screenshots).
    var fixedTime: Double?
    var onClose: ((BreakOutcome) -> Void)?

    private var timer: Timer?
    private var startDate = Date()
    private var finishDate = Date()

    init(exercises: [Exercise], buddy: Buddy = .mochi, nextMinutes: Int, snoozeMinutes: Int = 5, total: Double) {
        self.exercises = exercises.isEmpty ? [allExercises[0]] : exercises
        self.buddy = buddy
        self.nextMinutes = nextMinutes
        self.snoozeMinutes = snoozeMinutes
        self.total = total
    }

    var perExercise: Double { total / Double(exercises.count) }
    /// The clock time of the next break, counted from when this one ended.
    var nextBreakTime: String {
        let f = DateFormatter()
        f.locale = Localizer.locale
        f.timeStyle = .short
        return f.string(from: finishDate.addingTimeInterval(Double(nextMinutes) * 60))
    }
    /// When the current move began, so every exercise starts from rest.
    var moveStart: Date { finished ? finishDate : startDate.addingTimeInterval(Double(index) * perExercise) }
    var index: Int { min(Int(elapsed / perExercise), exercises.count - 1) }
    /// How far into the current move the buddy is, in seconds.
    var moveTime: Double { fixedTime ?? Date().timeIntervalSince(moveStart) }
    var current: Exercise { exercises[index] }
    var remaining: Int { max(0, Int((total - elapsed).rounded(.up))) }

    func progress(_ i: Int) -> Double {
        finished ? 1 : min(max((elapsed - Double(i) * perExercise) / perExercise, 0), 1)
    }

    func start() {
        startDate = Date()
        let t = Timer(timeInterval: 0.05, target: self, selector: #selector(step), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func step() {
        elapsed = Date().timeIntervalSince(startDate)
        if elapsed >= total { complete() }
    }

    func complete() {
        guard !finished else { return }
        timer?.invalidate()
        finished = true
        finishDate = Date()
        perform(#selector(closeAfterCheer), with: nil, afterDelay: 2.4)
    }

    func snooze() {
        guard !finished else { return }
        timer?.invalidate()
        onClose?(.snoozed)
    }

    /// Shows the finished state immediately (used for screenshots).
    func markFinishedForPreview() {
        finished = true
        finishDate = Date()
    }

    @objc private func closeAfterCheer() { onClose?(.completed) }
}

struct ActionButtonStyle: ButtonStyle {
    var prominent: Bool
    var accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: prominent ? .semibold : .medium))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(prominent ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, 12)
            .frame(height: 24)
            .background(Capsule().fill(prominent ? AnyShapeStyle(accent) : AnyShapeStyle(Color.primary.opacity(0.08))))
            .overlay(Capsule().fill(Color.black.opacity(configuration.isPressed ? 0.12 : 0)))
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// The content of the reminder. The glass background and shadow come from the window.
struct ReminderView: View {
    @ObservedObject var s: ReminderSession
    @Environment(\.colorScheme) private var scheme

    static let size = CGSize(width: 404, height: 144)
    static let cornerRadius: CGFloat = 22

    private var dark: Bool { scheme == .dark }
    private var accent: Color { Brand.accent(dark) }

    /// The small label at the top: a live cue while one fits the move, otherwise what this is.
    private var label: String {
        if s.finished { return L("BREAK COMPLETE") }
        return cue(for: s.current.move, at: s.moveTime)?.uppercased(with: Localizer.locale) ?? L("STRETCH BREAK")
    }

    private var countdown: String {
        String(format: "%d:%02d", s.remaining / 60, s.remaining % 60)
    }

    var body: some View {
        HStack(spacing: 14) {
            // The crew is drawn in ink, so it always stands on paper, also in dark mode
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Pen.paper)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.black.opacity(dark ? 0 : 0.05)))
                .overlay(BuddyView(move: s.finished ? .celebrate : s.current.move, buddy: s.buddy,
                                   fixedTime: s.fixedTime, epoch: s.moveStart).padding(4))
                .frame(width: 116, height: 116)
                .paperTone(scheme)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label)
                        .font(.system(size: 10.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(accent)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.25), value: label)
                    Spacer()
                    if !s.finished {
                        Text(countdown)
                            .font(.system(size: 11, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel(L("%ld seconds left", s.remaining))
                    }
                }

                Group {
                    if s.finished {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.cheer)
                                .font(.system(size: 17, weight: .semibold))
                                .tracking(-0.2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(L("Next break at %@.", s.nextBreakTime))
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity)
                    } else {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.current.title)
                                .font(.system(size: 17, weight: .semibold))
                                .tracking(-0.2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(s.current.text)
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                                .lineSpacing(1.5)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .id(s.index)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                    }
                }
                .padding(.top, 5)

                Spacer(minLength: 8)

                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        ForEach(0..<s.exercises.count, id: \.self) { i in
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.primary.opacity(0.1))
                                    Capsule().fill(accent).frame(width: g.size.width * s.progress(i))
                                }
                            }
                            .frame(height: 4)
                        }
                    }
                    .accessibilityHidden(true)

                    if !s.finished {
                        HStack(spacing: 6) {
                            Button(L("In %ld min", s.snoozeMinutes)) { s.snooze() }
                                .buttonStyle(ActionButtonStyle(prominent: false, accent: accent))
                                .accessibilityHint(L("Snoozes the break"))
                            Button(L("Done")) { s.complete() }
                                .buttonStyle(ActionButtonStyle(prominent: true, accent: accent))
                        }
                        .transition(.opacity)
                    }
                }
                .frame(height: 24)
            }
        }
        .padding(14)
        .frame(width: Self.size.width, height: Self.size.height)
        .overlay(
            // Circular corners, to match the window's own mask
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .circular)
                .strokeBorder(dark ? Color.white.opacity(0.12) : Color.black.opacity(0.07), lineWidth: 0.5)
        )
        .animation(.easeInOut(duration: 0.3), value: s.index)
        .animation(.easeInOut(duration: 0.3), value: s.finished)
    }
}
