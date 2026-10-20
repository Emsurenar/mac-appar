#!/bin/bash
# Installs the latest Sträckis release into /Applications and opens it.
#   curl -fsSL https://raw.githubusercontent.com/Emsurenar/strackis/main/install.sh | bash
set -euo pipefail

URL="https://github.com/Emsurenar/strackis/releases/latest/download/Strackis.zip"
APP="/Applications/Sträckis.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Sträckis…"
curl -fsSL "$URL" -o "$TMP/Strackis.zip"
ditto -x -k "$TMP/Strackis.zip" "$TMP"

pkill -x Strackis 2>/dev/null || true
if ! { rm -rf "$APP" && ditto "$TMP/Sträckis.app" "$APP"; } 2>/dev/null; then
    echo "Couldn't write to /Applications. Try again with: sudo bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Emsurenar/strackis/main/install.sh)\""
    exit 1
fi
# Downloads made with curl aren't quarantined, but clear the flag in case the zip was.
xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

open "$APP"
echo "Done! Sträckis now lives in your menu bar."
