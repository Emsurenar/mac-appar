#!/bin/bash
# Builds build/Unknot.app.
#   ./build.sh            native architecture, for development
#   ./build.sh --release  universal (Apple silicon + Intel) and dist/Unknot.zip
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Unknot.app"
BIN="$APP/Contents/MacOS/Unknot"
RELEASE=false
[[ "${1:-}" == "--release" ]] && RELEASE=true

echo "→ Checking translations"
python3 scripts/check_translations.py

rm -rf "$APP" build/obj build/icon
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/obj build/icon/AppIcon.iconset

ARCHS=("$(uname -m)")
$RELEASE && ARCHS=(arm64 x86_64)
for arch in "${ARCHS[@]}"; do
    echo "→ Compiling for $arch"
    swiftc -O -swift-version 5 -parse-as-library \
        -target "$arch-apple-macos13.0" \
        Sources/*.swift -o "build/obj/Unknot-$arch"
done
lipo -create build/obj/Unknot-* -output "$BIN"

cp Info.plist "$APP/Contents/Info.plist"
# The build number is the number of commits, so every release build is unique.
if git rev-parse --git-dir >/dev/null 2>&1; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(git rev-list --count HEAD)" "$APP/Contents/Info.plist"
fi
cp -R Resources/*.lproj "$APP/Contents/Resources/"

echo "→ Drawing the app icon"
"$BIN" --icon build/icon/icon.png
for s in 16 32 128 256 512; do
    sips -z $s $s build/icon/icon.png --out "build/icon/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) build/icon/icon.png --out "build/icon/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns build/icon/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"

codesign --force --deep --sign - "$APP" >/dev/null

echo "→ Self-test"
"$BIN" --selftest

if $RELEASE; then
    mkdir -p dist
    rm -f dist/Unknot.zip
    ditto -c -k --sequesterRsrc --keepParent "$APP" dist/Unknot.zip
    echo "→ dist/Unknot.zip ($(du -h dist/Unknot.zip | cut -f1)) for $(lipo -archs "$BIN")"
fi
echo "✓ Built $APP"
