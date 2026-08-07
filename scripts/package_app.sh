#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

swift build --product CatalinaWeb

APP="$ROOT/build/CatalinaWeb.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
BINARY="$ROOT/.build/debug/CatalinaWeb"

rm -rf "$APP"
mkdir -p "$MACOS"
cp "$BINARY" "$MACOS/CatalinaWeb"
chmod 755 "$MACOS/CatalinaWeb"

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CatalinaWeb</string>
    <key>CFBundleIdentifier</key>
    <string>com.catalinaweb.CatalinaWeb</string>
    <key>CFBundleName</key>
    <string>CatalinaWeb</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.15</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign - "$APP"
printf 'Packaged %s\n' "$APP"
