#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION=$(cat "$ROOT_DIR/VERSION")
APP_NAME="Zephyr"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$BUILD_DIR/dmg-staging"

echo "Building ${APP_NAME} v${VERSION}..."

# Build the app
xcodebuild -project "$ROOT_DIR/Zephyr.xcodeproj" \
    -scheme Zephyr \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CURRENT_PROJECT_VERSION="$(git -C "$ROOT_DIR" rev-list --count HEAD)" \
    clean build 2>&1 | tail -3

APP_PATH="$BUILD_DIR/Build/Products/Release/${APP_NAME}.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: ${APP_NAME}.app not found at $APP_PATH"
    exit 1
fi

# Prepare staging directory
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
mkdir -p "$DIST_DIR"
rm -f "$DIST_DIR/$DMG_NAME"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DIST_DIR/$DMG_NAME"

# Clean up
rm -rf "$STAGING_DIR"

echo ""
echo "DMG created: dist/$DMG_NAME"
echo "Size: $(du -h "$DIST_DIR/$DMG_NAME" | cut -f1)"
