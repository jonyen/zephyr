# Zephyr Rebrand, DMG Installer & Versioning — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Rebrand Spark → Zephyr, create a new wind-themed app icon, add semantic versioning, and build a DMG installer script.

**Architecture:** Shell scripts for versioning and DMG building, Xcode project edits for rebrand, SVG-to-PNG pipeline for icon generation. All changes are in the build/packaging layer — no app logic changes.

**Tech Stack:** Bash, xcodebuild, hdiutil, sips, sed

---

### Task 1: Rebrand Xcode Project — Spark → Zephyr

**Files:**
- Modify: `Spark.xcodeproj/project.pbxproj`
- Modify: `ESVBible/Info.plist`
- Modify: `ESVBible/ESVBibleApp.swift:34`
- Modify: `ESVBible/Services/SpotlightIndexer.swift:35,56,62,77,96,99`
- Modify: `ESVBible/Services/HistoryManager.swift:14`
- Modify: `ESVBible/Services/HighlightManager.swift:16`
- Modify: `ESVBible/Resources/Scripts/spark` → rename to `ESVBible/Resources/Scripts/zephyr`

**Step 1: Update project.pbxproj**

In `Spark.xcodeproj/project.pbxproj`, make these changes:

1. Rename targets: `Spark` → `Zephyr`, `SparkTests` → `ZephyrTests`
2. Rename product references: `Spark.app` → `Zephyr.app`, `SparkTests.xctest` → `ZephyrTests.xctest`
3. Update `PRODUCT_BUNDLE_IDENTIFIER`: `com.esv.bible` → `com.esv.bible.zephyr` (app target), `com.esv.bible.tests` → `com.esv.bible.zephyr.tests` (test target)
4. Update `MARKETING_VERSION`: `1.0` → `1.0.0` (add patch component for semver)
5. Update `TEST_HOST` paths: `Spark.app/Contents/MacOS/Spark` → `Zephyr.app/Contents/MacOS/Zephyr`
6. Update scheme comment references from `Spark` to `Zephyr`

**Step 2: Update Info.plist**

Change URL scheme from `spark` to `zephyr` and bundle URL name from `com.esv.bible.spark` to `com.esv.bible.zephyr`:

```xml
<key>CFBundleURLName</key>
<string>com.esv.bible.zephyr</string>
<key>CFBundleURLSchemes</key>
<array>
    <string>zephyr</string>
</array>
```

**Step 3: Update ESVBibleApp.swift**

Change line 34 from:
```swift
guard let url = urls.first, url.scheme == "spark" else { return }
```
to:
```swift
guard let url = urls.first, url.scheme == "zephyr" else { return }
```

**Step 4: Update SpotlightIndexer.swift**

Replace all `spark-bible` with `zephyr-bible` and `com.spark.bible` with `com.zephyr.bible`:
- Line 35: `"spark-bible:\(bookName):\(chapter.number)"` → `"zephyr-bible:\(bookName):\(chapter.number)"`
- Line 56: `"com.spark.bible"` → `"com.zephyr.bible"`
- Line 62: `"spark-bible:\(bookName):\(chapter.number):\(verse.number)"` → `"zephyr-bible:\(bookName):\(chapter.number):\(verse.number)"`
- Line 77: `"com.spark.bible"` → `"com.zephyr.bible"`
- Line 96: comment `"spark-bible:{Book}:{Chapter}"` → `"zephyr-bible:{Book}:{Chapter}"`
- Line 99: `parts[0] == "spark-bible"` → `parts[0] == "zephyr-bible"`

**Step 5: Update HistoryManager.swift and HighlightManager.swift**

- `HistoryManager.swift:14`: `"Spark"` → `"Zephyr"`
- `HighlightManager.swift:16`: `"Spark"` → `"Zephyr"`

**Step 6: Rename and update the CLI script**

Rename `ESVBible/Resources/Scripts/spark` to `ESVBible/Resources/Scripts/zephyr` and update its contents:
```bash
#!/bin/bash
if [ $# -eq 0 ]; then
    open -a Zephyr
else
    ref="$*"
    url=$(echo "$ref" | sed 's/ /\//g; s/:/\//g')
    open "zephyr://$url"
fi
```

**Step 7: Rename the Xcode scheme**

```bash
mv Spark.xcodeproj/xcshareddata/xcschemes/Spark.xcscheme Spark.xcodeproj/xcshareddata/xcschemes/Zephyr.xcscheme
```

If no shared scheme exists, the scheme is user-local and will be auto-recreated when you open the project. In that case, delete the old user scheme directory content referencing Spark.

**Step 8: Rename the .xcodeproj directory**

```bash
mv Spark.xcodeproj Zephyr.xcodeproj
```

**Step 9: Verify build**

```bash
xcodebuild -project Zephyr.xcodeproj -scheme Zephyr -configuration Release build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

**Step 10: Run tests**

```bash
xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -10
```

Expected: All tests pass.

**Step 11: Commit**

```bash
git add -A
git commit -m "rebrand: rename Spark to Zephyr across project, URL scheme, and services"
```

---

### Task 2: Create App Icon

**Files:**
- Create: `ESVBible/Assets.xcassets/AppIcon.appiconset/icon_1024.png` (master)
- Replace: all `icon_*.png` files in `ESVBible/Assets.xcassets/AppIcon.appiconset/`
- Modify: `ESVBible/Assets.xcassets/AppIcon.appiconset/Contents.json` (if needed)

**Step 1: Create SVG icon source**

Create `scripts/icon.svg` — a wind/breeze motif in blue tones. Design: rounded rectangle background with a gradient from sky blue (#4A9FE5) to deeper blue (#2563EB), with three flowing wind curves in white suggesting a gentle breeze (zephyr). Clean, modern, macOS-appropriate.

**Step 2: Generate PNG from SVG**

Use `sips` or a script to convert the master SVG to a 1024x1024 PNG, then resize to all required sizes:

```bash
# Generate all required sizes from the 1024px master
cd ESVBible/Assets.xcassets/AppIcon.appiconset
for size in 16 32 64 128 256 512 1024; do
    sips -z $size $size icon_1024.png --out icon_${size}.png 2>/dev/null
done
# Create the @2x variants (they're just the 2x resolution file with @2x name)
cp icon_32.png icon_16@2x.png
cp icon_64.png icon_32@2x.png
cp icon_256.png icon_128@2x.png
cp icon_512.png icon_256@2x.png
cp icon_1024.png icon_512@2x.png
# Clean up intermediate sizes
rm -f icon_64.png
```

**Step 3: Remove old icon files**

Delete the old `AppIcon.png` if it still exists.

**Step 4: Verify in Xcode**

```bash
xcodebuild -project Zephyr.xcodeproj -scheme Zephyr -configuration Release build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **` with no asset catalog warnings.

**Step 5: Commit**

```bash
git add ESVBible/Assets.xcassets/AppIcon.appiconset/
git commit -m "feat: add Zephyr wind-themed app icon in blue tones"
```

---

### Task 3: Add Versioning System

**Files:**
- Create: `VERSION`
- Create: `scripts/bump-version.sh`
- Modify: `Zephyr.xcodeproj/project.pbxproj` (MARKETING_VERSION already set in Task 1)

**Step 1: Create VERSION file**

```bash
echo "1.0.0" > VERSION
```

**Step 2: Create bump-version.sh**

Create `scripts/bump-version.sh`:

```bash
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
```

**Step 3: Make executable**

```bash
chmod +x scripts/bump-version.sh
```

**Step 4: Test the script (dry run)**

```bash
cat VERSION
# Expected: 1.0.0
```

**Step 5: Commit**

```bash
git add VERSION scripts/bump-version.sh
git commit -m "feat: add semantic versioning with VERSION file and bump script"
```

---

### Task 4: Create DMG Installer Script

**Files:**
- Create: `scripts/build-dmg.sh`

**Step 1: Create build-dmg.sh**

Create `scripts/build-dmg.sh`:

```bash
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
```

**Step 2: Make executable**

```bash
chmod +x scripts/build-dmg.sh
```

**Step 3: Add dist/ and build/ to .gitignore**

```
build/
dist/
```

**Step 4: Test the script**

```bash
./scripts/build-dmg.sh
```

Expected: `DMG created: dist/Zephyr-1.0.0.dmg` with file size output.

**Step 5: Verify DMG**

```bash
hdiutil attach dist/Zephyr-1.0.0.dmg
ls /Volumes/Zephyr/
hdiutil detach /Volumes/Zephyr
```

Expected: Shows `Zephyr.app` and `Applications` symlink.

**Step 6: Commit**

```bash
git add scripts/build-dmg.sh .gitignore
git commit -m "feat: add DMG installer build script"
```
