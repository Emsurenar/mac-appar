#!/bin/bash
# Builds "build/Hållning.app". Usage: [CONFIG=debug] ./build.sh [--run]
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Hållning.app"
CONFIG="${CONFIG:-release}"
swift build -c "$CONFIG" --arch arm64

[ -f Resources/AppIcon.icns ] || swift Scripts/make-icon.swift .

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/arm64-apple-macosx/$CONFIG/Hallning" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

# A stable signing identity keeps the camera permission across rebuilds;
# without one the app is signed ad hoc.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/"/{print $2; exit}')}"
IDENTITY="${IDENTITY:--}"
codesign --force --sign "$IDENTITY" "$APP"
echo "Built $APP (signed with: $IDENTITY)"

if [ "${1:-}" = "--run" ]; then
    pkill -x Hallning 2>/dev/null || true
    sleep 0.3
    open "$APP"
fi
