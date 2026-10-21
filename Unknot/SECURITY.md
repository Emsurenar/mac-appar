# Security

## What Unknot can see

Unknot asks for no permissions, and it only reads what it needs to time a break:

- **How long since you last touched the keyboard or mouse**, as a number of seconds. Never what you typed.
- **Whether a microphone or camera is on**, and which app is using the microphone, so a break can wait for
  your call to end. Never what they hear or see.
- **The size of the front app's windows**, to tell whether it's in full screen. Never their contents.

Settings and statistics are stored in `UserDefaults` on your Mac and never leave it.

## How updates are checked

The only network requests go to GitHub, for this repository's releases:

1. At most once a day, if **Check for updates automatically** is on, Unknot asks GitHub's releases API for the
   latest version number.
2. Only when you click **Install and Restart** does it download `Unknot.zip`, over HTTPS.
3. Before using the download it checks the SHA-256 checksum GitHub publishes for the file, that the app inside
   has Unknot's bundle identifier and the version it expected, and that its code signature is intact.
4. Then it replaces itself and restarts. If anything doesn't match, it stops and offers the release page.

Unknot is signed ad hoc, not with a paid Apple Developer ID, so the signature shows that the app hasn't been
changed since it was built, not who built it. The release zips are built from this repository by GitHub
Actions.

## Reporting a problem

If you find a security issue, please report it privately with
[Report a vulnerability](https://github.com/Emsurenar/unknot/security/advisories/new) instead of opening a
public issue.
