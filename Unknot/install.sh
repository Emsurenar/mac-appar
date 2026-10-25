#!/bin/bash
# Installs the latest Unknot release into /Applications and opens it:
#   curl -fsSL https://raw.githubusercontent.com/Emsurenar/mac-appar/main/Unknot/install.sh | bash
# Removes Unknot, its login item and its settings again:
#   curl -fsSL https://raw.githubusercontent.com/Emsurenar/mac-appar/main/Unknot/install.sh | bash -s -- --uninstall
set -euo pipefail

SCRIPT="https://raw.githubusercontent.com/Emsurenar/mac-appar/main/Unknot/install.sh"
# Unknot shares its repository with other apps, so the newest release isn't necessarily Unknot's: look for the
# newest one tagged unknot-v… instead. GitHub lists releases newest first.
RELEASES="https://api.github.com/repos/Emsurenar/mac-appar/releases?per_page=50"
APP="/Applications/Unknot.app"

quit_running_copies() {
    # Quit a running copy (also the old Sträckis) and wait until it's gone, or opening the new one fails.
    pkill -x Unknot 2>/dev/null || true
    pkill -x Strackis 2>/dev/null || true
    for _ in $(seq 1 50); do
        pgrep -xq Unknot || pgrep -xq Strackis || break
        sleep 0.1
    done
}

if [[ "${1:-}" == "--uninstall" ]]; then
    if [[ -x "$APP/Contents/MacOS/Unknot" ]]; then
        # Let the app remove its own login item before it goes
        "$APP/Contents/MacOS/Unknot" --remove-login-item 2>/dev/null || true
    fi
    quit_running_copies
    rm -rf "$APP"
    defaults delete io.github.emsurenar.unknot 2>/dev/null || true
    echo "Unknot is uninstalled, along with its settings and statistics."
    exit 0
fi

if [[ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]]; then
    echo "Unknot needs macOS 14 Sonoma or later. This Mac has macOS $(sw_vers -productVersion)."
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

URL="$(curl -fsSL "$RELEASES" | grep -o 'https://github.com/Emsurenar/mac-appar/releases/download/unknot-v[^"]*/Unknot.zip' | head -1 || true)"
if [[ -z "$URL" ]]; then
    echo "Couldn't find an Unknot release. Download it from https://github.com/Emsurenar/mac-appar/releases?q=unknot-v instead."
    exit 1
fi

echo "Downloading Unknot…"
curl -fsSL "$URL" -o "$TMP/Unknot.zip"
ditto -x -k "$TMP/Unknot.zip" "$TMP"

quit_running_copies
rm -rf "/Applications/Sträckis.app" 2>/dev/null || true

if ! { rm -rf "$APP" && ditto "$TMP/Unknot.app" "$APP"; } 2>/dev/null; then
    echo "Couldn't write to /Applications. Try again with: sudo bash -c \"\$(curl -fsSL $SCRIPT)\""
    exit 1
fi
# Downloads made with curl aren't quarantined, but clear the flag in case the zip was.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

# macOS can take a moment to notice the old copy is gone; try again before giving up.
for _ in 1 2 3; do
    open "$APP" 2>/dev/null || true
    sleep 1
    pgrep -xq Unknot && break
done
VERSION="$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || true)"
echo "Unknot ${VERSION} is installed. Look for the frog in your menu bar."
