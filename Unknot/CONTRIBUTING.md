# Contributing to Unknot

Unknot is small on purpose: one Swift target, no dependencies, no Xcode project. You need the Command Line
Tools (`xcode-select --install`) and nothing else.

## Build and run

```bash
./build.sh                  # build/Unknot.app for your Mac
./build.sh --release        # a universal app and dist/Unknot.zip
open build/Unknot.app
```

The build checks the translations, draws the app icon from code and runs a self-test
(`build/Unknot.app/Contents/MacOS/Unknot --selftest`). If another copy of Unknot is running, quit it first
or the new one hands over to it and exits.

## Checking your work

The app has a few command-line helpers, so you can look at changes without clicking around:

```bash
U=build/Unknot.app/Contents/MacOS/Unknot
$U --cast cast.png                      # every crew member in nine poses
$U --filmstrip film.png                 # ten frames across one cycle of a dozen moves
$U --transitions changes.png            # the frames around a change of exercise, which should never jump
$U --portraits people.png               # the people in the crew, large, for checking the likeness
$U --previews previews                  # the break panel for every exercise, light and dark
$U --gif demo.gif                       # the README animation: a break dropping out of the notch
$U --settings-screenshots shots         # every settings tab, light and dark, and the welcome window
$U --buddies-image crew.png             # the crew image in the README
$U --menubar-icons icons.png            # the menu bar frog in each mood
$U --capture-drop frames                # photographs a real break window while it opens and closes
$U --verify-latest-release              # downloads and checks the latest release like the updater does
$U --benchmark                          # how long one frame of each crew member takes to draw
```

Add `-AppleLanguages '(sv)'` to any of them to see the Swedish version.

## How the code is laid out

| Path | What's inside |
| --- | --- |
| `Sources/App.swift` | App start, the menu bar item and its menu |
| `Sources/MenuBarIcon.swift` | The menu bar frog, drawn in code |
| `Sources/BreakScheduler.swift` | When a break happens: interval, pauses, working hours, idle time, calls |
| `Sources/ReminderView.swift` | The contents of a break: exercise, progress, buttons |
| `Sources/ReminderPanel.swift`, `NotchDrop.swift` | The floating window, and the shape it takes coming out of the notch |
| `Sources/Exercises.swift` | The exercises and the lines shown when a break is done |
| `Sources/Buddy.swift` | The choreography: one animated pose per exercise |
| `Sources/LineArt.swift` | The engraving renderer: pen, hatching, arms and the animated `BuddyView` |
| `Sources/Crew.swift`, `Buddies.swift` | The Stretch Crew: names, and how each member is drawn |
| `Sources/SettingsView.swift`, `WelcomeView.swift`, `WindowManager.swift` | Settings and the first-launch window |
| `Sources/System.swift` | Login item, moving to Applications, idle, full-screen and call detection |
| `Sources/Updater.swift` | Checking GitHub for a new version and installing it |
| `Sources/Preferences.swift` | All settings and statistics, stored in `UserDefaults` |
| `Sources/Snapshot.swift`, `DropScene.swift` | The command-line helpers above, and the drawn screen in the README animation |
| `Sources/SelfTest.swift` | `--selftest`, run by every build |
| `Resources/*.lproj`, `Resources/Unknot.wav` | Translations, and the break sound (made by `scripts/make_sound.py`) |
| `docs/` | The website at emsurenar.github.io/unknot (`index.html`) and the README images |

## Adding a crew member

Add a case to `Buddy` in `Sources/Buddies.swift` and give it a name. Then draw it in `Sources/Crew.swift`:
a struct that conforms to `CrewArt`, with a body contour, shoulders, an arm style, a face, and details behind,
on and in front of the body. Build shapes once in `init`; the frame passed to each drawing function decides
eyes, mouth and anything that sways. The crew shares the arms and the moves, so a new member can do every
exercise straight away.

Keep to the style: one ink line (2.2) for contours, 1.25 for details, `Hatch.shadow` for the shadow side,
a soft wash and at most one or two stronger colours. Avoid boolean path operations in the per-frame
functions; build those shapes in `init`. Check the result with `--cast` and `--filmstrip`, and add the name
to `Resources/sv.lproj/Localizable.strings`.

## Translations

English is the source language: the strings in the code are the English text, wrapped in `L("…")`. To add a
language, copy `Resources/sv.lproj` to `Resources/<code>.lproj`, translate the right-hand side, add the code
to `CFBundleLocalizations` in `Info.plist` and to `AppLanguage` in `Sources/Localization.swift`, then run
`python3 scripts/check_translations.py`.

## Releasing

1. Bump `CFBundleShortVersionString` in `Info.plist` and add an entry to `CHANGELOG.md`.
2. Regenerate the README images if anything visible changed (see the helpers above).
3. Commit, then tag and push:

   ```bash
   git tag v1.7.0 && git push origin main v1.7.0
   ```

GitHub Actions builds the universal app and attaches `Unknot.zip` to the release. Running copies offer the
update from their menu, and `install.sh` always fetches the latest release.

## Style

Match the code around you: plain Swift and SwiftUI, short comments that explain why, no new dependencies.
Keep the app light and private: no tracking, and nothing that talks to the network except the update check.
