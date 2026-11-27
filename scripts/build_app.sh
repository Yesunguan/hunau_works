#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EXEC_NAME="GlassHomework"
DISPLAY_NAME="湘农作业"
BUNDLE_ID="com.glasshomework.app"
BUILD_DIR="$ROOT_DIR/.build-bundle"
APP_BUNDLE="$BUILD_DIR/$DISPLAY_NAME.app"
INSTALL_PATH="/Applications/$DISPLAY_NAME.app"
LEGACY_INSTALL_PATH="/Applications/GlassHomework.app"
BADGE_PNG="$ROOT_DIR/Sources/GlassHomeworkApp/Resources/AppBadge.png"

echo "==> [1/5] Building native Apple Silicon (arm64) release binary..."
cd "$ROOT_DIR"
arch -arm64 swift build -c release

BIN_PATH="$(arch -arm64 swift build -c release --show-bin-path)/$EXEC_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
    echo "ERROR: Built executable not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> [2/5] Generating AppIcon.icns from AppBadge.png..."
rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
arch -arm64 swift "$ROOT_DIR/scripts/generate_icon.swift" "$BADGE_PNG" "$ICONSET_DIR"
iconutil -c icns "$ICONSET_DIR" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "==> [3/5] Assembling $DISPLAY_NAME.app bundle..."
cp "$BIN_PATH" "$APP_BUNDLE/Contents/MacOS/$EXEC_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXEC_NAME"
cp "$BADGE_PNG" "$APP_BUNDLE/Contents/Resources/AppBadge.png"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$EXEC_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$DISPLAY_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>26.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> [4/5] Applying ad-hoc codesign..."
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "==> [5/5] Installing to $INSTALL_PATH..."
if pgrep -x "$EXEC_NAME" >/dev/null 2>&1; then
    killall "$EXEC_NAME" || true
    sleep 0.5
fi
rm -rf "$LEGACY_INSTALL_PATH" "$INSTALL_PATH"
cp -R "$APP_BUNDLE" "$INSTALL_PATH"
codesign --verify --deep --strict "$INSTALL_PATH"

echo "==> Done! Installed $INSTALL_PATH"
file "$INSTALL_PATH/Contents/MacOS/$EXEC_NAME"
