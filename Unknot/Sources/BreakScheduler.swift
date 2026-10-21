import AppKit

/// Decides when the next stretch break happens and shows it.
@MainActor
final class BreakScheduler: NSObject {
    enum Status {
        case upcoming(minutes: Int)
        case inBreak
        case paused(until: Date)
        case outsideWorkHours(resumes: Date?)
    }

    private(set) var nextBreak = Date()
    private(set) var pausedUntil: Date?
    private(set) var session: ReminderSession?
    /// Called once a second and whenever the state changes, to refresh the menu bar.
    var onChange: (() -> Void)?

    private let prefs = Preferences.shared
    private let panel = ReminderPanel()

    func start() {
        reschedule()
        let timer = Timer(timeInterval: 1, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)

        // Sleep or a locked screen already counts as a break: start the countdown over.
        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(restartCountdown), name: NSWorkspace.didWakeNotification, object: nil)
        ws.addObserver(self, selector: #selector(restartCountdown), name: NSWorkspace.screensDidWakeNotification, object: nil)
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(restartCountdown),
                                                            name: .init("com.apple.screenIsUnlocked"), object: nil)
    }

    var status: Status {
        if session != nil { return .inBreak }
        if let until = pausedUntil { return .paused(until: until) }
        if prefs.workHoursEnabled && !isWithinWorkHours(Date()) {
            return .outsideWorkHours(resumes: WorkHours.nextStart(after: Date(), start: prefs.workStartMinutes,
                                                                  weekdaysOnly: prefs.weekdaysOnly))
        }
        return .upcoming(minutes: max(0, Int((nextBreak.timeIntervalSinceNow / 60).rounded(.up))))
    }

    func reschedule(afterMinutes minutes: Int? = nil) {
        nextBreak = Date().addingTimeInterval(Double(minutes ?? prefs.intervalMinutes) * 60)
        onChange?()
    }

    func pause(minutes: Int) {
        pausedUntil = Date().addingTimeInterval(Double(minutes) * 60)
        onChange?()
    }

    func pauseForRestOfDay() {
        let cal = Calendar.current
        pausedUntil = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))
        onChange?()
    }

    func resume() {
        pausedUntil = nil
        reschedule()
    }

    func showBreakNow() {
        guard session == nil else { return }
        let picks = Array(prefs.enabledExercises.shuffled().prefix(prefs.exercisesPerBreak))
        let s = ReminderSession(exercises: picks, nextMinutes: prefs.intervalMinutes,
                                snoozeMinutes: prefs.snoozeMinutes, total: Double(prefs.breakSeconds))
        s.onClose = { [weak self] outcome in
            guard let self else { return }
            if outcome == .completed { self.prefs.recordCompletedBreak() }
            self.panel.close()
            self.session = nil
            self.reschedule(afterMinutes: outcome == .snoozed ? s.snoozeMinutes : nil)
        }
        session = s
        panel.show(s, at: prefs.position)
        if prefs.soundEnabled { NSSound(named: prefs.soundName)?.play() }
        s.start()
        onChange?()
    }

    private func isWithinWorkHours(_ date: Date) -> Bool {
        WorkHours.contains(date, start: prefs.workStartMinutes, end: prefs.workEndMinutes, weekdaysOnly: prefs.weekdaysOnly)
    }

    @objc private func restartCountdown() {
        if session == nil { reschedule() }
    }

    @objc private func tick() {
        defer { onChange?() }

        if let until = pausedUntil {
            guard Date() >= until else { return }
            pausedUntil = nil
            reschedule()
        }
        guard session == nil else { return }

        // Outside working hours, display off or away from the computer: keep the full interval ready for later.
        if Activity.displayIsAsleep || (prefs.workHoursEnabled && !isWithinWorkHours(Date())) {
            reschedule()
            return
        }
        if prefs.countAwayAsBreak && Activity.secondsSinceLastInput >= Double(prefs.awayMinutes * 60) {
            reschedule()
            return
        }

        guard Date() >= nextBreak else { return }
        if prefs.waitForFullscreen && Activity.frontmostAppIsFullscreen {
            nextBreak = Date().addingTimeInterval(30)
            return
        }
        showBreakNow()
    }
}
