import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// Command-line helpers used by build.sh and for the README images:
///   --icon <file.png>, --previews <dir>, --gif <file.gif>, --settings-screenshots <dir>, --selftest
@MainActor
enum Snapshot {
    static func run(_ args: [String]) -> Bool {
        func value(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        if let path = value("--icon") { icon(to: path); return true }
        if let dir = value("--previews") { previews(in: dir); return true }
        if let path = value("--gif") { gif(to: path); return true }
        if let dir = value("--settings-screenshots") { settingsScreenshots(in: dir); return true }
        if let path = value("--cast") { cast(to: path); return true }
        if let path = value("--buddies-image") { buddiesImage(to: path); return true }
        if args.contains("--selftest") { exit(selfTest() ? 0 : 1) }
        return false
    }

    // MARK: Images

    static func save<V: View>(_ view: V, to path: String, scale: CGFloat = 2) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let cg = renderer.cgImage else { print("Could not render \(path)"); return }
        write(cg, to: path)
    }

    static func write(_ image: CGImage, to path: String) {
        guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }

    /// Roughly how the reminder looks on screen: the glass is replaced by a flat surface.
    static func framed<V: View>(_ view: V, dark: Bool) -> some View {
        view
            .background(RoundedRectangle(cornerRadius: ReminderView.cornerRadius)
                .fill(dark ? Color(hex: 0x2C2B2B) : Color(hex: 0xF6F5F3)))
            .compositingGroup()
            .shadow(color: .black.opacity(dark ? 0.5 : 0.16), radius: 14, y: 5)
            .padding(28)
            .background(LinearGradient(colors: dark ? [Color(hex: 0x1D1E22), Color(hex: 0x131416)]
                                                    : [Color(hex: 0xEAE6E1), Color(hex: 0xDAD5CF)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .environment(\.colorScheme, dark ? .dark : .light)
    }

    static func icon(to path: String) {
        let view = ZStack {
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFFF7EE), Color(hex: 0xFFDCC4)], startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
            Circle().fill(Brand.accent(false).opacity(0.12)).frame(width: 560, height: 560).offset(y: 40)
            BuddyView(move: .armsUp, fixedTime: 0.98).frame(width: 660, height: 660).offset(y: 6)
        }
        .frame(width: 1024, height: 1024)
        save(view, to: path, scale: 1)
    }

    static func previews(in dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for (i, exercise) in allExercises.enumerated() {
            let others = allExercises.filter { $0.id != exercise.id }.prefix(2)
            let s = ReminderSession(exercises: [exercise] + others, nextMinutes: 20, total: 30)
            s.elapsed = 3.4
            s.fixedTime = 1.1 + Double(i) * 0.37
            save(framed(ReminderView(s: s), dark: false), to: "\(dir)/card-\(exercise.id).png")
            save(framed(ReminderView(s: s), dark: true), to: "\(dir)/card-\(exercise.id)-dark.png")
        }
        let done = ReminderSession(exercises: Array(allExercises.prefix(3)), nextMinutes: 20, total: 30)
        done.markFinishedForPreview()
        done.fixedTime = 0.3
        save(framed(ReminderView(s: done), dark: false), to: "\(dir)/card-done.png")
    }

    /// Every buddy in a few poses: a contact sheet for checking the drawings.
    static func cast(to path: String) {
        let moves: [(Move, Double)] = [(.wave, 0.4), (.armsUp, 1.0), (.sideBend, 1.3), (.hug, 0.5), (.lookAway, 2.0), (.celebrate, 0.31)]
        let sheet = VStack(spacing: 0) {
            ForEach(Buddy.allCases) { buddy in
                HStack(spacing: 0) {
                    Text(verbatim: buddy.rawValue).font(.system(size: 13, weight: .semibold)).frame(width: 70, alignment: .leading)
                    ForEach(moves.indices, id: \.self) { i in
                        BuddyView(move: moves[i].0, buddy: buddy, fixedTime: 100 + moves[i].1).frame(width: 120, height: 120)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(hex: 0xF4F3F1))
        save(sheet, to: path, scale: 2)
    }

    /// All buddies waving, with their names, for the README.
    static func buddiesImage(to path: String) {
        let rows = [Array(Buddy.allCases.prefix(5)), Array(Buddy.allCases.dropFirst(5))]
        let image = VStack(spacing: 6) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 6) {
                    ForEach(Array(rows[r].enumerated()), id: \.element) { i, buddy in
                        VStack(spacing: 0) {
                            BuddyView(move: .wave, buddy: buddy, fixedTime: 0.4 + Double(r * 5 + i) * 0.41)
                                .frame(width: 130, height: 130)
                            Text(buddy.name)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color(hex: 0x4A403A))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(LinearGradient(colors: [Color(hex: 0xFBF8F4), Color(hex: 0xF1ECE6)], startPoint: .top, endPoint: .bottom)))
        .environment(\.colorScheme, .light)
        save(image, to: path)
    }

    /// An animated GIF of one break, sped up, for the README.
    static func gif(to path: String) {
        let picks = [Move.armsUp, .sideBend, .breathe].compactMap { m in allExercises.first { $0.move == m } }
        let s = ReminderSession(exercises: picks, nextMinutes: 20, total: 30)
        let fps = 12.0
        let activeFrames = Int(2.6 * Double(picks.count) * fps)
        let doneFrames = Int(2.2 * fps)
        guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL,
                                                         UTType.gif.identifier as CFString,
                                                         activeFrames + doneFrames, nil) else { return }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary
        for frame in 0..<(activeFrames + doneFrames) {
            let t = Double(frame) / fps
            if frame < activeFrames {
                s.elapsed = Double(frame) / Double(activeFrames) * s.total
            } else {
                s.markFinishedForPreview()
            }
            s.fixedTime = 200 + t
            let renderer = ImageRenderer(content: framed(ReminderView(s: s), dark: false))
            renderer.scale = 1.5
            if let cg = renderer.cgImage { CGImageDestinationAddImage(dest, cg, frameProperties) }
        }
        CGImageDestinationFinalize(dest)
    }

    /// Renders the real settings and welcome windows off screen.
    static func settingsScreenshots(in dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for dark in [false, true] {
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let (window, tabs) = WindowManager.shared.makeSettingsWindow(animatesResize: false)
            window.appearance = appearance
            window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
            window.orderFrontRegardless()
            for tab in SettingsTab.allCases {
                tabs.selectedTabViewItemIndex = tab.rawValue
                capture(window, to: "\(dir)/settings-\(tab)\(dark ? "-dark" : "").png")
            }
            window.orderOut(nil)
        }

        let welcome = NSWindow(contentViewController: NSHostingController(rootView: WelcomeView(onTryBreak: {}, onDone: {})))
        welcome.styleMask = [.titled, .closable, .fullSizeContentView]
        welcome.titlebarAppearsTransparent = true
        welcome.titleVisibility = .hidden
        welcome.appearance = NSAppearance(named: .aqua)
        welcome.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        welcome.orderFrontRegardless()
        capture(welcome, to: "\(dir)/welcome.png")
    }

    private static func capture(_ window: NSWindow, to path: String) {
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))
        guard let frameView = window.contentView?.superview else { return }
        frameView.layoutSubtreeIfNeeded()
        guard let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) else { return }
        frameView.cacheDisplay(in: frameView.bounds, to: rep)
        if let cg = rep.cgImage { write(cg, to: path) }
    }

    // MARK: Self-test

    static func selfTest() -> Bool {
        var ok = true
        func check(_ condition: Bool, _ name: String) {
            print(condition ? "✓ \(name)" : "✗ \(name)")
            if !condition { ok = false }
        }

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
        for buddy in Buddy.allCases where buddy != .toast { stats.setEnabled(buddy, false) }
        check(stats.enabledBuddies == [.toast], "The last buddy can't be turned off")
        check(stats.randomBuddy(avoiding: .toast) == .toast, "With one buddy left, it's always that one")
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
