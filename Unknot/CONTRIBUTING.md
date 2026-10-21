# Contributing to Unknot

Thanks for helping! Unknot is small on purpose: one Swift target, no dependencies, no Xcode project.

## Build and run

```bash
./build.sh
open build/Unknot.app
```

You need Xcode or the Command Line Tools (`xcode-select --install`). The build checks the translations and
runs a self-test; `build/Unknot.app/Contents/MacOS/Unknot --selftest` runs it on its own.

Handy helpers for checking your work without clicking around:

```bash
build/Unknot.app/Contents/MacOS/Unknot --cast cast.png                # every buddy in six poses
build/Unknot.app/Contents/MacOS/Unknot --settings-screenshots shots   # every settings tab, light and dark
build/Unknot.app/Contents/MacOS/Unknot --previews previews -AppleLanguages '(sv)'
```

## Adding a buddy

Buddies live in `Sources/Buddies.swift`. Add a case to `Buddy`, then give it a name, a body `size`, a `look`
(colours and face layout) and, if it needs them, details in `drawBehind`, `drawOnBody` and `drawFront`.
Every buddy shares the face, arms and moves, so it can do all the exercises straight away. Check it with
`--cast` and add its name to `Resources/sv.lproj/Localizable.strings`.

## Translations

English is the source language. Copy `Resources/sv.lproj` to `Resources/<code>.lproj`, translate the
right-hand side, add the code to `CFBundleLocalizations` in `Info.plist`, and run
`python3 scripts/check_translations.py`.

## Style

Match the code around you: plain Swift and SwiftUI, short comments that explain why, user-facing strings
wrapped in `L("…")`. Keep the app light: no new dependencies, no tracking, nothing that phones home except
the optional update check.
