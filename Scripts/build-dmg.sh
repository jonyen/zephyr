#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION="${VERSION:-$(cat "$ROOT_DIR/VERSION")}"
APP_NAME="Zephyr"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR="$ROOT_DIR/build"
DIST_DIR="$ROOT_DIR/dist"
STAGING_DIR="$BUILD_DIR/dmg-staging"

echo "Building ${APP_NAME} v${VERSION}..."

# Build the app.
#
# Output goes to a log rather than through `tail`, which used to discard the compiler
# errors along with everything else — a failed CI build reported only "(2 failures)" with
# no indication of what failed. On success we still show just the tail; on failure the log
# is dumped in full.
# The log lives outside BUILD_DIR on purpose: `xcodebuild clean` deletes the
# derivedDataPath, which would take the log with it and leave a failure with no output.
BUILD_LOG=$(mktemp "${TMPDIR:-/tmp}/zephyr-xcodebuild.XXXXXX.log")
trap 'rm -f "$BUILD_LOG"' EXIT

if xcodebuild -project "$ROOT_DIR/Zephyr.xcodeproj" \
    -scheme Zephyr \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    CURRENT_PROJECT_VERSION="$VERSION" \
    MARKETING_VERSION="$VERSION" \
    clean build > "$BUILD_LOG" 2>&1; then
    tail -3 "$BUILD_LOG"
else
    status=$?
    echo "Build failed (exit $status). Full xcodebuild output:" >&2
    cat "$BUILD_LOG" >&2
    exit "$status"
fi

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

# Create .app.zip for auto-update
cd "$BUILD_DIR/Build/Products/Release"
zip -r -y "$DIST_DIR/${APP_NAME}.app.zip" "${APP_NAME}.app"
cd "$ROOT_DIR"

# Clean up
rm -rf "$STAGING_DIR"

echo ""
echo "DMG created: dist/$DMG_NAME"
echo "ZIP created: dist/${APP_NAME}.app.zip"
echo "Size (DMG): $(du -h "$DIST_DIR/$DMG_NAME" | cut -f1)"
echo "Size (ZIP): $(du -h "$DIST_DIR/${APP_NAME}.app.zip" | cut -f1)"
