#!/bin/bash
set -e

cd "$(dirname "$0")/.."

echo "==> Building Notchify (release)..."
swift build -c release --product Notchify ${SWIFT_BUILD_FLAGS:-}
swift build -c release --product notchify-cli ${SWIFT_BUILD_FLAGS:-}

APP_NAME="Notchify.app"
CONTENTS="$APP_NAME/Contents"
MACOS_DIR="$CONTENTS/MacOS"
RESOURCES_DIR="$CONTENTS/Resources"

rm -rf "$APP_NAME"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp .build/release/Notchify      "$MACOS_DIR/Notchify"
cp .build/release/notchify-cli  "$MACOS_DIR/notchify-cli"

# SPM resource bundle — must sit at Notchify.app/Notchify_Notchify.bundle
# because Bundle.module resolves to Bundle.main.bundleURL + bundle name
if [ -d ".build/release/Notchify_Notchify.bundle" ]; then
    cp -r .build/release/Notchify_Notchify.bundle "$APP_NAME/"
fi

# ---- Info.plist ----
cat > "$CONTENTS/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Notchify</string>
    <key>CFBundleIdentifier</key>
    <string>com.notchify.app</string>
    <key>CFBundleName</key>
    <string>Notchify</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# ---- Ad-hoc sign binaries (required for macOS to run from .app bundle) ----
# || true: signing is best-effort; CI runners may not support it
codesign --force --sign - "$MACOS_DIR/Notchify"     2>/dev/null || true
codesign --force --sign - "$MACOS_DIR/notchify-cli" 2>/dev/null || true
codesign --force --sign - "$APP_NAME"               2>/dev/null || true
echo "==> Signed binaries"

echo "==> App bundle created: $(pwd)/$APP_NAME"
echo ""
echo "Run setup to install CLI, hooks and launch the app:"
echo "  ./scripts/setup.sh"
