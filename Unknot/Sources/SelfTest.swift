import AppKit

/// `Unknot --selftest`: quick checks of the logic that's easy to get wrong. build.sh runs it after every build.
@MainActor
extension Snapshot {
    static func selfTest() -> Bool {
        var ok = true
        func check(_ condition: Bool, _ name: String) {
            print(condition ? "✓ \(name)" : "✗ \(name)")
            if !condition { ok = false }
        }

        check(Activity.shouldWaitForTyping(secondsSinceKeyPress: 0.4, waitedFor: 5), "A break waits while you're typing")
        check(!Activity.shouldWaitForTyping(secondsSinceKeyPress: 3, waitedFor: 5), "A break comes in a pause in the typing")
        check(!Activity.shouldWaitForTyping(secondsSinceKeyPress: 0.4, waitedFor: 61), "A break waits for typing a minute at most")
        check(Updater.version(fromTag: "unknot-v1.23.0") == "1.23.0", "Unknot's release tags give its version")
        check(Updater.version(fromTag: "dynamicisland-v2.0.0") == nil && Updater.version(fromTag: "v1.22.0") == nil,
              "Other apps' release tags are ignored")
        check(Updater.isVersion("1.0.1", newerThan: "1.0.0"), "1.0.1 is newer than 1.0.0")
        check(!Updater.isVersion("1.0.0", newerThan: "1.0.0"), "1.0.0 is not newer than itself")
        check(Updater.isVersion("1.10", newerThan: "1.9.9"), "1.10 is newer than 1.9.9")
        check(!Updater.isVersion("0.9", newerThan: "1.0"), "0.9 is older than 1.0")

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        cal.locale = Locale(identifier: "sv_SE")
        func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
        }
        // 19 October 2026 is a Monday, the 24th a Saturday.
        let office = (start: 8 * 60, end: 17 * 60)
        check(WorkHours.contains(date(19, 10), start: office.start, end: office.end, weekdaysOnly: true, calendar: cal),
              "Monday 10:00 is within 08–17")
        check(!WorkHours.contains(date(19, 17, 30), start: office.start, end: office.end, weekdaysOnly: true, calendar: cal),
              "Monday 17:30 is outside 08–17")
        check(!WorkHours.contains(date(24, 10), start: office.start, end: office.end, weekdaysOnly: true, calendar: cal),
              "Saturday is skipped with weekdays only")
        check(WorkHours.contains(date(24, 10), start: office.start, end: office.end, weekdaysOnly: false, calendar: cal),
              "Saturday counts when every day is allowed")
        check(WorkHours.contains(date(19, 23), start: 22 * 60, end: 6 * 60, weekdaysOnly: false, calendar: cal),
              "Night hours wrap past midnight")
        check(WorkHours.nextStart(after: date(23, 18), start: office.start, weekdaysOnly: true, calendar: cal) == date(26, 8),
              "After Friday evening, work resumes Monday 08:00")

        check(Set(allExercises.map(\.id)).count == allExercises.count, "Exercise ids are unique")
        check(Set(Buddy.allCases.map(\.name)).count == Buddy.allCases.count, "Every crew member has their own name")
        let picker = Preferences(defaults: UserDefaults(suiteName: "unknot.selftest.picks.\(UUID().uuidString)")!)
        check((0..<30).allSatisfy { _ in
            let first = picker.exercisesForBreak(count: 3)
            let second = picker.exercisesForBreak(count: 3, avoiding: first)
            return Set(first.map(\.area)).count == 3 && Set(first.map(\.id)).isDisjoint(with: second.map(\.id))
        }, "A break covers three parts of the body, and the next one repeats none of its exercises")
        func day(_ y: Int, _ m: Int, _ d: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: d, hour: 12))! }
        check(Holidays.isShroveTuesday(day(2026, 2, 17), calendar: cal) && Holidays.isShroveTuesday(day(2027, 2, 9), calendar: cal)
              && !Holidays.isShroveTuesday(day(2027, 2, 10), calendar: cal), "Shrove Tuesday falls on the right day")
        let semlaDay = Preferences(defaults: UserDefaults(suiteName: "unknot.selftest.semla.\(UUID().uuidString)")!)
        check((0..<5).allSatisfy { _ in semlaDay.buddyForBreak(avoiding: .semla, on: day(2026, 2, 17)) == .semla },
              "Selma leads every break on Shrove Tuesday")
        check(allExercises.allSatisfy { pose(for: $0.move, at: 0).leftReach == 0 && pose(for: $0.move, at: 0).rightReach == 0 },
              "Every exercise starts with the hands at rest")
        let fromChest = pose(for: .wristCircles, at: 3), toBend = pose(for: .sideBend, at: 1.2)
        check(stride(from: 0.0, through: 1.0, by: 0.05).allSatisfy { k in
            let p = mix(fromChest, toBend, k)
            return p.leftTarget == (k < 0.5 ? fromChest.leftTarget : toBend.leftTarget) || p.leftReach < 0.01
        }, "A hand lets go of one target before reaching for another")
        check(NSSound(named: "Unknot") != nil, "The app's own sound is bundled")

        let notch = CGRect(x: 270, y: 0, width: 185, height: 32)
        let island = CGRect(x: 123, y: 0, width: 480, height: 160)
        let drop = NotchDrop(start: notch, island: island)
        func near(_ a: CGRect, _ b: CGRect) -> Bool {
            abs(a.minX - b.minX) < 0.5 && abs(a.minY - b.minY) < 0.5 && abs(a.width - b.width) < 0.5 && abs(a.height - b.height) < 0.5
        }
        check(near(drop.frame(at: 0).outline.boundingBoxOfPath, notch), "A break starts inside the notch")
        check(near(drop.frame(at: NotchDrop.openDuration).outline.boundingBoxOfPath, island), "A break opens into the island")
        check(near(drop.frame(at: NotchDrop.closeDuration, closing: true).outline.boundingBoxOfPath, notch), "A break closes back into the notch")
        check(stride(from: 0.0, through: NotchDrop.openDuration, by: 0.02).allSatisfy { t in
            drop.frame(at: t).outline.boundingBoxOfPath.minY == 0
        }, "The island hangs from the top of the screen all the way")
        check(drop.frame(at: 0.05).reveal == 0 && drop.frame(at: NotchDrop.openDuration).reveal == 1,
              "The contents arrive once the island has started to open")
        check(abs(Island.spring(3, response: 0.42, damping: 0.74) - 1) < 0.001 && Island.spring(0, response: 0.42, damping: 0.74) == 0,
              "The spring starts at 0 and settles at 1")

        Localizer.apply(.swedish)
        check(L("Stretch now") == "Sträck på dig nu", "Swedish can be chosen in the app")
        Localizer.apply(.english)
        check(L("Stretch now") == "Stretch now", "English can be chosen in the app")
        check(L("%ld minutes", 20) == "20 minutes", "Formatted strings follow the chosen language")
        Localizer.apply(.system)

        let stats = Preferences(defaults: UserDefaults(suiteName: "unknot.selftest.\(UUID().uuidString)")!)
        stats.recordCompletedBreak(at: date(19, 10))
        stats.recordCompletedBreak(at: date(20, 10))
        stats.recordCompletedBreak(at: date(20, 14))
        stats.recordCompletedBreak(at: date(21, 9))
        check(stats.streak(until: date(21, 12), calendar: cal) == 3, "Three days in a row is a streak of 3")
        check(stats.streak(until: date(22, 8), calendar: cal) == 3, "The streak survives the morning before a break")
        check(stats.streak(until: date(23, 8), calendar: cal) == 0, "A day without breaks ends the streak")
        check(stats.recentDays(7, until: date(21, 12), calendar: cal).map(\.count) == [0, 0, 0, 0, 1, 2, 1],
              "The last 7 days are counted per day")
        check(stats.breaksTotal == 4, "All breaks are counted in the total")

        stats.setEnabled(Buddy.cat, false)
        check(!stats.enabledBuddies.contains(.cat), "A buddy can be turned off")
        for buddy in Buddy.allCases where buddy != .crispbread { stats.setEnabled(buddy, false) }
        check(stats.enabledBuddies == [.crispbread], "The last buddy can't be turned off")
        check(stats.randomBuddy(avoiding: .crispbread) == .crispbread, "With one buddy left, it's always that one")
        stats.disabledBuddies = []
        check((0..<20).allSatisfy { _ in stats.randomBuddy(avoiding: .mochi) != .mochi }, "The same buddy never comes twice in a row")

        if let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "sv"),
           let table = NSDictionary(contentsOfFile: path) as? [String: String] {
            let keys = allExercises.flatMap { [$0.titleKey, $0.textKey] } + cheers
            let missing = keys.filter { table[$0] == nil }
            check(missing.isEmpty, "Swedish translations exist for exercises and cheers \(missing.isEmpty ? "" : "\(missing)")")
        } else {
            check(false, "The Swedish strings file is bundled")
        }
        return ok
    }
}
