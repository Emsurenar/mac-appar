<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Sträckis app icon">
</p>

<h1 align="center">Sträckis</h1>

<p align="center">
  A tiny friend in your Mac's menu bar that reminds you to get up and stretch.
</p>

<p align="center">
  <a href="https://github.com/Emsurenar/strackis/releases/latest"><strong>Download for macOS</strong></a>
  &nbsp;·&nbsp; macOS 13 or later &nbsp;·&nbsp; Apple silicon and Intel &nbsp;·&nbsp; Free and open source
</p>

<p align="center">
  <img src="docs/demo.gif" width="460" alt="A stretch break: the buddy shows three exercises, then cheers">
</p>

Every 20 minutes a small glass panel slides into the corner of your screen. A little mochi buddy
demonstrates a few quick exercises, a progress bar counts down, and after 30 seconds it's gone again.
It never steals focus, so you can keep typing if you really have to.

The name is a playful Swedish take on *sträcka på sig*, "to stretch".

## Features

- **Gentle breaks.** A non-activating panel in the corner of your screen, light and dark mode, sound optional.
- **12 animated exercises.** Each break picks a few at random. Turn off the ones you don't like.
- **Smart timing.** Time away from the computer counts as a break. Sleep and a locked screen restart the countdown.
  Optional working hours, and Sträckis can wait while an app is in full screen (presentations, calls, movies).
- **A quiet menu bar icon.** See when the next break is, stretch now, or pause for 30 minutes, an hour, two hours
  or the rest of the day.
- **See your progress.** Breaks today, this week, days in a row and a chart of the last seven days.
- **Native and tiny.** About 1 MB, written in Swift and SwiftUI. No account, no tracking, no ads.
- **English and Swedish**, following your Mac's language.

<p align="center">
  <img src="docs/break-light.png" width="420" alt="A stretch break in light mode">
  <img src="docs/break-dark.png" width="420" alt="A stretch break in dark mode">
</p>

## Install

**One line in Terminal** (downloads the latest release into Applications and opens it):

```bash
curl -fsSL https://raw.githubusercontent.com/Emsurenar/strackis/main/install.sh | bash
```

**Or download it yourself:**

1. Download `Strackis.zip` from the [latest release](https://github.com/Emsurenar/strackis/releases/latest) and unzip it.
2. Drag **Sträckis** into your **Applications** folder and open it.
3. The first time, macOS says it can't verify the developer, because Sträckis isn't signed with a paid
   Apple Developer ID. Click **Done**, open **System Settings → Privacy & Security**, scroll down and click
   **Open Anyway**. You only need to do this once.

A welcome window shows up on first launch. From then on Sträckis lives in the menu bar.

<p align="center">
  <img src="docs/welcome.png" width="320" alt="The welcome window on first launch">
</p>

## Settings

Click the menu bar icon and choose **Settings…**, or open the app again from Finder or Spotlight.

| General | Exercises |
| --- | --- |
| <img src="docs/settings-general.png" alt="General settings"> | <img src="docs/settings-exercises.png" alt="Exercise settings"> |

| Schedule | Activity |
| --- | --- |
| <img src="docs/settings-schedule.png" alt="Schedule settings"> | <img src="docs/settings-activity.png" alt="Activity: today, this week, streak and a chart of the last 7 days"> |

- **General:** how often, how long, how many exercises per break, how long to snooze, position on screen,
  a countdown in the menu bar, sound, open at login and update checks.
- **Exercises:** choose which exercises can come up. Hover over one to watch the movement.
- **Schedule:** working hours and smart pauses.
- **Activity:** your breaks today, this week, days in a row and all time, with a chart of the last seven days.

Can't see the menu bar icon, for example because it's hidden behind the camera notch? Open Sträckis again from
Finder or Spotlight and the settings appear.

## Privacy

Sträckis doesn't collect anything. Settings and statistics stay on your Mac. The only network request is an
optional check of GitHub's releases API, at most once a day, to tell you about new versions. You can turn it
off under **Settings → General**. Nothing is ever downloaded or installed automatically.

## Build from source

You need Xcode or the Command Line Tools (`xcode-select --install`). There are no dependencies.

```bash
git clone https://github.com/Emsurenar/strackis.git
cd strackis
./build.sh
open "build/Sträckis.app"
```

`./build.sh --release` builds a universal app and `dist/Strackis.zip`. The build also checks the
translations and runs a small self-test (`Sträckis --selftest`).

| Path | What's inside |
| --- | --- |
| `Sources/App.swift` | App start, menu bar icon and menu |
| `Sources/BreakScheduler.swift` | When to show a break: interval, pauses, working hours, idle time |
| `Sources/ReminderView.swift`, `ReminderPanel.swift` | The break itself and its floating glass window |
| `Sources/Buddy.swift` | The buddy and its poses, drawn with SwiftUI `Canvas` |
| `Sources/SettingsView.swift`, `WelcomeView.swift`, `WindowManager.swift` | Settings and first-launch windows |
| `Sources/System.swift` | Login item, moving to Applications, idle and full-screen detection |
| `Sources/Preferences.swift` | All settings, stored in `UserDefaults` |
| `Resources/*.lproj` | Translations |

## Translations

English is the source language: the strings in the code are the English text. To add a language:

1. Copy `Resources/sv.lproj` to `Resources/<code>.lproj` and translate the right-hand side.
2. Add the code to `CFBundleLocalizations` in `Info.plist`.
3. Run `python3 scripts/check_translations.py` to find missing strings, then open a pull request.

## Releasing

Bump `CFBundleShortVersionString` in `Info.plist`, add an entry to `CHANGELOG.md`, then tag and push:

```bash
git tag v1.0.1 && git push origin v1.0.1
```

GitHub Actions builds the universal app and attaches `Strackis.zip` to the release.

## Uninstall

Choose **Quit Sträckis** in the menu, turn off **Open at login** first if you enabled it, and drag the app to
the Trash. To remove its settings as well:

```bash
defaults delete io.github.emsurenar.strackis
```

## På svenska

Sträckis är en liten kompis i menyraden som påminner dig om att sträcka på dig. Var 20:e minut glider en ruta
in i hörnet och figuren visar några snabba övningar. Appen följer din Macs språk och finns på svenska och
engelska. Ladda ned den under [Releases](https://github.com/Emsurenar/strackis/releases/latest).

## License

[MIT](LICENSE) © 2026 Emre Sunar
