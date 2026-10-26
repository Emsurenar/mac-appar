#!/bin/bash
# Installs the latest Dynamic Island release into /Applications and opens it:
#   curl -fsSL https://raw.githubusercontent.com/Emsurenar/mac-appar/main/DynamicIsland/install.sh | bash
# Removes it, its login item and its settings again:
#   curl -fsSL https://raw.githubusercontent.com/Emsurenar/mac-appar/main/DynamicIsland/install.sh | bash -s -- --uninstall
set -euo pipefail

SCRIPT="https://raw.githubusercontent.com/Emsurenar/mac-appar/main/DynamicIsland/install.sh"
# The repository holds several apps, so look for the newest release tagged island-v…. GitHub lists releases newest first.
RELEASES="https://api.github.com/repos/Emsurenar/mac-appar/releases?per_page=50"
APP="/Applications/Dynamic Island.app"

quit_running_copy() {
    pkill -x DynamicIsland 2>/dev/null || true
    for _ in $(seq 1 50); do
        pgrep -xq DynamicIsland || break
        sleep 0.1
    done
}

if [[ "${1:-}" == "--uninstall" ]]; then
    quit_running_copy
    rm -rf "$APP"
    defaults delete com.emresunar.DynamicIsland 2>/dev/null || true
    echo "Dynamic Island is uninstalled, along with its settings."
    exit 0
fi

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "Dynamic Island needs a Mac with Apple silicon."
    exit 1
fi
if [[ "$(sw_vers -productVersion | cut -d. -f1)" -lt 14 ]]; then
    echo "Dynamic Island needs macOS 14 Sonoma or later. This Mac has macOS $(sw_vers -productVersion)."
    exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

URL="$(curl -fsSL "$RELEASES" | grep -o 'https://github.com/Emsurenar/mac-appar/releases/download/island-v[^"]*/DynamicIsland.zip' | head -1 || true)"
if [[ -z "$URL" ]]; then
    echo "Couldn't find a Dynamic Island release. Download it from https://github.com/Emsurenar/mac-appar/releases?q=island-v instead."
    exit 1
fi

echo "Downloading Dynamic Island…"
curl -fsSL "$URL" -o "$TMP/DynamicIsland.zip"
ditto -x -k "$TMP/DynamicIsland.zip" "$TMP"

quit_running_copy
if ! { rm -rf "$APP" && ditto "$TMP/Dynamic Island.app" "$APP"; } 2>/dev/null; then
    echo "Couldn't write to /Applications. Try again with: sudo bash -c \"\$(curl -fsSL $SCRIPT)\""
    exit 1
fi
# Downloads made with curl aren't quarantined, but clear the flag in case the zip was.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

open "$APP"
VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist" 2>/dev/null || true)"
echo "Dynamic Island ${VERSION} is installed. Look at the notch at the top of your screen."
