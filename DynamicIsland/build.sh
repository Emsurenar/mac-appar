#!/bin/bash
# Builds "build/Dynamic Island.app". Usage: [CONFIG=debug] ./build.sh [--with-companions] [--run]
#   --with-companions  also builds Posture and Unknot and puts them inside the app, like the release
set -euo pipefail
cd "$(dirname "$0")"

RUN=false
COMPANIONS=false
for arg in "$@"; do
    case "$arg" in
        --run) RUN=true ;;
        --with-companions) COMPANIONS=true ;;
        *) echo "Unknown option: $arg"; exit 1 ;;
    esac
done

APP="build/Dynamic Island.app"
CONFIG="${CONFIG:-release}"
swift build -c "$CONFIG" --arch arm64

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/arm64-apple-macosx/$CONFIG/DynamicIsland" "$APP/Contents/MacOS/"
cp Resources/Info.plist "$APP/Contents/"
[ -f Resources/AppIcon.icns ] && cp Resources/AppIcon.icns "$APP/Contents/Resources/"

clang -fobjc-arc -O2 -dynamiclib -mmacosx-version-min=14.0 -framework Foundation \
    -o "$APP/Contents/Resources/libNowPlayingBridge.dylib" Bridge/NowPlayingBridge.m

# A stable signing identity keeps the Accessibility permission across rebuilds;
# without one the app is signed ad hoc.
IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | awk -F'"' '/"/{print $2; exit}')}"
IDENTITY="${IDENTITY:--}"
codesign --force --sign "$IDENTITY" "$APP/Contents/Resources/libNowPlayingBridge.dylib"

if $COMPANIONS; then
    # The island runs these from Contents/Library/Helpers. Each keeps its own signature, made before the island's.
    HELPERS="$APP/Contents/Library/Helpers"
    mkdir -p "$HELPERS"
    ../Posture/build.sh
    ditto ../Posture/build/Posture.app "$HELPERS/Posture.app"
    ../Unknot/build.sh --release
    ditto ../Unknot/build/Unknot.app "$HELPERS/Unknot.app"
    codesign --force --sign "$IDENTITY" "$HELPERS/Posture.app"
    codesign --force --sign "$IDENTITY" "$HELPERS/Unknot.app"
fi

codesign --force --sign "$IDENTITY" "$APP"
echo "Built $APP (signed with: $IDENTITY)"

if $RUN; then
    pkill -x DynamicIsland 2>/dev/null || true
    sleep 0.3
    open "$APP"
fi
