#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/AgentDock.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building AgentDock..."
cd "$PROJECT_DIR"
swift build -c release

echo "Creating .app bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

echo "Copying binary..."
cp "$PROJECT_DIR/.build/release/AgentDock" "$MACOS/AgentDock"
chmod +x "$MACOS/AgentDock"

echo "Copying Info.plist..."
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"

echo "Fixing rpath..."
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS/AgentDock" 2>/dev/null || true

echo "Copying SPM resource bundle..."
RESOURCE_BUNDLE="$PROJECT_DIR/.build/release/AgentDock_AgentDock.bundle"
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$RESOURCES/"
fi

echo ""
echo "Build complete: $APP_BUNDLE"
echo "Run: open $APP_BUNDLE"
