# In-App Auto-Update Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add automatic update checking via GitHub Releases with in-app download, replace, and relaunch.

**Architecture:** `UpdateService` checks the GitHub API for new releases, compares semantic versions, downloads `.app.zip` assets, and spawns a helper script to replace the app and relaunch. `UpdateBannerView` shows update status in the reading pane.

**Tech Stack:** SwiftUI, URLSession (async/await with progress), GitHub REST API, shell script for app replacement

---

### Task 1: Add version comparison utility and UpdateService skeleton

**Files:**
- Create: `ESVBible/Services/UpdateService.swift`
- Test: `ESVBibleTests/UpdateServiceTests.swift`

**Step 1: Write the failing tests**

Add to `ESVBibleTests/UpdateServiceTests.swift`:

```swift
import XCTest
@testable import ESVBible

final class UpdateServiceTests: XCTestCase {

    // MARK: - Version comparison

    func testNewerVersionDetected() {
        XCTAssertTrue(UpdateService.isNewer("1.1.0", than: "1.0.0"))
        XCTAssertTrue(UpdateService.isNewer("2.0.0", than: "1.9.9"))
        XCTAssertTrue(UpdateService.isNewer("1.0.1", than: "1.0.0"))
    }

    func testSameVersionNotNewer() {
        XCTAssertFalse(UpdateService.isNewer("1.0.0", than: "1.0.0"))
    }

    func testOlderVersionNotNewer() {
        XCTAssertFalse(UpdateService.isNewer("1.0.0", than: "1.1.0"))
        XCTAssertFalse(UpdateService.isNewer("0.9.0", than: "1.0.0"))
    }

    func testVersionWithVPrefix() {
        XCTAssertTrue(UpdateService.isNewer("v1.1.0", than: "1.0.0"))
        XCTAssertTrue(UpdateService.isNewer("v2.0.0", than: "v1.0.0"))
    }

    // MARK: - GitHub response parsing

    func testParseGitHubRelease() throws {
        let json = """
        {
            "tag_name": "v1.1.0",
            "body": "Bug fixes and improvements",
            "assets": [
                {
                    "name": "Zephyr.app.zip",
                    "browser_download_url": "https://github.com/jonyen/zephyr/releases/download/v1.1.0/Zephyr.app.zip"
                },
                {
                    "name": "Zephyr-1.1.0.dmg",
                    "browser_download_url": "https://github.com/jonyen/zephyr/releases/download/v1.1.0/Zephyr-1.1.0.dmg"
                }
            ]
        }
        """.data(using: .utf8)!

        let release = try JSONDecoder().decode(UpdateService.GitHubRelease.self, from: json)
        XCTAssertEqual(release.tagName, "v1.1.0")
        XCTAssertEqual(release.body, "Bug fixes and improvements")
        XCTAssertEqual(release.assets.count, 2)

        let zipAsset = release.assets.first { $0.name.hasSuffix(".zip") }
        XCTAssertNotNil(zipAsset)
        XCTAssertEqual(zipAsset?.browserDownloadURL, "https://github.com/jonyen/zephyr/releases/download/v1.1.0/Zephyr.app.zip")
    }
}
```

**Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr -only-testing:ZephyrTests/UpdateServiceTests 2>&1 | tail -20`
Expected: FAIL — `UpdateService` not found

**Step 3: Write implementation**

Create `ESVBible/Services/UpdateService.swift`:

```swift
import Foundation
import AppKit

@Observable
class UpdateService {
    enum State: Equatable {
        case idle
        case checking
        case updateAvailable(version: String, notes: String, downloadURL: URL)
        case downloading(progress: Double)
        case readyToInstall(localURL: URL)
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.checking, .checking): return true
            case let (.updateAvailable(v1, n1, u1), .updateAvailable(v2, n2, u2)):
                return v1 == v2 && n1 == n2 && u1 == u2
            case let (.downloading(p1), .downloading(p2)): return p1 == p2
            case let (.readyToInstall(u1), .readyToInstall(u2)): return u1 == u2
            case let (.error(e1), .error(e2)): return e1 == e2
            default: return false
            }
        }
    }

    struct GitHubRelease: Codable {
        let tagName: String
        let body: String?
        let assets: [Asset]

        struct Asset: Codable {
            let name: String
            let browserDownloadURL: String

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case body
            case assets
        }
    }

    private(set) var state: State = .idle
    private let repoOwner = "jonyen"
    private let repoName = "zephyr"

    var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    // MARK: - Version comparison

    static func isNewer(_ remote: String, than local: String) -> Bool {
        let r = parseVersion(remote)
        let l = parseVersion(local)
        if r.major != l.major { return r.major > l.major }
        if r.minor != l.minor { return r.minor > l.minor }
        return r.patch > l.patch
    }

    private static func parseVersion(_ version: String) -> (major: Int, minor: Int, patch: Int) {
        let cleaned = version.hasPrefix("v") ? String(version.dropFirst()) : version
        let parts = cleaned.split(separator: ".").compactMap { Int($0) }
        return (
            major: parts.count > 0 ? parts[0] : 0,
            minor: parts.count > 1 ? parts[1] : 0,
            patch: parts.count > 2 ? parts[2] : 0
        )
    }

    // MARK: - Check for updates

    func checkForUpdate() async {
        state = .checking
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            state = .error("Invalid API URL")
            return
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                state = .error("Failed to check for updates")
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let remoteVersion = release.tagName

            guard Self.isNewer(remoteVersion, than: currentAppVersion) else {
                state = .idle
                return
            }

            guard let zipAsset = release.assets.first(where: { $0.name.hasSuffix(".zip") }),
                  let downloadURL = URL(string: zipAsset.browserDownloadURL) else {
                state = .error("No downloadable update found")
                return
            }

            let cleanVersion = remoteVersion.hasPrefix("v") ? String(remoteVersion.dropFirst()) : remoteVersion
            state = .updateAvailable(
                version: cleanVersion,
                notes: release.body ?? "No release notes.",
                downloadURL: downloadURL
            )
        } catch {
            state = .error("Update check failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Download update

    func downloadUpdate(from url: URL) async {
        state = .downloading(progress: 0)

        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url, delegate: nil)

            // Move to a stable temp location
            let destURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("ZephyrUpdate-\(UUID().uuidString).zip")
            try FileManager.default.moveItem(at: tempURL, to: destURL)

            state = .readyToInstall(localURL: destURL)
        } catch {
            state = .error("Download failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Install and relaunch

    func installAndRelaunch(from zipURL: URL) {
        guard let appBundlePath = Bundle.main.bundlePath as String? else {
            state = .error("Cannot determine app location")
            return
        }

        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZephyrExtract-\(UUID().uuidString)")

        // Extract zip
        let unzipProcess = Process()
        unzipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzipProcess.arguments = ["-xk", zipURL.path, extractDir.path]

        do {
            try unzipProcess.run()
            unzipProcess.waitUntilExit()
        } catch {
            state = .error("Failed to extract update: \(error.localizedDescription)")
            return
        }

        guard unzipProcess.terminationStatus == 0 else {
            state = .error("Failed to extract update")
            return
        }

        // Find the .app in the extracted directory
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: extractDir.path)) ?? []
        guard let appName = contents.first(where: { $0.hasSuffix(".app") }) else {
            state = .error("No .app found in update")
            return
        }
        let newAppPath = extractDir.appendingPathComponent(appName).path

        // Write and execute relaunch script
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        #!/bin/bash
        # Wait for the app to quit
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        # Replace the app
        rm -rf "\(appBundlePath)"
        mv "\(newAppPath)" "\(appBundlePath)"
        # Clean up
        rm -rf "\(extractDir.path)"
        rm -f "\(zipURL.path)"
        # Relaunch
        open "\(appBundlePath)"
        # Delete this script
        rm -f "$0"
        """

        let scriptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("zephyr-update.sh")
        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptURL.path
            )
        } catch {
            state = .error("Failed to prepare update: \(error.localizedDescription)")
            return
        }

        let launchProcess = Process()
        launchProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
        launchProcess.arguments = [scriptURL.path]
        try? launchProcess.run()

        // Quit the current app
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }

    func dismiss() {
        state = .idle
    }
}
```

**Step 4: Add file to Xcode project and run tests**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr -only-testing:ZephyrTests/UpdateServiceTests 2>&1 | tail -20`
Expected: PASS (all 5 tests)

**Step 5: Commit**

```bash
git add ESVBible/Services/UpdateService.swift ESVBibleTests/UpdateServiceTests.swift Zephyr.xcodeproj/project.pbxproj
git commit -m "feat: add UpdateService with version comparison and GitHub release checking"
```

---

### Task 2: Create UpdateBannerView

**Files:**
- Create: `ESVBible/Views/UpdateBannerView.swift`

**Step 1: Create the banner view**

```swift
import SwiftUI

struct UpdateBannerView: View {
    let updateService: UpdateService

    var body: some View {
        switch updateService.state {
        case .idle, .checking:
            EmptyView()

        case let .updateAvailable(version, notes, downloadURL):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Zephyr v\(version) is available")
                        .font(.headline)
                    Spacer()
                    Button {
                        updateService.dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                HStack {
                    Spacer()
                    Button("Later") {
                        updateService.dismiss()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Button("Update") {
                        Task {
                            await updateService.downloadUpdate(from: downloadURL)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 48)
            .padding(.top, 12)
            .transition(.move(edge: .top).combined(with: .opacity))

        case let .downloading(progress):
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.blue)
                    Text("Downloading update...")
                        .font(.headline)
                    Spacer()
                }
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 48)
            .padding(.top, 12)

        case let .readyToInstall(localURL):
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Update ready to install")
                        .font(.headline)
                    Spacer()
                }
                HStack {
                    Spacer()
                    Button("Install & Relaunch") {
                        updateService.installAndRelaunch(from: localURL)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 48)
            .padding(.top, 12)

        case let .error(message):
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.caption)
                Spacer()
                Button("Retry") {
                    Task {
                        await updateService.checkForUpdate()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Button {
                    updateService.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.separator, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
            .padding(.horizontal, 48)
            .padding(.top, 12)
        }
    }
}
```

**Step 2: Add to Xcode project and verify build**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 3: Commit**

```bash
git add ESVBible/Views/UpdateBannerView.swift Zephyr.xcodeproj/project.pbxproj
git commit -m "feat: add UpdateBannerView for in-app update notifications"
```

---

### Task 3: Integrate UpdateService and banner into ContentView

**Files:**
- Modify: `ESVBible/ContentView.swift`

**Step 1: Add state and banner**

1. Add state variable near the top of ContentView:
```swift
@State private var updateService = UpdateService()
```

2. In `mainContent`, add the `UpdateBannerView` overlay inside the `ZStack`, right after the reading pane `Group` block and before the tap-to-dismiss layer:
```swift
// Update banner overlay
UpdateBannerView(updateService: updateService)
    .zIndex(5)
```

3. Add update check on appear — in the existing `.onAppear` modifier, add at the end:
```swift
Task {
    await updateService.checkForUpdate()
}
```

4. Add notification receiver for manual check:
```swift
.onReceive(NotificationCenter.default.publisher(for: .checkForUpdates)) { _ in
    Task {
        await updateService.checkForUpdate()
    }
}
```

**Step 2: Verify build**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -20`
Expected: BUILD SUCCEEDED (will fail until Task 4 adds the notification name — if so, add a placeholder `.checkForUpdates` notification name to ESVBibleApp.swift first)

**Step 3: Commit**

```bash
git add ESVBible/ContentView.swift
git commit -m "feat: integrate update banner and auto-check in ContentView"
```

---

### Task 4: Add "Check for Updates" menu command and notification

**Files:**
- Modify: `ESVBible/ESVBibleApp.swift`

**Step 1: Add notification name**

In the `Notification.Name` extension, add:
```swift
static let checkForUpdates = Notification.Name("checkForUpdates")
```

**Step 2: Add menu command**

In `ESVBibleApp.body` commands, add after the "Keyboard Shortcuts" button:
```swift
Divider()

Button("Check for Updates...") {
    NotificationCenter.default.post(name: .checkForUpdates, object: nil)
}
.keyboardShortcut("u", modifiers: .command)
```

**Step 3: Verify build**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add ESVBible/ESVBibleApp.swift
git commit -m "feat: add Check for Updates menu command with Cmd+U"
```

---

### Task 5: Update build script to produce .app.zip

**Files:**
- Modify: `Scripts/build-dmg.sh`

**Step 1: Add zip creation**

After the DMG creation section (after `hdiutil create ...`) and before the cleanup section, add:

```bash
# Create .app.zip for auto-update
cd "$BUILD_DIR/Build/Products/Release"
zip -r -y "$DIST_DIR/${APP_NAME}.app.zip" "${APP_NAME}.app"
cd "$ROOT_DIR"
```

Update the final echo to also mention the zip:

```bash
echo "DMG created: dist/$DMG_NAME"
echo "ZIP created: dist/${APP_NAME}.app.zip"
echo "Size (DMG): $(du -h "$DIST_DIR/$DMG_NAME" | cut -f1)"
echo "Size (ZIP): $(du -h "$DIST_DIR/${APP_NAME}.app.zip" | cut -f1)"
```

**Step 2: Test the script runs (optional — skip if no Xcode available)**

Run: `bash Scripts/build-dmg.sh` (only if you want to test the full build)

**Step 3: Commit**

```bash
git add Scripts/build-dmg.sh
git commit -m "feat: build script also produces .app.zip for auto-update"
```

---

### Task 6: Run full test suite and verify

**Step 1: Run all tests**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -30`
Expected: All tests PASS

**Step 2: Build**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme Zephyr 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 3: Check git log**

Run: `git log --oneline -10`
