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
        if let path = value("--filmstrip") { filmstrip(to: path); return true }
        if let path = value("--buddies-image") { buddiesImage(to: path); return true }
        if let path = value("--menubar-icons") { menuBarIcons(to: path); return true }
        if let dir = value("--capture-drop") { captureDrop(in: dir); return true }
        if args.contains("--verify-latest-release") { verifyLatestRelease(); return true }
        if args.contains("--benchmark") { benchmark(); return true }
        if let path = value("--transitions") { transitions(to: path); return true }
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
        // The frog reaching up, engraved on paper, with a soft green field behind it
        let view = ZStack {
            RoundedRectangle(cornerRadius: 186, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0xFBF9F4), Color(hex: 0xEEEAE1)], startPoint: .top, endPoint: .bottom))
                .frame(width: 824, height: 824)
                .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
            Circle().fill(Color(hex: 0xCFE0C3)).frame(width: 520, height: 520).offset(x: 40, y: -10)
            BuddyView(move: .armsUp, buddy: .frog, fixedTime: 2.3).frame(width: 760, height: 760).offset(y: 10)
                .blendMode(.multiply)
        }
        .compositingGroup()
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

    /// Every buddy in a dozen poses: a contact sheet for checking the drawings.
    static func cast(to path: String) {
        // Each move at a telling moment: the top of a reach, the middle of a hold, the peak of a jump
        let moves: [(Move, Double)] = [(.wave, 0.5), (.armsUp, 2.3), (.sideBend, 1.7), (.twist, 1.7),
                                       (.armsWide, 2.4), (.hug, 1.6), (.lookAway, 1.9), (.calfRaise, 1.0), (.celebrate, 0.28),
                                       (.shrug, 1.5), (.crossArm, 1.9), (.crossArm, 5.1)]
        let sheet = VStack(spacing: 0) {
            ForEach(Buddy.allCases) { buddy in
                HStack(spacing: 0) {
                    Text(verbatim: buddy.rawValue).font(.system(size: 13, weight: .semibold)).frame(width: 70, alignment: .leading)
                    ForEach(moves.indices, id: \.self) { i in
                        BuddyView(move: moves[i].0, buddy: buddy, fixedTime: moves[i].1).frame(width: 120, height: 120)
                    }
                }
            }
        }
        .padding(12)
        .background(Pen.paper)
        save(sheet, to: path, scale: 2)
    }

    /// Ten frames across one cycle of each move, for checking that the motion flows.
    static func filmstrip(to path: String) {
        let rows: [(Buddy, Move, Double)] = [(.frog, .armsUp, 4.6), (.frog, .sideBend, 6.4), (.mochi, .twist, 5.6), (.cat, .lookAway, 6.4),
                                             (.semla, .armsWide, 4.8), (.chick, .hug, 3.14), (.toast, .calfRaise, 2.4), (.panda, .breathe, 8),
                                             (.bunny, .wiggle, 1.4), (.cactus, .celebrate, 0.84), (.onigiri, .wristCircles, 1.05), (.frog, .shoulderRoll, 2.2),
                                             (.frog, .shrug, 3.6), (.cat, .crossArm, 6.4)]
        let sheet = VStack(alignment: .leading, spacing: 0) {
            ForEach(rows.indices, id: \.self) { r in
                HStack(spacing: 0) {
                    Text(verbatim: "\(rows[r].0.rawValue) · \(rows[r].1.rawValue)").font(.system(size: 11, weight: .semibold)).frame(width: 120, alignment: .leading)
                    ForEach(0..<10, id: \.self) { k in
                        BuddyView(move: rows[r].1, buddy: rows[r].0, fixedTime: rows[r].2 * Double(k) / 10).frame(width: 100, height: 100)
                    }
                }
            }
        }
        .padding(12)
        .background(Pen.paper)
        save(sheet, to: path, scale: 1.5)
    }

    /// The menu bar icon in each mood, large, on light and dark menu bars.
    static func menuBarIcons(to path: String) {
        let moods: [MenuBarIcon.Mood] = [.awake, .asleep, .happy]
        let row = { (dark: Bool) in
            HStack(spacing: 24) {
                ForEach(moods.indices, id: \.self) { i in
                    Image(nsImage: MenuBarIcon.image(moods[i])).renderingMode(.template)
                        .foregroundStyle(dark ? Color.white : Color.black.opacity(0.85))
                }
            }
            .padding(10)
            .background(dark ? Color(hex: 0x2A2A2C) : Color(hex: 0xECEBEA))
        }
        save(VStack(spacing: 0) { row(false); row(true) }, to: path, scale: 8)
    }

    /// The frames around a change of exercise: the end of one move, then the next one blending in.
    static func transitions(to path: String) {
        let pairs: [(Buddy, Move, Move)] = [(.frog, .twist, .armsUp), (.cat, .lookAway, .hug), (.panda, .hug, .celebrate),
                                            (.semla, .wristCircles, .sideBend), (.chick, .wiggle, .breathe)]
        let ranFor = 10.0
        let sheet = VStack(alignment: .leading, spacing: 0) {
            ForEach(pairs.indices, id: \.self) { r in
                let (buddy, from, to) = pairs[r]
                HStack(spacing: 0) {
                    Text(verbatim: "\(from.rawValue) → \(to.rawValue)").font(.system(size: 11, weight: .semibold)).frame(width: 150, alignment: .leading)
                    ForEach([-0.2, -0.1, 0.0], id: \.self) { dt in
                        BuddyView(move: from, buddy: buddy, fixedTime: ranFor + dt).frame(width: 90, height: 90)
                    }
                    Rectangle().fill(Color.red.opacity(0.5)).frame(width: 1, height: 70)
                    ForEach([0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.7], id: \.self) { t in
                        BuddyView(move: to, buddy: buddy, fixedTime: t, previous: (from, ranFor)).frame(width: 90, height: 90)
                    }
                }
            }
        }
        .padding(12)
        .background(Pen.paper)
        save(sheet, to: path, scale: 1.5)
    }

    /// The whole Stretch Crew waving, with their names, for the README.
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

    /// An animated GIF of one break for the README: it drops out of the notch, shows three exercises
    /// (sped up), cheers, and goes back. The morph uses the same `NotchDrop` as the real window.
    static func gif(to path: String) {
        let picks = [Move.armsUp, .sideBend, .breathe].compactMap { m in allExercises.first { $0.move == m } }
        let s = ReminderSession(exercises: picks, buddy: .frog, nextMinutes: 20, total: 30)
        s.fixedTime = 0
        var frames: [(t: CGFloat, mood: MenuBarIcon.Mood, delay: Double)] = []
        frames.append((0, .awake, 0.9))                                    // the desktop, before
        let morphFPS = 30.0
        for i in 0...Int(NotchDrop.openDuration * morphFPS) {             // out of the notch
            frames.append((CGFloat(Double(i) / (NotchDrop.openDuration * morphFPS)), .happy, 1 / morphFPS))
        }
        let fps = 20.0
        let secondsPerMove = 2.6
        s.moveDurationOverride = secondsPerMove
        let activeFrames = Int(secondsPerMove * fps) * picks.count
        let doneFrames = Int(2.0 * fps)
        let closeFrames = Int(NotchDrop.closeDuration * morphFPS)
        guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.gif.identifier as CFString,
                                                         frames.count + activeFrames + doneFrames + closeFrames + 2, nil) else { return }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        func add(_ t: CGFloat, _ mood: MenuBarIcon.Mood, _ delay: Double) {
            let renderer = ImageRenderer(content: DropScene(session: s, t: t, mood: mood))
            renderer.scale = 1.5
            guard let cg = renderer.cgImage else { return }
            CGImageDestinationAddImage(dest, cg, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
        }
        for f in frames { add(f.t, f.mood, f.delay) }
        let framesPerMove = Int(secondsPerMove * fps)
        for frame in 0..<activeFrames {
            // Each move plays in real time from its start; the progress bar runs faster than the clock
            s.elapsed = Double(frame) / Double(activeFrames) * s.total
            s.fixedTime = Double(frame % framesPerMove) / fps
            add(1, .happy, 1 / fps)
        }
        s.markFinishedForPreview()
        for frame in 0..<doneFrames {
            s.fixedTime = Double(frame) / fps
            add(1, .happy, 1 / fps)
        }
        for i in 0...closeFrames {                                          // and back in
            let k = Double(i) / Double(closeFrames)
            add(CGFloat(1 - k * k * (3 - 2 * k)), .happy, 1 / morphFPS)
        }
        add(0, .awake, 1.2)
        CGImageDestinationFinalize(dest)
    }

    /// Renders the real settings and welcome windows off screen.
    static func settingsScreenshots(in dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        // Be the front app, so switches and the selected tab are drawn in colour. macOS only allows that when
        // the app was opened normally: `open -W -n build/Unknot.app --args --settings-screenshots <dir>`.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        for dark in [false, true] {
            let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            let (window, tabs) = WindowManager.shared.makeSettingsWindow(animatesResize: false)
            window.appearance = appearance
            window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
            window.makeKeyAndOrderFront(nil)
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
        welcome.makeKeyAndOrderFront(nil)
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

    /// Shows a real break at the top center and photographs its window while it opens and closes.
    /// An app may always capture its own windows, so this needs no permissions.
    static func captureDrop(in dir: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let s = ReminderSession(exercises: Array(allExercises.prefix(3)), buddy: .frog, nextMinutes: 20, total: 30)
        let panel = ReminderPanel()
        func shoot(_ name: String) {
            for w in NSApp.windows where w.isVisible {
                if let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(w.windowNumber), [.boundsIgnoreFraming, .bestResolution]) {
                    write(image, to: "\(dir)/\(name).png")
                }
            }
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        let opened = Date()
        panel.show(s, at: .topCenter)
        s.start()
        for t in [0.05, 0.12, 0.2, 0.28, 0.36, 0.45, 0.55, 0.7, 1.5] {
            RunLoop.current.run(until: opened.addingTimeInterval(t))
            shoot(String(format: "open-%.2f", t))
        }
        let closed = Date()
        panel.close()
        for t in [0.1, 0.2, 0.3, 0.4] {
            RunLoop.current.run(until: closed.addingTimeInterval(t))
            shoot(String(format: "close-%.2f", t))
        }
    }

    /// Downloads the latest release the way the updater would, checks it and throws it away again.
    static func verifyLatestRelease() {
        var done = false
        Task {
            do {
                let api = URL(string: "https://api.github.com/repos/\(Updater.repository)/releases/latest")!
                let (data, _) = try await URLSession.shared.data(from: api)
                struct Asset: Decodable { let name: String; let browser_download_url: URL; let digest: String? }
                struct Release: Decodable { let tag_name: String; let assets: [Asset] }
                let release = try JSONDecoder().decode(Release.self, from: data)
                guard let zip = release.assets.first(where: { $0.name == "Unknot.zip" }) else { print("✗ no Unknot.zip"); exit(1) }
                let version = String(release.tag_name.dropFirst())
                let sha = zip.digest.map { String($0.dropFirst(7)) }
                print("→ \(release.tag_name), sha256 \(sha ?? "none")")
                let app = try await Updater.fetch(zip.browser_download_url, sha256: sha, expecting: version)
                print("✓ verified \(app.path)")
                try? FileManager.default.removeItem(at: app.deletingLastPathComponent())
                do {
                    _ = try await Updater.fetch(zip.browser_download_url, sha256: String(repeating: "0", count: 64), expecting: version)
                    print("✗ a wrong checksum was accepted")
                } catch {
                    print("✓ a wrong checksum is refused: \(error.localizedDescription)")
                }
            } catch {
                print("✗ \(error.localizedDescription)")
            }
            done = true
        }
        while !done { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
    }

    /// How long one frame of each crew member takes to draw, at the size of the break panel.
    static func benchmark() {
        let context = CGContext(data: nil, width: 232, height: 232, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        for buddy in Buddy.allCases {
            let frames = 240
            let start = Date()
            for i in 0..<frames {
                let t = Double(i) / 120
                let renderer = ImageRenderer(content: BuddyView(move: allExercises[i % allExercises.count].move, buddy: buddy, fixedTime: t)
                    .frame(width: 116, height: 116))
                renderer.render { _, draw in draw(context) }
            }
            let ms = Date().timeIntervalSince(start) / Double(frames) * 1000
            print(String(format: "%-8@ %.2f ms per frame", buddy.rawValue as NSString, ms))
        }
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
        check(NSSound(named: "Unknot") != nil, "The app's own sound is bundled")

        let notch = CGRect(x: 270, y: 0, width: 185, height: 32)
        let card = CGRect(x: 36, y: 42, width: 404, height: 144)
        let drop = NotchDrop(start: notch, panel: card, fromNotch: true)
        func near(_ a: CGRect, _ b: CGRect) -> Bool {
            abs(a.minX - b.minX) < 0.5 && abs(a.minY - b.minY) < 0.5 && abs(a.width - b.width) < 0.5 && abs(a.height - b.height) < 0.5
        }
        check(near(drop.frame(at: 0).outline.boundingBoxOfPath, notch), "A break starts inside the notch")
        check(near(drop.frame(at: 1).outline.boundingBoxOfPath, card), "A break ends as the panel")
        check(drop.frame(at: 0).ink == 1 && drop.frame(at: 1).ink == 0, "The drop starts black and ends as glass")
        check(drop.frame(at: 0.3).content == 0 && drop.frame(at: 1).content == 1, "The contents appear once it has opened")
        check(stride(from: 0.0, through: 1.0, by: 0.05).allSatisfy { k in
            let stops = NotchDrop.inkStops(CGFloat(k))
            return stops.solid <= stops.clear
        }, "The black drains in order")

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

/// The top of a Mac screen, drawn: wallpaper, menu bar, the camera notch, and a break coming out of it.
struct DropScene: View {
    @ObservedObject var session: ReminderSession
    var t: CGFloat
    var mood: MenuBarIcon.Mood = .awake
    var dark = false

    static let size = CGSize(width: 720, height: 236)
    private let menuBar: CGFloat = 30

    var body: some View {
        let notch = CGRect(x: (Self.size.width - 186) / 2, y: 0, width: 186, height: menuBar)
        let panel = CGRect(x: (Self.size.width - ReminderView.size.width) / 2, y: menuBar + 10,
                           width: ReminderView.size.width, height: ReminderView.size.height)
        let f = NotchDrop(start: notch, panel: panel, fromNotch: true, cornerRadius: ReminderView.cornerRadius).frame(at: t)
        let outline = Path(f.outline)

        ZStack(alignment: .topLeading) {
            LinearGradient(colors: dark ? [Color(hex: 0x2B3036), Color(hex: 0x1B1D21)] : [Color(hex: 0xE6DCD0), Color(hex: 0xC9CDD2)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            // Soft hills, so the glass has something to sit on
            Path { p in
                p.move(to: CGPoint(x: 0, y: 170))
                p.addCurve(to: CGPoint(x: 720, y: 150), control1: CGPoint(x: 220, y: 110), control2: CGPoint(x: 480, y: 210))
                p.addLine(to: CGPoint(x: 720, y: 236)); p.addLine(to: CGPoint(x: 0, y: 236)); p.closeSubpath()
            }
            .fill(dark ? Color(hex: 0x3A4048).opacity(0.7) : Color(hex: 0xB9AFA5).opacity(0.45))

            menuBarView
            // The notch, with the small flares where it meets the top of the screen
            Path(NotchDrop.outline(notch, top: 0, bottom: 10)).fill(Color.black)

            Group {
                outline.fill(dark ? Color(hex: 0x2C2B2B) : Color(hex: 0xF6F5F3))
                    .shadow(color: .black.opacity((dark ? 0.5 : 0.22) * f.shadow), radius: 14, y: 6)
                let stops = NotchDrop.inkStops(f.ink)
                outline.fill(LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: stops.solid),
                                                    .init(color: .black.opacity(0), location: stops.clear)],
                                            startPoint: UnitPoint(x: 0.5, y: f.outline.boundingBoxOfPath.minY / Self.size.height),
                                            endPoint: UnitPoint(x: 0.5, y: f.outline.boundingBoxOfPath.maxY / Self.size.height)))
                ReminderView(s: session)
                    .frame(width: panel.width, height: panel.height)
                    .opacity(f.content)
                    .offset(x: panel.minX, y: panel.minY + f.contentOffset)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
        .environment(\.colorScheme, dark ? .dark : .light)
    }

    private var menuBarView: some View {
        let text = dark ? Color.white.opacity(0.9) : Color.black.opacity(0.82)
        return HStack(spacing: 18) {
            Image(systemName: "apple.logo").font(.system(size: 13, weight: .medium))
            Text(verbatim: "Finder").font(.system(size: 13, weight: .bold))
            ForEach(["File", "Edit", "View", "Go"], id: \.self) { Text(verbatim: $0).font(.system(size: 13)) }
            Spacer()
            Image(nsImage: MenuBarIcon.image(mood)).renderingMode(.template)
            Image(systemName: "wifi").font(.system(size: 13))
            Image(systemName: "battery.75percent").font(.system(size: 15))
            Text(verbatim: "Wed 10:40").font(.system(size: 13))
        }
        .foregroundStyle(text)
        .padding(.horizontal, 16)
        .frame(width: Self.size.width, height: menuBar)
        .background(dark ? Color.black.opacity(0.25) : Color.white.opacity(0.35))
    }
}
