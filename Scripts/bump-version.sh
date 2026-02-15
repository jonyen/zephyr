#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
VERSION_FILE="$ROOT_DIR/VERSION"
PBXPROJ="$ROOT_DIR/Zephyr.xcodeproj/project.pbxproj"

if [ $# -ne 1 ] || [[ ! "$1" =~ ^(major|minor|patch)$ ]]; then
    echo "Usage: $0 [major|minor|patch]"
    exit 1
fi

CURRENT=$(cat "$VERSION_FILE")
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT"

case "$1" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
echo "$NEW_VERSION" > "$VERSION_FILE"

# Update MARKETING_VERSION in pbxproj
sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $NEW_VERSION/" "$PBXPROJ"

echo "Bumped version: $CURRENT → $NEW_VERSION"

git add "$VERSION_FILE" "$PBXPROJ"
git commit -m "release: bump version to $NEW_VERSION"
git tag "v$NEW_VERSION"

echo "Tagged v$NEW_VERSION"
