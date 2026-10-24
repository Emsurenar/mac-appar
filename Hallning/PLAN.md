# Hållning – plan

A local macOS menu bar app that watches your posture through the camera (Apple Vision) and your AirPods (head angle), learns your good and bad postures during onboarding, and reminds you when you have sat badly for a while. It integrates with the Dynamic Island app in `../DynamicIsland`.

All UI text is Swedish. The design follows Apple's conventions (macOS 26 Tahoe, Liquid Glass, SF Symbols, spring animations) and matches the Dynamic Island app.

## What the user asked for

- A local macOS app with Apple design that integrates with their own Dynamic Island app (`../DynamicIsland`).
- Every 10 seconds: take a picture with the Mac's camera and get the body posture from Apple's Vision body pose model.
- Onboarding: the user records 10 good and 10 bad postures.
- If posture is bad for about 3 minutes in a row (90 %+ of samples), send a notification with a concrete correction such as "Dra bak axlarna", "Sträck på dig" or "Dra bakhuvudet bakåt".
- AirPods integration: the head angle from the AirPods is an input.
- "Gör den oerhört professionell."

## The user's machine (verified)

- macOS 26.6.2 on an Apple M2, FaceTime HD Camera.
- Command Line Tools only (no Xcode): Swift 6.3.3, macOS SDK 26.5. Build with SwiftPM plus a `build.sh` that assembles the `.app` bundle, the same way `../DynamicIsland/build.sh` does.
- Code signing identity: `"Dagsplan Development"`. `build.sh` picks the first identity, so camera and other permissions survive rebuilds.
- Frameworks in the SDK: Vision (with the macOS 15+ Swift API), CoreMotion `CMHeadphoneMotionManager` (macOS 14+), Charts, UserNotifications, AVFoundation.
- Liquid Glass is in the SDK (SwiftUICore): `.glassEffect(_ glass: Glass = .regular, in: some Shape)`, `Glass.regular/.clear`, `.tint(_:)`, `.interactive()`, `GlassEffectContainer`, `.glassEffectID(_:in:)`, `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)`.
- Vision Swift API (verified signatures):
  - `DetectHumanBodyPoseRequest()` returns `[HumanBodyPoseObservation]` from `try await request.perform(on: cgImage)` (`orientation` defaults to nil).
  - `observation.joint(for: .leftShoulder) -> Joint?`. `Joint` has `location: NormalizedPoint` (`.x`, `.y`, `.cgPoint`; lower-left origin) and `confidence: Float`.
  - Joint names: `leftEar, leftEye, rightEar, rightEye, neck, nose, leftShoulder, leftElbow, leftWrist, rightShoulder, rightElbow, rightWrist, root, leftHip, leftKnee, leftAnkle, rightHip, rightKnee, rightAnkle`.
  - `DetectFaceRectanglesRequest()` returns `[FaceObservation]`. These have `boundingBox: NormalizedRect` (`.cgRect`) and `roll`, `yaw`, `pitch` as `Measurement<UnitAngle>`.
- SF Symbols that exist: `figure.stand`, `figure.seated.side.left`, `figure.mind.and.body`, `figure.cooldown`, `airpods.pro`, `airpodspro`, `airpods`, `airpods.gen4`, `web.camera.fill`, `camera.fill`, `pause.circle.fill`, `checkmark.seal.fill`, `sparkles`, `chart.bar.xaxis`, `person.fill.viewfinder`. The seated figures look like reclined car seats, so draw our own figure (see below).

## Package layout

```
Hallning/
  Package.swift            // swift-tools-version 6.2, platforms [.macOS(.v26)], swiftSettings [.swiftLanguageMode(.v5)], executable "Hallning"
  build.sh                 // like ../DynamicIsland/build.sh -> "build/Hållning.app", signs, --run
  README.md                // Swedish, like the Dynamic Island README
  Resources/Info.plist     // com.emresunar.Hallning, name "Hållning", LSUIElement, NSCameraUsageDescription, NSMotionUsageDescription, sv
  Resources/AppIcon.icns   // from Scripts/make-icon.swift (same approach as the island's script)
  Scripts/make-icon.swift  // squircle, teal->blue gradient, white upright seated figure
  Sources/Hallning/
    App/HallningApp.swift          // SwiftUI App: MenuBarExtra(.window) + Window "main" + Window "onboarding"
    App/AppModel.swift             // composition root (@MainActor @Observable)
    Capture/CameraService.swift    // AVCaptureSession: on-demand bursts + live preview stream
    Analysis/BodyPose.swift        // Codable pose: joints (normalized, lower-left), aspect, face (box, pitch/yaw/roll)
    Analysis/PoseAnalyzer.swift    // Vision body pose + face rectangles -> BodyPose
    Analysis/FeatureVector.swift   // posture features from a pose plus AirPods gravity
    Analysis/PostureClassifier.swift // standardisation, weighted kNN, novelty check, cross-validation
    Motion/HeadphoneMotionService.swift
    Monitoring/PostureIssue.swift  // issue kinds and Swedish recommendations
    Monitoring/PostureMonitor.swift// loop every N s, sliding-window rule, alerts
    Storage/CalibrationStore.swift // Application Support/Hallning/calibration.json
    Storage/HistoryStore.swift     // per-minute buckets per day, alerts, kept 30 days
    Integration/IslandBridge.swift // DistributedNotificationCenter protocol (below)
    Notifications/NotificationService.swift
    Settings/PostureSettings.swift
    Views/...                      // menu bar panel, main window (Översikt, Kalibrering, Inställningar), onboarding, components
```

Code style should match the Dynamic Island app: `@MainActor @Observable` models, `@ObservationIgnored` for internals, short doc comments, English code comments, Swedish UI strings, `UserDefaults` with `didSet` storage as in `AppSettings`.

## Capture (CameraService)

- Every `interval` seconds (default 10): start the session, throw away frames for about 0.8 s while exposure settles, take 3 frames about 0.1 s apart, then stop the session. The camera is on for about 1 s per check, which saves power and keeps the green light off most of the time. A setting, "Håll kameran igång", keeps the session running instead.
- Use 1280x720 (fall back to 640x480) and BGRA. Convert to `CGImage` with a shared `CIContext` on the video queue. Do not hold on to pool buffers.
- Keep separate session and video queues, with shared state behind a lock. Fail a capture that has no frames after 6 s.
- A live preview stream at about 15 fps is used by onboarding, the live view in Översikt and the live test.
- Camera picker via `AVCaptureDevice.DiscoverySession([.builtInWideAngleCamera, .external, .continuityCamera], ...)`.
- "Pausa under videosamtal" (default on): skip a check when `device.isInUseByAnotherApplication`.
- Pause automatically on screen sleep or lock (`NSWorkspace.screensDidSleepNotification` and the distributed `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` notifications).
- Images are never saved. Only joint coordinates are stored.

## Analysis

`PoseAnalyzer` runs body pose and face rectangles on each frame. It picks the person with the widest shoulders and the face that matches that head. Joints need confidence ≥ 0.3. Convert points to a space where 1 unit is the image height (`x * aspect, y`).

Features. Each one is optional, and a vector needs shoulders plus a head (ears, else eyes, else nose):

| feature | definition | catches |
|---|---|---|
| neckHeight | (head.y − shoulderMid.y) / shoulderWidth | slouching, forward head, shrugging |
| headScale | face box height / shoulderWidth | head pushed forward (head grows relative to shoulders) |
| shoulderWidth | shoulder distance | leaning towards the screen |
| shoulderTilt | atan((L.y − R.y) / abs(L.x − R.x)) in degrees (robust to mirroring) | leaning sideways |
| headTilt | eye line angle, same formula (fallback: face roll) | head tilt |
| headOffset | (head.x − shoulderMid.x) / width, sign flipped if L.x < R.x | lateral lean |
| shoulderHeight | shoulderMid.y | sinking in the chair |
| headHeight | head.y | sinking or forward head |
| noseDrop | (earsMid.y − nose.y) / width | looking down |
| facePitch, faceYaw | from FaceObservation in degrees (low weight) | looking down; yaw is context only |
| gravity (AirPods) | mean unit gravity vector over the last 3 s, `CMDeviceMotion.gravity` | neck flexion and tilt, independent of axes |

Each check averages the 3 frames with the median per feature. The pose with the highest confidence is kept for drawing.

## AirPods (HeadphoneMotionService)

- `CMHeadphoneMotionManager`: `startConnectionStatusUpdates()`, then `startDeviceMotionUpdates(to: .main)`. Implement the delegate methods `headphoneMotionManagerDidConnect/DidDisconnect` as nonisolated and hop to the main actor.
- Keep a 5 s ring buffer of gravity, pitch and roll. `currentSample()` returns the mean if the newest value is less than 1.5 s old.
- The classifier uses the gravity vector, so it does not depend on how the AirPods axes are oriented.
- For display ("Nacke 12° nedåt"), show `attitude.pitch` relative to the mean of the good calibration samples. Pick the sign from the calibration: if the forwardHead and lookingDown samples have lower pitch than the good mean, then lower pitch means down.
- This is optional. Show "Inga AirPods – bara kamera" when there is no data. It needs `NSMotionUsageDescription`. It has not been verified whether macOS delivers headphone motion to a background menu bar app, so handle missing data quietly.

## Classifier (PostureClassifier)

- Training data: each recorded pose is a burst of about 6 frames, so about 120 vectors in all. Each sample stores its label (good or bad), its `PostureIssue` (for bad samples), its prompt index, its vectors and one representative `BodyPose`.
- Standardise every scalar feature by the **good-class** mean and standard deviation, with a floor on the standard deviation:
  - neckHeight .03, headScale .02, shoulderWidth .01, shoulderTilt 1.5°, headTilt 2°, headOffset .03, shoulderHeight .01, headHeight .01, noseDrop .03, facePitch 3°, faceYaw 5°.
  - Gravity uses the angle between vectors, scaled by the RMS angle of the good samples (floor 3°).
- Prior weights: neckHeight 1.0, headScale 1.0, shoulderWidth .8, shoulderTilt .8, headTilt .5, headOffset .6, shoulderHeight .8, headHeight .6, noseDrop .6, facePitch .4, faceYaw .2, gravity 1.2.
- Distance: d² = Σ wᵢ·clamp(Δzᵢ, ±8)² / Σ wᵢ over the features both vectors have. Require a minimum shared weight.
- Weighted kNN with k = 7 and a Gaussian kernel. σ is the median nearest-neighbour distance between different poses (floor 0.5). P(bad) = Σw_bad / Σw.
- Novelty: if the nearest distance is above max(3σ, 2.5), mark the sample as uncertain. It is shown, but it does not count towards an alert.
- Sensitivity setting: Låg 0.65, Normal 0.5, Hög 0.35.
- Issue: the kernel-weighted vote among the bad neighbours' issues. If no tagged neighbours exist, infer the issue from z-deviations against the good mean:
  - shoulderTilt → leaningLeft/Right
  - noseDrop, facePitch or gravity → lookingDown
  - neckHeight low with shoulderHeight low → slouching
  - neckHeight low with shoulderHeight high → shrugging
  - headScale high → forwardHead
  - shoulderWidth high → tooClose
- Leave-one-pose-out cross-validation, shown as "Träffsäkerhet: 19 av 20 poser".
- Quick feedback from the menu bar ("Stämmer inte? Det här är bra / dålig hållning") and from the notification action ("Fel – jag satt bra") adds the latest vectors as new samples and retrains.

## Issues and recommendations (Swedish copy)

| issue | title | body |
|---|---|---|
| slouching | Sträck på dig | Du har sjunkit ihop. Res dig från höfterna och låt ryggen växa mot taket. |
| forwardHead | Dra bakhuvudet bakåt | Huvudet har glidit fram. Dra in hakan lätt så att öronen hamnar rakt ovanför axlarna. |
| roundedShoulders | Dra bak axlarna | Axlarna rullar framåt. För skulderbladen bakåt och nedåt och öppna bröstet. |
| lookingDown | Lyft blicken | Du tittar ner länge. Höj skärmen så att överkanten hamnar i ögonhöjd. |
| tooClose | Luta dig tillbaka | Du sitter nära skärmen. Sätt dig långt bak i stolen med stöd för ländryggen. |
| leaningLeft / leaningRight | Räta upp dig | Du lutar åt vänster/höger. Fördela vikten jämnt på båda sittbenen. |
| shrugging | Släpp ner axlarna | Axlarna är uppdragna mot öronen. Andas ut och låt dem sjunka. |
| headTilt | Räta upp huvudet | Huvudet lutar åt sidan. Låt det vila rakt ovanpå halsen. |
| chinOnHand | Släpp hakan | Du stöder huvudet i handen. Lägg händerna på bordet och låt nacken bära huvudet. |

## Onboarding (window about 860×640, hidden title bar)

1. **Välkommen**: the animated figure loops between upright and slouched. Three rows: "Allt sker lokalt" (no images saved), "Lär sig din kropp", "Fungerar med Dynamic Island". Button "Kom igång".
2. **Behörigheter**: Kamera (required), Notiser, AirPods huvudvinkel (optional, shows connection status).
3. **Placering**: live preview, mirrored, with a skeleton overlay. Checklist: "Axlarna syns", "Ansiktet syns".
4. **10 bra hållningar**:
   1. Sitt rakt och bekvämt
   2. Titta mot skärmens vänstra kant
   3. Titta mot högra kanten
   4. Titta mot överkanten
   5. Sänk blicken mot tangentbordet utan att böja nacken
   6. Händerna på tangentbordet
   7. Luta dig lätt bakåt mot ryggstödet med rak rygg
   8. Händerna i knät
   9. Sitt rakt och andas lugnt
   10. Din egen bästa hållning
5. **10 dåliga hållningar**, each tagged with an issue:
   1. Sjunk ihop (slouching)
   2. Skjut fram huvudet (forwardHead)
   3. Runda axlarna (roundedShoulders)
   4. Titta ner i knät som i mobilen (lookingDown)
   5. Luta dig nära skärmen (tooClose)
   6. Luta åt vänster (leaningLeft)
   7. Luta åt höger (leaningRight)
   8. Dra upp axlarna (shrugging)
   9. Vila hakan i handen (chinOnHand)
   10. Sjunk ner i stolen (slouching)

   For each prompt: a card with the step ("Bra hållning 3 av 10"), title, instruction and illustration. Press "Ta bild" (space bar), then a 3-2-1 countdown ring, then a burst of 6 frames with "Håll stilla". Validate that at least 4 frames have shoulders and a head; otherwise show "Jag ser inte dina axlar …". Then a checkmark and the next prompt. "Gör om" redoes the previous pose. Progress dots run along the bottom.
6. **Klart**: a grid of 20 skeleton thumbnails (green for good, orange for bad), the cross-validation result, and a live test that classifies continuously ("Sitt bra och sedan dåligt – stämmer det?"). Button "Klar".

## Monitoring rule (PostureMonitor)

- Settings: interval (default 10 s), alert duration (default 3 min, 1–10) and threshold (default 90 %, 60–100).
- The window holds the valid samples (good or bad; uncertain and away excluded) with date ≥ max(windowStart, now − duration).
- Alert when:
  - the window covers at least duration − 1.5·interval,
  - there are at least 60 % of the expected samples, and
  - the bad fraction is at least the threshold.
- After an alert, or when the monitor resumes from a pause, set `windowStart = now`, so the next alert needs a full new window.
- UI progress while the latest sample is bad: badCount / ceil(threshold·expected), with "Påminnelse om m:ss".
- Statuses:
  - idle (not calibrated)
  - good
  - bad(issue)
  - uncertain
  - away (no person in view)
  - paused(until)
  - cameraBusy
  - noPermission
  - error
- Pause options: 15 min, 30 min, 1 h, resten av dagen.
- Smoothed score from 0 to 100: an EMA of (1 − P(bad)).
- History: per-minute buckets per day of good, bad and uncertain counts, plus the alerts with their issues. Store one JSON file per day and keep 30 days.

## Notifications

`UNUserNotificationCenter`, category `posture-alert` with the actions "Pausa 30 min" and "Fel – jag satt bra". Example: the title is the issue title, and the body is "Du har suttit med dålig hållning i 3 minuter. " followed by the advice. Show banners even while the app is active.

Alert style setting:
- "Dynamic Island, annars notis" (default): if the island has said hello within 75 s, alert only in the island and play a soft sound if enabled; otherwise send a notification.
- "Båda".
- "Endast notis".

## Dynamic Island protocol (DistributedNotificationCenter, deliverImmediately)

- `com.emresunar.Hallning.state` (Hållning → island), sent on every check, on launch and on quit:
  - `status`: good | bad | uncertain | away | paused | idle | off
  - `issue`, `title`, `progress` (0…1), `score` (Int), `todayGood` (0…1), `headPitch` (Double, optional), `airpods` (Bool), `interval`, `lastCheck` (epoch), `pausedUntil` (epoch, optional), `version` = 1
- `com.emresunar.Hallning.alert` (Hållning → island): `issue`, `title`, `body`, `minutes`.
- `com.emresunar.Hallning.command` (island → Hållning): `command` is pause30 | resume | check | open.
- `com.emresunar.DynamicIsland.posture.hello` (island → Hållning): sent on launch and at most every 30 s while receiving state. Hållning answers with a state immediately.

## Dynamic Island changes (`../DynamicIsland`)

- `Services/PostureService.swift`, `@MainActor @Observable`:
  - Observes the notifications above and holds the latest state.
  - `isConnected` is true when the last update is within 2·interval + 20 s and the status is not off.
  - `onAlert` callback.
  - `send(_ command:)`.
- `IslandModel`:
  - New presentation `.postureAlert`. Priority: open > hud > postureAlert > peek > compact media > postureCompact.
  - It shows for about 6 s and is sized notch + 260 wide, notch.height + 64 high, with a bottomRadius of about 24.
  - New `.postureCompact` live activity: the small figure in orange on the left and a progress ring on the right. Show it when the status is bad, progress ≥ 0.5 and no music is playing.
  - New tab `.posture` with the symbol `figure.stand`. It is visible only when the setting is on and the posture service is connected.
- `Views/PostureViews.swift`:
  - **PostureTab**:
    - A ring with today's percentage of good posture and the figure inside, which slouches with the status.
    - The title (status or issue) and "Senaste kontroll för 6 s sedan".
    - The progress bar towards the reminder.
    - The AirPods angle.
    - Buttons: Pausa 30 min / Fortsätt, Kontrollera nu, Öppna Hållning.
  - **PostureAlertView**: the figure with a bounce, the title, and "Dålig hållning i 3 min".
  - **CompactPostureView**.
- `AppSettings` and `SettingsView`: a "Hållning" section with the toggles showPostureTab, showPostureAlerts and showPostureLiveActivity.
- Extend `SnapshotRenderer` with the posture states. Update the README.

## Signature visual: PostureFigure

A custom SwiftUI `Shape`: a seated person seen from the side, facing right, with an animatable `slouch` from 0 to 1. Coordinates are in a unit square with y pointing down. The body lines are stroked, and the head is a filled circle (radius 0.10). The line width is 0.085·size with round caps. Fill one path with `strokedPath` plus the circle.

| point | upright (slouch 0) | slouched (slouch 1) |
|---|---|---|
| hip | (0.36, 0.72) | same |
| knee | (0.74, 0.72) | same |
| foot | (0.74, 0.97) | same |
| shoulder | (0.40, 0.34) | (0.55, 0.44) |
| spine control (back bows out) | (0.36, 0.52) | (0.24, 0.56) |
| head centre | (0.44, 0.15) | (0.72, 0.29) |
| elbow | (0.44, 0.55) | (0.56, 0.62) |
| hand | (0.66, 0.52) | (0.76, 0.60) |

The neck runs from the shoulder towards the head and stops 1.25·r from the head centre. The same shape renders the menu bar template icon (18 pt, via ImageRenderer, `isTemplate = true`), the onboarding hero, the rings, and a copy in the island app.

## UI

- **Menu bar panel** (`MenuBarExtra` with `.window`, width 320):
  - Figure ring with the status title, "Kontrolleras var 10:e s · nyss" and a pause button.
  - When bad, an orange progress bar with "Påminnelse om 1:20".
  - Three stat tiles: Idag 86 %, Påminnelser, Nacke 8° (AirPods).
  - A small Charts timeline of today.
  - Feedback buttons.
  - "Öppna Hållning…", a pause menu and "Avsluta".
- **Main window** (`NavigationSplitView`):
  - **Översikt**:
    - Status header.
    - Optional live camera card with the skeleton.
    - Today's chart (Charts, 15-minute stacked bars, good and bad).
    - The last 7 days.
    - Issues of the day as horizontal bars.
  - **Kalibrering**:
    - Model quality.
    - The sample grid as skeleton thumbnails, with delete.
    - "Kalibrera om…".
  - **Inställningar**: Form `.grouped` with these sections:
    - Kontroller: interval
    - Påminnelser: duration, threshold, sensitivity, style, sound
    - Kamera: picker, keep on, pause during calls
    - AirPods
    - Dynamic Island: connection status
    - Allmänt: launch at login with `SMAppService`
    - Integritet: "Radera all data"
- Scenes: on macOS 15+, use `.defaultLaunchBehavior(.suppressed)` for the main window. Present onboarding when not calibrated. Use `.restorationBehavior(.disabled)`.
- Colours: green for good, orange for bad, secondary for away, indigo for paused. The accent is teal.

## Status

Analysis and design are done (this file). No Swift code has been written yet for Hållning. The Dynamic Island app is unchanged.

The build has to be done on the Mac. The cloud environment is Linux and cannot compile AppKit, SwiftUI, Vision or AVFoundation code, so write the code carefully against the API signatures above and keep it simple to compile.
