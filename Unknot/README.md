<p align="center">
  <img src="docs/icon.png" width="128" height="128" alt="Unknot app icon: an engraved frog reaching up">
</p>

<h1 align="center">Unknot</h1>

<p align="center">
  <strong>Stretch breaks for your Mac that drop out of the camera notch.</strong>
</p>

<p align="center">
  <a href="https://github.com/Emsurenar/unknot/releases/latest"><img src="https://img.shields.io/github/v/release/Emsurenar/unknot?label=release&color=de6447" alt="Latest release"></a>
  <a href="https://github.com/Emsurenar/unknot/actions/workflows/build.yml"><img src="https://github.com/Emsurenar/unknot/actions/workflows/build.yml/badge.svg" alt="Build status"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-555" alt="macOS 14 or later">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/Emsurenar/unknot?color=555" alt="MIT license"></a>
</p>

<p align="center">
  <a href="https://github.com/Emsurenar/unknot/releases/latest"><strong>Download</strong></a>
  &nbsp;·&nbsp;
  <a href="https://emsurenar.github.io/unknot/">Website</a>
  &nbsp;·&nbsp;
  <a href="CHANGELOG.md">Changelog</a>
  &nbsp;·&nbsp;
  <a href="https://github.com/Emsurenar/unknot/issues">Report an issue</a>
</p>

<p align="center">
  <img src="docs/demo.gif" width="720" alt="A break drops out of the camera notch, shows three stretches, cheers and goes back into the notch">
</p>

Unknot is a small menu bar app that reminds you to move. Every 20 minutes a panel drops out of the notch at the
top of your screen, a member of the Stretch Crew demonstrates three short exercises, and after 30 seconds the
panel slides back. It waits for a pause in your typing and never takes focus, so it doesn't break your train
of thought.

## Highlights

- **Designed for the notch.** Breaks emerge from the camera housing and return to it. On displays without a
  notch they unfold from beneath the menu bar.
- **Fourteen animated exercises** for the neck, shoulders, back, wrists, legs and eyes, each choreographed to
  match the real movement, with live cues such as *Breathe in · 3* and *Switch sides*.
- **Context-aware timing.** Time away counts as a break, sleep resets the countdown, and breaks wait while
  you're on a call or presenting, and for a pause in your typing.
- **The Stretch Crew.** Fifteen hand-engraved characters lead the breaks; keep the ones you like.
- **Native and lightweight.** Written in Swift and SwiftUI: a 2 MB download that uses about 12 MB of memory
  and next to no CPU while it waits, and draws each animation frame in under 1.5 ms.
- **Private by design.** No account, no analytics, no ads. Settings and statistics never leave your Mac.

## Contents

- [Installation](#installation)
- [Using Unknot](#using-unknot)
- [Exercises](#exercises)
- [The Stretch Crew](#the-stretch-crew)
- [Settings](#settings)
- [Privacy and security](#privacy-and-security)
- [FAQ](#faq)
- [Building from source](#building-from-source)
- [Contributing](#contributing)
- [License](#license)

## Installation

| Requirement | |
| --- | --- |
| macOS | 14 Sonoma or later |
| Hardware | Apple silicon or Intel |
| Download size | About 2 MB |

**Terminal (recommended).** Downloads the latest release into `/Applications` and opens it:

```bash
curl -fsSL https://raw.githubusercontent.com/Emsurenar/unknot/main/install.sh | bash
```

**Manual.** Download `Unknot.zip` from the [latest release](https://github.com/Emsurenar/unknot/releases/latest),
unzip it and move **Unknot** to **Applications**.

> [!NOTE]
> Unknot is not signed with a paid Apple Developer ID, so on first launch of a manual download macOS reports
> that it can't verify the developer. Click **Done**, open **System Settings → Privacy & Security** and click
> **Open Anyway**. This is needed only once, and not at all with the Terminal installer.

## Using Unknot

On first launch a welcome window sets the break interval and whether Unknot opens at login, and **Show me a
break** plays one straight away so you know what to expect. From then on the app lives in the menu bar as a
small frog.

<p align="center">
  <img src="docs/welcome.png" width="360" alt="The welcome window: an introduction from a member of the Stretch Crew, the break interval, open at login and a button to try a break">
</p>

<p align="center">
  <img src="docs/break-light.png" width="420" alt="A stretch break in light mode">
  <img src="docs/break-dark.png" width="420" alt="The same break in dark mode">
</p>

During a break, **Done** ends it early and counts it, and **In 5 min** postpones it. Breaks are timed around
what you're doing:

| Situation | What Unknot does |
| --- | --- |
| You've been away from the computer for 5 minutes | Counts it as a break and restarts the countdown |
| The Mac slept or the screen was locked | Restarts the countdown |
| You're in the middle of typing | Waits for a two-second pause, at most a minute |
| Another app is using the microphone or camera | Holds the break until the call ends |
| An app is in full screen (optional) | Holds the break until you leave full screen |
| Outside your working hours (optional) | Stays quiet until they begin |

Unknot only checks how long ago the last key was pressed and whether the microphone or camera is in use,
never what you type or what they record.

The menu bar frog shows the state at a glance: awake, asleep while reminders are paused, smiling during a
break. Its menu shows the next break and your streak, starts a break immediately, and pauses reminders for
30 minutes, 1 hour, 2 hours or the rest of the day.

<p align="center">
  <img src="docs/menubar.png" width="300" alt="The menu bar frog: awake, asleep while paused, and smiling during a break">
</p>

## Exercises

Each break draws exercises from different parts of the body and avoids repeating the previous break. Any
exercise can be turned off in Settings.

| Area | Exercise | Instruction |
| --- | --- | --- |
| **Neck and shoulders** | Neck stretch | Slowly tilt your ear toward your shoulder, right then left |
| | Shoulder rolls | Roll your shoulders backwards in big, slow circles |
| | Shoulder shrugs | Shoulders up to your ears, hold, let them drop |
| | Shoulder stretch | Pull one arm across your chest, switch halfway |
| **Back and chest** | Reach for the sky | Interlace your fingers and stretch your arms straight up |
| | Side bend | One arm overhead, lean to the side, switch halfway |
| | Seated twist | Twist your upper body with one hand on the chair back |
| | Open your chest | Arms out and back, squeeze your shoulder blades |
| | Back hug | Hug yourself and breathe into your back |
| **Arms, hands and legs** | Wrist circles | Roll your wrists slowly in both directions |
| | Shake it out | Shake out your arms and hands |
| | Calf raises | Stand up, rise onto your toes and back down |
| **Eyes and breathing** | Rest your eyes | Look at something at least 6 meters away and blink |
| | Deep breaths | In for four seconds, out for four, shoulders down |

## The Stretch Crew

<p align="center">
  <img src="docs/buddies.png" width="640" alt="The Stretch Crew: Momo the mochi, Miso the cat, Bao the panda, Juni the bunny, Otto the frog, Selma the semla, Pip the chick, Finn the crispbread, Nori the onigiri, Stefan Löfven, Jesus of Nazareth, Mahatma Gandhi, René Descartes, Alexander Bard and Kaknästornet">
</p>

Every character is drawn in code in the style of a small engraving: a single ink line, hatching for shadow and
a soft wash of colour. The historical and public figures are based on photographs and portraits. A random
member leads each break, except on Shrove Tuesday, when Selma the semla leads them all.

## Settings

Open Settings from the menu bar, or by opening Unknot again from Finder or Spotlight.

| General | Stretch Crew |
| --- | --- |
| <img src="docs/settings-general.png" alt="General settings: interval, break length, snooze, language, position, sound"> | <img src="docs/settings-buddies.png" alt="Choose who's on your Stretch Crew"> |

| Exercises | Activity |
| --- | --- |
| <img src="docs/settings-exercises.png" alt="Turn exercises on and off"> | <img src="docs/settings-activity.png" alt="Breaks today, this week, days in a row and a chart of the last 7 days"> |

| Tab | Options |
| --- | --- |
| General | Interval, break length, exercises per break, snooze length, language (English or Swedish), panel position, sound, open at login, automatic updates |
| Stretch Crew | Which characters can lead a break |
| Exercises | Which exercises can come up, grouped by body area |
| Schedule | Working hours, time away, waiting for calls and full screen |
| Activity | Breaks today, this week and in total, your streak, and the last seven days |

## Privacy and security

Unknot collects no data. The only network traffic is an optional check of GitHub's releases API, at most once
a day. Updates are installed only when you choose **Install and Restart**; the download is verified against its
SHA-256 checksum and code signature before it replaces the app. The check can be turned off in
**Settings → General**. See [SECURITY.md](SECURITY.md) for details and for reporting vulnerabilities.

## FAQ

<details>
<summary><strong>The menu bar icon is missing</strong></summary>

On MacBooks with a notch, menu bar icons that don't fit are hidden behind it. Open Unknot again from Finder or
Spotlight to reach Settings, or remove a few other menu bar items.
</details>

<details>
<summary><strong>My Mac has no notch</strong></summary>

The panel unfolds from beneath the menu bar instead. The same applies to external displays. You can also move
it to a corner in **Settings → General → Position on screen**.
</details>

<details>
<summary><strong>How do I update?</strong></summary>

Unknot announces new versions in its menu and installs them with one click. Running the install command again
works as well.
</details>

<details>
<summary><strong>How do I uninstall it?</strong></summary>

This removes the app, its login item, settings and statistics:

```bash
curl -fsSL https://raw.githubusercontent.com/Emsurenar/unknot/main/install.sh | bash -s -- --uninstall
```

To do it by hand, turn off **Open at login**, quit Unknot, move it to the Trash and run
`defaults delete io.github.emsurenar.unknot`.
</details>

## Building from source

The only requirement is the Xcode Command Line Tools (`xcode-select --install`). There are no dependencies and
no Xcode project.

```bash
git clone https://github.com/Emsurenar/unknot.git
cd unknot
./build.sh && open build/Unknot.app
```

`./build.sh --release` produces a universal binary and `dist/Unknot.zip`. Every build checks the translations
and runs the self-test.

## Contributing

Bug reports, ideas and pull requests are welcome. [CONTRIBUTING.md](CONTRIBUTING.md) covers the code layout,
the command-line tools for checking drawings and animations, adding a character or a translation, and the
release process.

## License

Released under the [MIT License](LICENSE). © 2026 Emre Sunar.
