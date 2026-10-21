#!/bin/bash
# Installs the latest Unknot release into /Applications and opens it.
#   curl -fsSL https://raw.githubusercontent.com/Emsurenar/unknot/main/install.sh | bash
set -euo pipefail

URL="https://github.com/Emsurenar/unknot/releases/latest/download/Unknot.zip"
APP="/Applications/Unknot.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Unknot…"
curl -fsSL "$URL" -o "$TMP/Unknot.zip"
ditto -x -k "$TMP/Unknot.zip" "$TMP"

# Quit a running copy (also the old Sträckis) and wait until it's gone, or opening the new one fails.
pkill -x Unknot 2>/dev/null || true
pkill -x Strackis 2>/dev/null || true
for _ in $(seq 1 50); do
    pgrep -xq Unknot || pgrep -xq Strackis || break
    sleep 0.1
done
rm -rf "/Applications/Sträckis.app" 2>/dev/null || true

if ! { rm -rf "$APP" && ditto "$TMP/Unknot.app" "$APP"; } 2>/dev/null; then
    echo "Couldn't write to /Applications. Try again with: sudo bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Emsurenar/unknot/main/install.sh)\""
    exit 1
fi
# Downloads made with curl aren't quarantined, but clear the flag in case the zip was.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

open "$APP"
echo "Done! Unknot now lives in your menu bar."
