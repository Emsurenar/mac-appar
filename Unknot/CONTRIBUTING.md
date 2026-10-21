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
build/Unknot.app/Contents/MacOS/Unknot --cast cast.png                # the whole crew in six poses
build/Unknot.app/Contents/MacOS/Unknot --settings-screenshots shots   # every settings tab, light and dark
build/Unknot.app/Contents/MacOS/Unknot --previews previews -AppleLanguages '(sv)'
```

## Adding a crew member

Add a case to `Buddy` in `Sources/Buddies.swift` and give it a name. Then draw it in `Sources/Crew.swift`: a struct
that conforms to `CrewArt`, with a body contour, shoulders and an arm style, a face, and details behind, on and in
front of the body. Shapes are built once in `init`; the frame decides eyes, mouth and anything that sways.
The crew shares the face, arms and moves, so a new member can do all the exercises straight away. Keep to
the style: one ink line (2.2) for contours, 1.25 for details, `Hatch.shadow` for the shadow side, a soft tint
and at most one or two stronger colour details. Check it with `--cast` and `--filmstrip`. Check it with
`--cast` and add its name to `Resources/sv.lproj/Localizable.strings`.

## Translations

English is the source language. Copy `Resources/sv.lproj` to `Resources/<code>.lproj`, translate the
right-hand side, add the code to `CFBundleLocalizations` in `Info.plist`, and run
`python3 scripts/check_translations.py`.

## Style

Match the code around you: plain Swift and SwiftUI, short comments that explain why, user-facing strings
wrapped in `L("…")`. Keep the app light: no new dependencies, no tracking, nothing that phones home except
the optional update check.
