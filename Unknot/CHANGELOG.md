# Changelog

## 1.13.0 – 2026-10-21

- **Four new members of the Stretch Crew**, drawn in more detail than the rest:
  - **Jesus of Nazareth**: long hair parted in the middle, a beard, a white tunic with a red mantle, sandals
    and a fine gold halo.
  - **Mahatma Gandhi**: round wire glasses, a white moustache, a khadi shawl with a woven border, a dhoti and
    sandals.
  - **Barack Obama**: close-cropped hair going grey at the temples, his wide smile, a charcoal suit, a blue
    tie, a flag pin and a pocket square.
  - **René Descartes**, as Frans Hals painted him: long dark hair, a thin moustache, a black doublet engraved
    all over and a wide white collar.
- The Stretch Crew settings and the README picture have room for all fourteen.

## 1.12.0 – 2026-10-21

- **Stefan Löfven joins the Stretch Crew** in place of Sol the cactus: a dark suit, a red tie, a shiny crown
  with grey hair at the sides, and the same moves as everyone else.

## 1.11.0 – 2026-10-21

- **The crew have names**: Momo the mochi, Miso the cat, Bao the panda, Juni the bunny, Otto the frog, Selma
  the semla, Pip the chick, Toby the toast, Nori the onigiri and Sol the cactus. A break says who's leading it
  (*Stretch break with Otto*), the welcome window introduces whoever waves, and the Stretch Crew settings
  show each name with what they are.
- **Selma, redrawn.** The semla is now clearly a semla: a low, golden cardamom bun with a glazed shine, a
  visible layer of almond paste, two rows of soft piped cream and the bun's top resting on it as a lid,
  dusted with icing sugar where it's thickest on top.

## 1.10.0 – 2026-10-21

- **Says who's on the call.** When a break waits for a call, the menu names the app using the microphone:
  *Break waiting until your call in zoom.us ends*.
- In Low Power Mode the crew animates at 30 frames a second instead of the display's full rate.
- Calmer Stretch Crew settings: the checkmark shows who's on, without a coloured frame around every card.
- The Activity chart shows today in full colour and the days before a little quieter.
- [SECURITY.md](SECURITY.md) explains what Unknot can see and how updates are checked, and security issues
  can be reported privately on GitHub.
- For contributors: the self-test and the README scene have their own files, and CI checks `install.sh`.

## 1.9.1 – 2026-10-21

- **No more jumps between exercises.** When a break moves on to the next exercise, the crew used to snap
  back to standing from wherever it was, arms halfway up or a hand over its eyes. Now it blends into the
  next move over half a second. The same goes for the cheer at the end.
- Hovering over a crew member in the settings brings the still picture to life from where it is, instead
  of jumping to another pose.
- `Unknot --transitions` draws the frames around every change of exercise, for checking new moves.

## 1.9.0 – 2026-10-21

- **Pick a position by looking at it.** Settings → General shows five small screens with the panel where it
  would appear, instead of a menu of long names.
- **Exercises grouped by where they help**: neck and shoulders, back and chest, arms, hands and legs, eyes
  and breathing. In the settings and in the README.
- During a break the menu offers **Done** and **In 5 min**, handy when the panel is on another display.
- **Report a problem** in Settings → About opens a bug report with your Unknot and macOS versions already
  filled in. Nothing is sent until you submit it.
- Clearer issue forms on GitHub.

## 1.8.1 – 2026-10-21

- **Smoother animations.** The crew now moves at the display's own refresh rate, up to 120 frames a second,
  instead of 30. A frame takes well under a millisecond to draw.
- **Fixed:** on macOS 26, switching to a taller settings tab (from Stretch Crew to Exercises, say) could leave a
  white band over the first rows. The window now gets its new size before the tab is shown.
- The README animation runs at 20 frames a second.

## 1.8.0 – 2026-10-21

- **Live cues.** The label at the top of a break keeps time with the move: *Breathe in · 3* during deep
  breaths, *Switch sides* halfway through a side bend, a neck stretch or a twist.
- **Two new exercises:** shoulder shrugs and a shoulder stretch with one arm across your chest.
- **Unknot's own sound**: two soft wooden notes instead of a macOS alert. The other sounds are still there.
- The menu shows the time of the next break, not just how far away it is.
- In dark mode the paper behind the crew is printed a little dimmer, so it doesn't glare.
- `install.sh` checks the macOS version, says which version it installed, and can uninstall everything with
  `--uninstall`.
- A small website at [emsurenar.github.io/unknot](https://emsurenar.github.io/unknot/).

## 1.7.0 – 2026-10-21

- **Out of the notch.** A break now starts as a drop of black inside the camera notch, falls out of it and
  opens into the glass panel, then shrinks back into the notch when it's done. On screens without a notch it
  unfolds from under the menu bar.
- **Waits for your calls.** A break that's due holds off while another app uses the microphone or camera,
  and sitting still through a call no longer counts as time away. Unknot only checks whether they're on.
  Turn it off under Settings → Schedule.
- **One-click updates.** When a new version is out, choose it in the menu and Unknot downloads it from
  GitHub, checks its SHA-256 checksum, replaces itself and restarts.
- **A frog in the menu bar** instead of a generic symbol. It closes its eyes while reminders are paused and
  smiles during a break.
- A clearer first launch: the welcome window explains what happens, and afterwards a small note points at
  the menu bar icon.
- When a break is done it shows the time of the next one, with new lines to finish on.
- Drawing the crew is cheaper: shapes that never change are no longer rebuilt for every frame.
- A rewritten README with a FAQ, and a CONTRIBUTING guide with the code map and the command-line helpers.

## 1.6.0 – 2026-10-21

- **Breaks drop down from the camera.** The panel now slides out from under the menu bar at the top center of
  the screen, where the camera sits, and goes back the same way. This is the new default; the corners are still
  there under Settings → General → Position on screen.
- **A semla joins the crew** in place of the penguin: a cardamom bun with almond paste, a cloud of whipped
  cream and a sugared lid that wobbles as it moves.

## 1.5.0 – 2026-10-21

- **The Stretch Crew, redrawn.** Every member is now an engraved line drawing: one ink line, finer lines for
  detail, hatching for shadow and a soft tint of colour printed on top. Each has its own details, from the
  frog's golden eyes and webbed toes to the cat's tabby stripes and the cactus's patterned pot.
- **New animations for every exercise.** Moves have a beginning, a hold and an end, with smooth easing,
  a quiet breath at rest, a soft landing after jumps, tails and ears that follow a beat behind, and a real
  hand over the brow when resting your eyes. Every exercise starts from rest.
- The crew always stands on paper, so the drawings read just as well in dark mode.
- A new app icon: the frog, reaching up.
- Unknot now needs macOS 14 Sonoma or later.

## 1.4.0 – 2026-10-21

- **A new look for the crew**: a flat, calmer illustration style with no outlines, small features, soft shading
  and a muted palette. The app icon follows.
- "Buddies" is now the **Stretch Crew**.
- **Choose the app's language** in Settings → General: follow the system, English or Svenska. It switches
  right away.
- Hover over the menu bar icon to see when the next break is.

## 1.3.1 – 2026-10-21

- Updating could leave Unknot closed: the new copy saw the old one, which was still quitting, and stepped aside.
  It now ignores a copy that's on its way out, and the installer retries opening the app.

## 1.3.0 – 2026-10-21

- **Nine new buddies**: a cat, a panda, a bunny, a frog, a penguin, a chick, a slice of toast, an onigiri and
  a cactus join Mochi. Every break brings a random one, never the same twice in a row.
- New **Buddies** tab: pick who can visit you. Hover over a buddy to see it wave.
- The welcome window and the exercise list show off the whole cast.

## 1.2.0 – 2026-10-21

- **Sträckis is now called Unknot.** A name that works in every language and says what the app is for.
  Your settings and statistics come along, and the old Sträckis app is quit and moved to the Trash.
- The installer waits for the running app to quit before opening the new version, so updating no longer
  fails with error -600.

## 1.1.0 – 2026-10-21

- New **Activity** tab: today, this week, days in a row and all time, plus a chart of the last seven days.
- Choose how long the snooze button postpones a break: 5, 10 or 15 minutes.
- The settings window resizes to fit each tab.
- Waiting for full-screen apps now works on Macs with a camera notch, without mistaking a zoomed window for full screen.
- Opening a second copy of Sträckis shows the settings of the one that's already running instead of doing nothing.
- Moving to Applications no longer replaces a newer version that's already installed.
- No breaks while the display is asleep.
- The buddy animates at 30 frames per second, which saves battery.
- Every build gets its own build number.

## 1.0.0 – 2026-10-20

First public release.

- Stretch breaks in a floating glass panel that never steals focus, with an animated buddy that shows each exercise.
- 12 exercises; every break picks a few at random from the ones you have turned on.
- Settings window: interval, break length, exercises per break, position, sound, open at login, update checks.
- Smart pauses: time away from the computer counts as a break, sleep and a locked screen restart the countdown, optional working hours and waiting while an app is in full screen.
- Menu bar menu with countdown, "Stretch now", pause for 30 min / 1 h / 2 h / the rest of the day, and today's break count.
- Welcome window on first launch, with an offer to move the app to the Applications folder.
- English and Swedish.
- Universal app for Apple silicon and Intel, macOS 13 or later.
