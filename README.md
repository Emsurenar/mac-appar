<h1 align="center">mac-appar</h1>

<p align="center">
  Three native macOS apps written in Swift and SwiftUI.<br>
  No Xcode project: each app builds with a one-line script.
</p>

<p align="center">
  <a href="https://github.com/Emsurenar/mac-appar/actions/workflows/build.yml"><img src="https://github.com/Emsurenar/mac-appar/actions/workflows/build.yml/badge.svg" alt="Build"></a>
  <img src="https://img.shields.io/badge/platform-macOS-black?logo=apple" alt="macOS">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT license"></a>
</p>

<p align="center">
  <img src="DynamicIsland/Screenshots/hero.png" alt="Dynamic Island open under the menu bar">
</p>

## Download

| App | What you get | Download |
|---|---|---|
| **Dynamic Island** | The island, with Posture and Unknot built in | [DynamicIsland.zip](https://github.com/Emsurenar/mac-appar/releases?q=island-v&expanded=true) |
| **Posture** | Only Posture | [Posture.zip](https://github.com/Emsurenar/mac-appar/releases?q=posture-v&expanded=true) |
| **Unknot** | Only Unknot | [Unknot.zip](https://github.com/Emsurenar/mac-appar/releases?q=unknot-v&expanded=true) |

Or install from the Terminal:

```bash
# Dynamic Island, with Posture and Unknot
curl -fsSL https://raw.githubusercontent.com/Emsurenar/mac-appar/main/DynamicIsland/install.sh | bash

# Unknot on its own
curl -fsSL https://raw.githubusercontent.com/Emsurenar/mac-appar/main/Unknot/install.sh | bash
```

The apps are signed ad hoc, not notarized. The first time you open a downloaded zip, right-click the app and choose **Open**, or go to **System Settings → Privacy & Security** and click **Open Anyway**. The install scripts don't need this.

## The apps

### [Dynamic Island](DynamicIsland)

A Dynamic Island that grows out of your MacBook's notch. It shows Now Playing from any app with artwork and controls, and lets you set volume, brightness and audio output, including AirPods and AirPlay. It shows volume and output changes as HUDs in the notch and runs your Apple Home scenes through Shortcuts. It also has a calendar with reminders, clipboard history, a file shelf, a screenshot shelf, water reminders and a System tab. The animations use the same springs as the iPhone.

Posture and Unknot come with it. The island starts them, shows them in its own tabs and settings, and each one can be turned off under **Settings → Posture** or **Settings → Unknot**.

→ [Read more](DynamicIsland/README.md)

### [Posture](Posture)

A menu bar app that keeps an eye on how you sit. Every 10 seconds it reads your shoulders, head and face from the camera with Apple's Vision framework, and AirPods can add your neck angle. It learns your own good and bad postures from a short calibration and reminds you, with concrete advice, when you've been slouching for a while. With Dynamic Island running, the reminders appear in the notch.

→ [Read more](Posture/README.md)

<p align="center">
  <img src="DynamicIsland/Screenshots/posture.png" width="640" alt="Posture shown in the Dynamic Island">
</p>

### [Unknot](Unknot)

Stretch breaks that drop out of the camera notch. Every 20 minutes a member of the Stretch Crew, fifteen characters drawn like small engravings, shows three short exercises in a black island, with Dynamic Island's look and springs, and goes back into the notch. Breaks wait for a pause in your typing, for calls and for full-screen apps, and time away counts as a break. On its own it updates itself from the menu bar; inside Dynamic Island it's updated along with the island.

→ [Read more](Unknot/README.md) · [Website](https://emsurenar.github.io/mac-appar/unknot/)

<p align="center">
  <img src="Unknot/docs/demo.gif" width="640" alt="An Unknot break drops out of the notch, shows three stretches and goes back">
</p>

## Requirements

| | Dynamic Island | Posture | Unknot |
|---|---|---|---|
| macOS | 14 Sonoma or later | 26 Tahoe or later | 14 Sonoma or later |
| Mac | Apple silicon. Designed for MacBooks with a notch | Apple silicon with a camera | Apple silicon or Intel, notch optional |
| Tools | Xcode 16+ or the Command Line Tools | Xcode 26+ or the Command Line Tools | The Command Line Tools |

On macOS 14 and 15 Dynamic Island still runs Unknot, and leaves Posture off.

## How the apps fit together

Every app works on its own. A full Dynamic Island keeps the other two in `Dynamic Island.app/Contents/Library/Helpers/` and opens them at launch. If Posture or Unknot is also installed on its own, the island runs that copy instead, so there's never two of the same.

The apps talk over `DistributedNotificationCenter`:

- **Posture** broadcasts its state after every check, and its reminders. The island announces itself; Posture then sends reminders to the notch instead of as notifications, and the island sends button presses (pause, check now, open) back.
- **Unknot** listens for the island's *Stretch now*. Inside the island it leaves login items and updates to the island.

## Build and run

```bash
git clone https://github.com/Emsurenar/mac-appar.git
cd mac-appar

# Dynamic Island, on its own or with Posture and Unknot inside
DynamicIsland/build.sh --run
DynamicIsland/build.sh --with-companions --run

# Posture
Posture/build.sh --run

# Unknot
Unknot/build.sh && open Unknot/build/Unknot.app
```

Dynamic Island and Posture are Swift packages: their scripts build a release binary with Swift Package Manager, wrap it in an `.app` bundle in the app's `build/` folder, sign it and, with `--run`, launch it. Unknot's script compiles its sources with `swiftc`, draws its icon and runs its self-test; `--release` makes a universal app and `dist/Unknot.zip`. All three live in the menu bar and have no Dock icon.

## Releases

Each app has its own tag, and the [Release workflow](.github/workflows/release.yml) builds and attaches the zip when the tag is pushed:

| Tag | Zip |
|---|---|
| `island-v1.2.0` | `DynamicIsland.zip`, with Posture and Unknot inside |
| `posture-v1.2.0` | `Posture.zip` |
| `unknot-v1.2.0` | `Unknot.zip` |

```bash
git tag island-v1.2.0 && git push origin island-v1.2.0
```

## Repository layout

```
mac-appar/
├── DynamicIsland/   # The notch app (Swift package, build script, install script, screenshots)
├── Posture/         # Posture (Swift package, build script)
├── Unknot/          # Stretch breaks (build script, install script, website in docs/)
└── .github/         # CI for all three, releases, Unknot's website, issue forms
```

## Contributing

Issues and pull requests are welcome. Please keep changes in the style of the surrounding code and make sure the apps still build:

```bash
(cd DynamicIsland && swift build) && (cd Posture && swift build) && Unknot/build.sh
```

Unknot has its own [contributing guide](Unknot/CONTRIBUTING.md), with tools for checking its drawings and animations.

## License

[MIT](LICENSE) © 2026 Emre Sunar

*Not affiliated with Apple. Dynamic Island, Mac and AirPods are trademarks of Apple Inc.*
