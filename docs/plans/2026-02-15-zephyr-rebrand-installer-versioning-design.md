# Zephyr Rebrand, DMG Installer & Versioning

**Date:** 2026-02-15
**Status:** Approved

## Context

The macOS ESV Bible reader app "Spark" needs to be rebranded to "Zephyr" (name conflict), get a new app icon, a DMG installer for direct distribution, and a semantic versioning system.

## 1. Rebrand: Spark → Zephyr

- Update `PRODUCT_NAME` to `Zephyr` in the Xcode project
- Update `PRODUCT_BUNDLE_IDENTIFIER` to `com.esv.bible.zephyr`
- Update the custom URL scheme from `spark` to `zephyr` in `Info.plist`
- Update user-facing strings (window title references, notification names that surface to users)
- Rename the Xcode scheme from `Spark` to `Zephyr`
- Keep internal directory names (`ESVBible/`) unchanged to minimize churn

## 2. App Icon

- Wind/breeze motif in blue tones, clean modern macOS style
- Create SVG source, then generate all required sizes via `sips`:
  - 16x16, 16x16@2x, 32x32, 32x32@2x, 128x128, 128x128@2x, 256x256, 256x256@2x, 512x512, 512x512@2x
- Update `Contents.json` in the AppIcon asset catalog
- Remove old Spark icon files

## 3. Versioning System

- **Single source of truth:** `VERSION` file at repo root (e.g. `1.0.0`)
- **`scripts/bump-version.sh [major|minor|patch]`:**
  - Reads current version from `VERSION`
  - Bumps the specified component
  - Updates `MARKETING_VERSION` in the Xcode project
  - Writes new version to `VERSION`
  - Commits the change
  - Creates git tag `vX.Y.Z`
- **Build number:** `CURRENT_PROJECT_VERSION` set to git commit count via a build phase script, so it auto-increments

## 4. DMG Installer

- **`scripts/build-dmg.sh`:**
  1. Reads version from `VERSION`
  2. Builds Release configuration via `xcodebuild -scheme Zephyr -configuration Release`
  3. Creates a staging directory with `Zephyr.app` and an `Applications` symlink
  4. Uses `hdiutil` to create `Zephyr-X.Y.Z.dmg`
  5. Outputs DMG to `dist/` directory
- Simple DMG layout (app + Applications symlink, no custom background)
- No external dependencies — just `xcodebuild` and `hdiutil`

## Decisions

- **Distribution:** Direct download now, potentially Mac App Store later
- **Versioning:** Semantic versioning with git tags
- **DMG style:** Simple (no custom background artwork)
- **Build tool:** Shell scripts + hdiutil (no external dependencies)
- **Internal code structure:** Keep `ESVBible/` directory names to avoid unnecessary churn
