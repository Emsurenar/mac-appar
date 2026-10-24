# Posture

A Mac menu bar app that watches how you sit, using the camera, Apple's Vision and, if you like, the head angle from your AirPods. It learns your own body. When you have sat badly for a while it tells you, with concrete advice such as *Pull your shoulders back*, *Sit up straight* or *Draw your head back*.

- **Every 10 seconds** the app reads your shoulders, head and face with Vision. The camera stays on while it watches, so its light stays steady instead of blinking at every check.
- **Calibration**: you show 10 good and 10 poor postures, and each poor posture is linked to its own advice.
- **The 3-minute rule**: you get a reminder when at least 90% of the checks over 3 minutes show poor posture. Both values can be changed.
- **AirPods neck limit**: with AirPods Pro, AirPods Max or AirPods (3rd generation and later), your neck counts as bent once it is more than 15° below neutral. After 2 minutes like that you get a reminder to lift your head. The angle is sampled every second, and the limit, the time and the neutral position can all be set. Without AirPods only the camera is used.
- **Dynamic Island**: when [Dynamic Island](../DynamicIsland) is running, reminders and status show in the island; otherwise they come as notifications.
- **Overview** shows today's chart, the last 7 days and today's most common issues.

## Build and run

Requires macOS 26 and the Command Line Tools. Xcode is not needed.

```bash
cd Hallning
./build.sh --run
```

The app ends up in `build/Posture.app`.

- **Icon**: on the first build, `Scripts/make-icon.swift` draws the icon (`Resources/AppIcon.icns`).
- **Signing**: the script signs with the first code signing identity in the keychain, so the camera permission survives rebuilds. Pick another one with `SIGN_IDENTITY="…" ./build.sh`.

The app has no Dock icon. It lives in the menu bar as a seated figure, and the first launch opens calibration automatically.

## Permissions

| Permission | Why | |
|---|---|---|
| Camera | Reading your posture | Required |
| Notifications | Reminders when Dynamic Island isn't running | Optional |
| Motion (AirPods) | The neck angle | Optional |

If something goes wrong, turn Posture on under **System Settings → Privacy & Security → Camera** (or **Motion & Fitness**).

## How it works

1. Vision finds joints (ears, eyes, nose, shoulders …) and the face's box and angles.
2. About ten measures are derived from them. Examples:
   - how high the head sits above the shoulders relative to shoulder width
   - how large the face appears, which grows when the head moves forward
   - the shoulder tilt
   - how far the nose has dropped

   The AirPods add the direction of gravity in the head.
3. The measures are compared with your own calibrated postures, using a weighted nearest neighbour that is normalised against your good postures. A position that matches nothing you calibrated counts as *unsure* and does not affect reminders.
4. The AirPods neck angle is a hard rule on top of that. Past the limit, a check counts as poor posture whatever the camera says, and the neck has its own shorter reminder window.
5. Not right? Press *This is good* or *Poor posture* in the menu, or *Wrong – I sat well* in the notification. The check is then added to the calibration.

Checks pause automatically when the screen is locked or asleep and, if you want, during video calls, when another app is using the camera. The camera turns off while paused.

### Neutral position

The neck angle is measured from your calibration, or from a neutral position you set yourself. To set it, sit up straight, look at the screen and press **Settings → AirPods → Neutral position → Set now**.

## Dynamic Island

The apps talk over distributed notifications:

- `com.emresunar.Hallning.state`: the status. It is sent on every check, at launch and at quit, and includes the AirPods `headPitch` and `neckLimit`.
- `com.emresunar.Hallning.alert`: a reminder, with the `issue`, `title`, `body` and `minutes`.
- `com.emresunar.Hallning.command`: the buttons in the island's tab: `pause30`, `resume`, `check` and `open`.
- `com.emresunar.DynamicIsland.posture.hello`: the island is running. If the island has been heard from in the last 75 seconds, the reminder shows only there (the default); otherwise it comes as a notification. You can change this under **Settings → Reminders**.

The names keep the app's original Swedish name, *Hållning*, as do the bundle identifier and the folder. That way existing permissions and data carry over.

## Privacy

- Everything happens locally on your Mac. Nothing is sent anywhere.
- **Images are never saved.** Each frame is analysed in memory and released straight away. Only joint coordinates are stored, for the calibration and its thumbnails.
- Data lives in `~/Library/Application Support/Hallning/`:
  - `calibration.json`
  - one file per day in `History/`, with the number of good and poor checks per minute, kept for 30 days
- **Settings → Privacy → Delete all data** removes everything.
