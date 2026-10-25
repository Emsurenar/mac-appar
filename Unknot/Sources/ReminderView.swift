import SwiftUI

enum Brand {
    /// Dynamic Island's orange, a shade deeper on light backgrounds so it stays legible there.
    static func accent(_ dark: Bool) -> Color { dark ? Island.accent : Color(hex: 0xF08A00) }
}

enum BreakOutcome { case completed, snoozed }

/// One stretch break: a few exercises shown one after another, then a short cheer.
@MainActor
final class ReminderSession: NSObject, ObservableObject {
    let exercises: [Exercise]
    let buddy: Buddy
    let cheer = Holidays.isShroveTuesday(Date()) ? L("Happy Semla Day") : L(cheers.randomElement()!)
    let nextMinutes: Int
    let snoozeMinutes: Int
    let total: Double
    @Published var elapsed = 0.0
    /// How far the contents have come into view while the island grows out of the notch, from 0 to 1.
    @Published var reveal: CGFloat = 1
    @Published private(set) var finished = false
    /// Freezes the buddy animation at a given time (used for screenshots).
    var fixedTime: Double?
    /// How long each move really plays, when that differs from the clock (the README animation is sped up).
    var moveDurationOverride: Double?
    var onClose: ((BreakOutcome) -> Void)?

    private var timer: Timer?
    private var startDate = Date()
    /// While the pointer rests on the island the clock stands still, so there's time to read.
    @Published private(set) var held = false
    private var heldSince: Date?
    private var heldFor = 0.0
    private var finishDate = Date()
    /// The move that was showing when the break finished, and for how long.
    private var finishedFrom: (move: Move, ranFor: Double)?
    /// The exercise VoiceOver last read out.
    private var announced = -1

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
    var moveStart: Date { finished ? finishDate : startDate.addingTimeInterval(heldFor + Double(index) * perExercise) }
    var index: Int { min(Int(elapsed / perExercise), exercises.count - 1) }
    /// How far into the current move the buddy is, in seconds.
    var moveTime: Double { fixedTime ?? Date().timeIntervalSince(moveStart) }
    /// The move before the one showing now, so the buddy can blend over from it instead of jumping.
    var previousMove: (move: Move, ranFor: Double)? {
        if finished { return finishedFrom }
        guard index > 0 else { return nil }
        return (exercises[index - 1].move, moveDurationOverride ?? perExercise)
    }
    var current: Exercise { exercises[index] }
    var remaining: Int { max(0, Int((total - elapsed).rounded(.up))) }

    func progress(_ i: Int) -> Double {
        finished ? 1 : min(max((elapsed - Double(i) * perExercise) / perExercise, 0), 1)
    }

    func start() {
        startDate = Date()
        announced = 0
        announce(L("Stretch break with %@", buddy.callName) + ". " + exercises[0].title + ". " + exercises[0].text)
        let t = Timer(timeInterval: 0.05, target: self, selector: #selector(step), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func hold(_ on: Bool) {
        guard fixedTime == nil, !finished, on != held else { return }
        held = on
        if on {
            heldSince = Date()
        } else if let since = heldSince {
            heldFor += Date().timeIntervalSince(since)
            heldSince = nil
        }
    }

    @objc private func step() {
        guard !held else { return }
        elapsed = Date().timeIntervalSince(startDate) - heldFor
        if elapsed >= total { complete(); return }
        if index != announced {
            announced = index
            announce(current.title + ". " + current.text)
        }
    }

    /// The panel never takes focus, so VoiceOver wouldn't notice it: read out the start, each new exercise and
    /// the end instead.
    private func announce(_ text: String) {
        guard fixedTime == nil, NSWorkspace.shared.isVoiceOverEnabled else { return }
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }

    func complete() {
        guard !finished else { return }
        timer?.invalidate()
        finishedFrom = (current.move, elapsed - Double(index) * perExercise)
        finished = true
        finishDate = Date()
        announce(cheer + ". " + L("Next break at %@.", nextBreakTime))
        perform(#selector(closeAfterCheer), with: nil, afterDelay: 2.4)
    }

    func snooze() {
        guard !finished else { return }
        timer?.invalidate()
        onClose?(.snoozed)
    }

    /// Shows the finished state immediately (used for screenshots).
    func markFinishedForPreview() {
        finishedFrom = (current.move, moveDurationOverride ?? perExercise)
        finished = true
        finishDate = Date()
    }

    @objc private func closeAfterCheer() { onClose?(.completed) }
}

/// The contents of a break: the crew member on a paper tile, like the artwork in Dynamic Island, the exercise
/// with its live cues, the progress and the buttons. The black island around it comes from the window.
struct ReminderView: View {
    @ObservedObject var s: ReminderSession
    /// Room at the top for the notch or the menu bar, and at the sides for the island's ears.
    var topInset: CGFloat = 0
    var sideInset: CGFloat = 0

    static let content = CGSize(width: 420, height: 104)
    static let padding: CGFloat = 16

    /// The whole island or panel around the contents.
    static func size(topInset: CGFloat, sideInset: CGFloat) -> CGSize {
        CGSize(width: content.width + padding * 2 + sideInset * 2,
               height: (topInset > 0 ? topInset + 6 : padding) + content.height + padding + 2)
    }

    /// The small label at the top: a live cue while one fits the move, otherwise what this is.
    private var label: String {
        if s.finished { return L("BREAK COMPLETE") }
        return (cue(for: s.current.move, at: s.moveTime) ?? L("Stretch break with %@", s.buddy.callName)).uppercased(with: Localizer.locale)
    }

    private var countdown: String {
        String(format: "%d:%02d", s.remaining / 60, s.remaining % 60)
    }

    var body: some View {
        let size = Self.size(topInset: topInset, sideInset: sideInset)
        VStack(spacing: 0) {
            Color.clear.frame(height: topInset > 0 ? topInset + 6 : Self.padding)
            HStack(alignment: .top, spacing: 14) {
                tile
                VStack(alignment: .leading, spacing: 0) {
                    header
                    words.padding(.top, 4)
                    Spacer(minLength: 6)
                    controls
                }
                .padding(.top, 1)
            }
            .frame(width: Self.content.width, height: Self.content.height)
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onHover { s.hold($0) }
        .modifier(IslandReveal(progress: s.reveal, scale: 0.9))
        .environment(\.colorScheme, .dark)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: s.index)
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: s.finished)
    }

    /// The crew is drawn in ink, so it stands on paper, a little toned down beside the black.
    private var tile: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Pen.paper)
            .overlay(BuddyView(move: s.finished ? .celebrate : s.current.move, buddy: s.buddy,
                               fixedTime: s.fixedTime, epoch: s.moveStart, previous: s.previousMove).padding(4))
            .colorMultiply(Color(hex: 0xF1ECE3))
            .frame(width: Self.content.height, height: Self.content.height)
            .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Island.accent)
                .lineLimit(1)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: label)
            Spacer(minLength: 8)
            if s.held && !s.finished {
                Image(systemName: "pause.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.8))
                    .accessibilityLabel(L("Paused while the pointer is here"))
                    .transition(.opacity)
            } else if !s.finished {
                Text(countdown)
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(Island.tertiary)
                    .accessibilityLabel(L("%ld seconds left", s.remaining))
            }
        }
    }

    private var words: some View {
        Group {
            if s.finished {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.cheer)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(L("Next break at %@.", s.nextBreakTime))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Island.secondary)
                }
                .transition(.islandContent(scale: 0.96))
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.current.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(s.current.text)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Island.secondary)
                        .lineSpacing(1.5)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .id(s.index)
                .transition(.islandContent(scale: 0.96))
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            // One thin track per exercise, filled in white like the sliders in Dynamic Island
            HStack(spacing: 4) {
                ForEach(0..<s.exercises.count, id: \.self) { i in
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.18))
                            Capsule().fill(Color.white.opacity(0.85)).frame(width: g.size.width * s.progress(i))
                        }
                    }
                    .frame(height: 5)
                }
            }
            .accessibilityHidden(true)

            if !s.finished {
                HStack(spacing: 6) {
                    Button(L("In %ld min", s.snoozeMinutes)) { s.snooze() }
                        .buttonStyle(IslandCapsuleStyle())
                        .accessibilityHint(L("Snoozes the break"))
                    Button(L("Done")) { s.complete() }
                        .buttonStyle(IslandCapsuleStyle(prominent: true))
                }
                .transition(.opacity)
            }
        }
        .frame(height: 26)
    }
}
