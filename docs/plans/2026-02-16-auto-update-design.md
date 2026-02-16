# In-App Auto-Update Feature Design

## Overview

Add automatic update checking and in-app updating using GitHub Releases. The app checks for new versions on launch, shows a banner when an update is available, downloads the new `.app.zip`, replaces itself, and relaunches.

## Update Flow

1. On app launch, check `https://api.github.com/repos/jonyen/zephyr/releases/latest`
2. Parse the release tag (e.g. `v1.1.0`) and compare against the app's `MARKETING_VERSION`
3. If a newer version exists, show a non-intrusive banner with version number and release notes
4. User clicks "Update" — download the `.app.zip` asset from the release
5. Extract to a temp directory, replace the running app, relaunch via a helper script

## Components

### UpdateService (`ESVBible/Services/UpdateService.swift`)

`@Observable` class managing the full update lifecycle.

**State machine:**
- `idle` — no update available or not checked yet
- `updateAvailable(version, releaseNotes, downloadURL)` — newer version found
- `downloading(progress)` — download in progress with 0.0-1.0 progress
- `readyToInstall(localURL)` — download complete, ready to replace
- `error(String)` — something went wrong

**Methods:**
- `checkForUpdate()` — async, hits GitHub API, compares versions
- `downloadUpdate()` — async, downloads zip asset with progress tracking
- `installAndRelaunch()` — extracts zip, spawns helper script to replace app and relaunch

**Version comparison:**
- Semantic versioning: split on `.`, compare major/minor/patch numerically
- Strip leading `v` from GitHub tag

**Relaunch strategy:**
- Write a small shell script to a temp file
- Script: waits for current app PID to exit, moves new .app over old location, opens new app, deletes itself
- Launch script with `Process`, then call `NSApp.terminate(nil)`

### UpdateBannerView (`ESVBible/Views/UpdateBannerView.swift`)

Small SwiftUI banner displayed at the top of the reading pane.

**States:**
- Update available: shows "Zephyr v{X.Y.Z} is available" with release notes preview, "Update" and "Later" buttons
- Downloading: shows progress bar with percentage
- Error: shows error message with "Retry" button

### ContentView changes

- Add `UpdateService` as `@State`
- Show `UpdateBannerView` overlay at top of reading pane when update state is not idle
- Trigger `checkForUpdate()` on appear

### ESVBibleApp changes

- Add "Check for Updates..." menu item with `Cmd+U` shortcut
- Post notification to trigger manual update check

### Build script changes (`Scripts/build-dmg.sh`)

After building the app, also create `Zephyr.app.zip`:
```bash
cd "$BUILD_DIR/Build/Products/Release"
zip -r "$DIST_DIR/Zephyr.app.zip" "Zephyr.app"
```

This zip is what gets uploaded to GitHub Releases alongside the DMG.

## Technical Details

- GitHub API is unauthenticated (60 req/hour rate limit — plenty for update checks)
- No sandbox entitlements needed (app is not sandboxed)
- Download uses `URLSession` with progress delegate
- The app's current version is read from `Bundle.main.infoDictionary["CFBundleShortVersionString"]`
- GitHub API response: `tag_name` for version, `body` for release notes, `assets[].browser_download_url` for download URL (filter for `.zip`)

## Files

- **New:** `ESVBible/Services/UpdateService.swift`
- **New:** `ESVBible/Views/UpdateBannerView.swift`
- **Modify:** `ESVBible/ContentView.swift` — add banner overlay + state
- **Modify:** `ESVBible/ESVBibleApp.swift` — add "Check for Updates" menu item
- **Modify:** `Scripts/build-dmg.sh` — also produce `.app.zip`
