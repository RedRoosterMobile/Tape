#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Tape"
APP_DIR="$ROOT_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE_PATH="$MACOS_DIR/$APP_NAME"
SOURCE_FILE="$ROOT_DIR/Sources/Tape/main.swift"
PLIST_FILE="$CONTENTS_DIR/Info.plist"
ICONSET_DIR="$ROOT_DIR/Tape.iconset"
ICON_FILE="$RESOURCES_DIR/Tape.icns"
ICON_RENDERER="$ROOT_DIR/Sources/Tape/render_icon.swift"

rm -rf "$APP_DIR"
rm -rf "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
mkdir -p "$ICONSET_DIR"

cat > "$PLIST_FILE" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>Tape</string>
    <key>CFBundleIdentifier</key>
    <string>com.thomasranker.tape</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>Tape</string>
    <key>CFBundleName</key>
    <string>Tape</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

for size in 16 32 128 256 512; do
    xcrun swift "$ICON_RENDERER" "$size" "$ICONSET_DIR/icon_${size}x${size}.png"
    retina_size=$((size * 2))
    xcrun swift "$ICON_RENDERER" "$retina_size" "$ICONSET_DIR/icon_${size}x${size}@2x.png"
done

iconutil -c icns "$ICONSET_DIR" -o "$ICON_FILE"

xcrun swiftc \
    -O \
    -framework AppKit \
    -framework CoreAudio \
    "$SOURCE_FILE" \
    -o "$EXECUTABLE_PATH"

codesign --force --sign - "$APP_DIR" >/dev/null

rm -rf "$ICONSET_DIR"

echo "Built $APP_DIR"
