# Flag Text Issues From Reader — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user flag a text-rendering issue from inside the reader with one click and (optionally) one sentence, and have a GitHub issue filed automatically on `jonyen/zephyr`. Leverage the existing highlights feature so the flag itself is also a persistent visual marker.

**Architecture:** Three new units with clear boundaries: `KeychainTokenStore` (PAT storage), `IssueReporterService` (GitHub API calls + fallback URL building), `FlagIssueSheet` (SwiftUI composer). The reader's existing NSMenu selection context gains a `Flag Text Issue…` item that both writes a `.flag`-colored highlight through the existing `HighlightManager` path and opens the sheet. A new GitHub tab in Settings holds the PAT configuration.

**Tech Stack:** Swift / SwiftUI / AppKit, XCTest, URLSession, Security framework (Keychain). Patterned on the existing `UpdateService` for GitHub API calls and on `NotePopoverView` for sheet presentation from the context menu.

**Spec:** `docs/superpowers/specs/2026-04-12-flag-text-issue-design.md`

**Code conventions discovered during planning:**
- Services live in `ESVBible/Services/`, tested in `ESVBibleTests/`.
- Services that need observation use `@Observable` (see `UpdateService`, `HighlightManager`).
- Tests use XCTest with `@testable import ESVBible`.
- Managers that touch disk take an optional injectable location in init for tests (see `HighlightManager(storageDirectory:)`).
- The `HighlightableTextView` right-click menu in `SelectableTextView.swift` already owns the "selection → action" UX; we extend it rather than introducing a popover.
- Settings is a SwiftUI `Settings { TabView { … } }` block in `ESVBibleApp.swift`.

---

## File Structure

**New files:**
- `ESVBible/Services/KeychainTokenStore.swift` — GitHub PAT Keychain storage (static API).
- `ESVBible/Services/IssueReporterService.swift` — GitHub API client + fallback URL builder. Also contains `IssueReport` struct and `IssueReporterError` enum.
- `ESVBible/Services/IssueBodyFormatter.swift` — pure functions for building the issue title, body, and percent-encoded fallback URL. Zero I/O, easy to unit test.
- `ESVBible/Views/FlagIssueSheet.swift` — SwiftUI sheet with selection preview + single "What's wrong?" text field.
- `ESVBible/Views/GitHubSettingsView.swift` — SwiftUI view for the new Settings → GitHub tab.
- `ESVBibleTests/KeychainTokenStoreTests.swift`
- `ESVBibleTests/IssueBodyFormatterTests.swift`
- `ESVBibleTests/IssueReporterServiceTests.swift`

**Modified files:**
- `ESVBible/Models/BibleModels.swift` — add `.flag` case to `HighlightColor` + color mappings.
- `ESVBible/Views/SelectableTextView.swift` — new `onFlagIssue` callback on outer struct + Coordinator; new `Flag Text Issue…` menu item in `HighlightableTextView.menu(for:)`; new `flagIssue(_:)` @objc method; filter `.flag` out of the existing `for color in HighlightColor.allCases` loop.
- `ESVBible/ReadingPaneView.swift` — `ChapterView` wires up `onFlagIssue`, owns the sheet `@State`, and presents `FlagIssueSheet`.
- `ESVBible/ESVBibleApp.swift` — add `GitHubSettingsView` tab to the `Settings { TabView { … } }` block.
- `ESVBibleTests/HighlightManagerTests.swift` — one added test for `.flag` color round-trip through JSON.

---

## Task 1: Add `.flag` case to `HighlightColor`

**Files:**
- Modify: `ESVBible/Models/BibleModels.swift:82-111`
- Test: `ESVBibleTests/BibleModelsTests.swift` (existing file; add one test)

**Context:** `HighlightColor` is a `CaseIterable` enum with three color accessors: `nsColor`, `swiftUIColor`, `scrubberColor`. We add `.flag` and supply all three. The color is a distinct reddish-orange that does not collide with `pink` or any existing shade. `CaseIterable` ordering puts new cases at the end by default.

- [ ] **Step 1: Write the failing test**

Append to `ESVBibleTests/BibleModelsTests.swift` (or create the file if it doesn't already contain a `HighlightColorTests` class — check first, and if it exists, add the test method inside it):

```swift
func testHighlightColorFlagCase() {
    // Flag case exists and is distinct from existing colors
    XCTAssertTrue(HighlightColor.allCases.contains(.flag))
    XCTAssertNotEqual(HighlightColor.flag, .yellow)
    XCTAssertNotEqual(HighlightColor.flag, .pink)

    // All three color accessors return a non-nil color and don't crash
    _ = HighlightColor.flag.nsColor
    _ = HighlightColor.flag.swiftUIColor
    _ = HighlightColor.flag.scrubberColor

    // Round-trips through JSON
    let encoded = try! JSONEncoder().encode(HighlightColor.flag)
    let decoded = try! JSONDecoder().decode(HighlightColor.self, from: encoded)
    XCTAssertEqual(decoded, .flag)
}
```

If `BibleModelsTests.swift` doesn't exist, create it:

```swift
import XCTest
@testable import ESVBible

final class HighlightColorTests: XCTestCase {
    func testHighlightColorFlagCase() {
        // ... same body as above
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme ESVBible -only-testing:ESVBibleTests/HighlightColorTests/testHighlightColorFlagCase 2>&1 | tail -40`

Expected: FAIL with "type 'HighlightColor' has no member 'flag'".

- [ ] **Step 3: Add the `.flag` case to `HighlightColor`**

Replace the `HighlightColor` enum in `ESVBible/Models/BibleModels.swift:82-111` with:

```swift
enum HighlightColor: String, Codable, CaseIterable {
    case yellow, green, blue, pink, flag

    var nsColor: NSColor {
        switch self {
        case .yellow: return NSColor.systemYellow.withAlphaComponent(0.35)
        case .green: return NSColor.systemGreen.withAlphaComponent(0.35)
        case .blue: return NSColor.systemBlue.withAlphaComponent(0.25)
        case .pink: return NSColor.systemPink.withAlphaComponent(0.3)
        case .flag: return NSColor.systemRed.withAlphaComponent(0.35)
        }
    }

    var swiftUIColor: Color {
        switch self {
        case .yellow: return Color.yellow.opacity(0.35)
        case .green: return Color.green.opacity(0.35)
        case .blue: return Color.blue.opacity(0.25)
        case .pink: return Color.pink.opacity(0.3)
        case .flag: return Color.red.opacity(0.35)
        }
    }

    var scrubberColor: Color {
        switch self {
        case .yellow: return Color.yellow.opacity(0.85)
        case .green: return Color.green.opacity(0.85)
        case .blue: return Color.blue.opacity(0.8)
        case .pink: return Color.pink.opacity(0.85)
        case .flag: return Color.red.opacity(0.85)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme ESVBible -only-testing:ESVBibleTests/HighlightColorTests 2>&1 | tail -20`

Expected: PASS. Also verify that existing `HighlightManagerTests` still pass (no case was removed, only added, and `CaseIterable` still works).

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme ESVBible -only-testing:ESVBibleTests/HighlightManagerTests 2>&1 | tail -10`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ESVBible/Models/BibleModels.swift ESVBibleTests/BibleModelsTests.swift
git commit -m "feat: add .flag case to HighlightColor enum"
```

---

## Task 2: `KeychainTokenStore`

**Files:**
- Create: `ESVBible/Services/KeychainTokenStore.swift`
- Test: `ESVBibleTests/KeychainTokenStoreTests.swift`

**Context:** Stores a single GitHub PAT in the macOS Keychain under a fixed service name. Tests must use a test-specific service name so real Keychain entries are never touched. We use a struct with a configurable `service` property (defaults to production name) rather than all-static methods, so tests can inject their own isolated service name.

- [ ] **Step 1: Write the failing tests**

Create `ESVBibleTests/KeychainTokenStoreTests.swift`:

```swift
import XCTest
@testable import ESVBible

final class KeychainTokenStoreTests: XCTestCase {
    var store: KeychainTokenStore!

    override func setUp() {
        super.setUp()
        // Unique service per test run to avoid colliding with real entries or parallel tests
        store = KeychainTokenStore(service: "com.jonyen.zephyr.test.\(UUID().uuidString)")
    }

    override func tearDown() {
        try? store.delete()
        super.tearDown()
    }

    func testWriteAndRead() throws {
        try store.write("ghp_testtoken12345")
        XCTAssertEqual(store.read(), "ghp_testtoken12345")
    }

    func testReadWithoutWriteReturnsNil() {
        XCTAssertNil(store.read())
    }

    func testWriteOverwritesExisting() throws {
        try store.write("first")
        try store.write("second")
        XCTAssertEqual(store.read(), "second")
    }

    func testDelete() throws {
        try store.write("to_be_deleted")
        try store.delete()
        XCTAssertNil(store.read())
    }

    func testDeleteWhenNothingStoredDoesNotThrow() {
        XCTAssertNoThrow(try store.delete())
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme ESVBible -only-testing:ESVBibleTests/KeychainTokenStoreTests 2>&1 | tail -30`

Expected: FAIL (KeychainTokenStore type does not exist yet).

- [ ] **Step 3: Implement `KeychainTokenStore`**

Create `ESVBible/Services/KeychainTokenStore.swift`:

```swift
import Foundation
import Security

struct KeychainTokenStore {
    static let defaultService = "com.jonyen.zephyr.github-token"
    static let account = "github-pat"

    let service: String

    init(service: String = KeychainTokenStore.defaultService) {
        self.service = service
    }

    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
    }

    func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func write(_ token: String) throws {
        guard let data = token.data(using: .utf8) else {
            throw KeychainError.unexpectedStatus(errSecParam)
        }

        // Delete any existing item first so add always succeeds cleanly
        try? delete()

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.account,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: Self.account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
```

- [ ] **Step 4: Add file to Xcode project**

Add `KeychainTokenStore.swift` to the `ESVBible` target and `KeychainTokenStoreTests.swift` to the `ESVBibleTests` target in `Zephyr.xcodeproj/project.pbxproj`. (If the existing codebase uses a build system with an Xcode project file group-based layout, confirm the file appears under the correct group. Follow the same pattern used by `UpdateService.swift` and `UpdateServiceTests.swift`.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme ESVBible -only-testing:ESVBibleTests/KeychainTokenStoreTests 2>&1 | tail -20`

Expected: PASS (all 5 tests).

- [ ] **Step 6: Commit**

```bash
git add ESVBible/Services/KeychainTokenStore.swift ESVBibleTests/KeychainTokenStoreTests.swift Zephyr.xcodeproj/project.pbxproj
git commit -m "feat: add KeychainTokenStore for GitHub PAT"
```

---

## Task 3: `IssueReport` + `IssueBodyFormatter` (pure functions)

**Files:**
- Create: `ESVBible/Services/IssueBodyFormatter.swift` (contains `IssueReport` struct + `IssueBodyFormatter` enum with static methods)
- Test: `ESVBibleTests/IssueBodyFormatterTests.swift`

**Context:** All string building for the issue (title, body, fallback URL) lives here as pure functions. No I/O, no network, no dependencies on other services — so these tests are fast and exhaustive. The `IssueReport` struct is shared across `IssueReporterService` and `FlagIssueSheet`.

- [ ] **Step 1: Write the failing tests**

Create `ESVBibleTests/IssueBodyFormatterTests.swift`:

```swift
import XCTest
@testable import ESVBible

final class IssueBodyFormatterTests: XCTestCase {

    private func sampleReport(
        note: String = "",
        book: String = "John",
        chapter: Int = 3,
        verseStart: Int = 16,
        verseEnd: Int = 16,
        selectedText: String = "For God so loved the world"
    ) -> IssueReport {
        IssueReport(
            book: book,
            chapter: chapter,
            verseStart: verseStart,
            verseEnd: verseEnd,
            selectedText: selectedText,
            userNote: note,
            appVersion: "0.9.6",
            osVersion: "macOS 15.2",
            timestamp: Date(timeIntervalSince1970: 1_776_000_000) // fixed for reproducibility
        )
    }

    func testTitleWithoutNote() {
        let report = sampleReport(note: "")
        XCTAssertEqual(IssueBodyFormatter.title(for: report), "[text] John 3:16")
    }

    func testTitleWithShortNote() {
        let report = sampleReport(note: "extra space")
        XCTAssertEqual(IssueBodyFormatter.title(for: report), "[text] John 3:16 — extra space")
    }

    func testTitleWithLongNoteGetsTruncated() {
        let longNote = String(repeating: "x", count: 80)
        let report = sampleReport(note: longNote)
        let title = IssueBodyFormatter.title(for: report)
        // Prefix + first 50 chars of note + ellipsis
        XCTAssertEqual(title, "[text] John 3:16 — " + String(repeating: "x", count: 50) + "…")
    }

    func testTitleMultiVerseLocation() {
        let report = sampleReport(verseStart: 16, verseEnd: 18)
        XCTAssertEqual(IssueBodyFormatter.title(for: report), "[text] John 3:16-18")
    }

    func testBodyIncludesAllMetadata() {
        let report = sampleReport(note: "weird spacing")
        let body = IssueBodyFormatter.body(for: report)
        XCTAssertTrue(body.contains("**Location:** John 3:16"))
        XCTAssertTrue(body.contains("> For God so loved the world"))
        XCTAssertTrue(body.contains("weird spacing"))
        XCTAssertTrue(body.contains("Zephyr 0.9.6"))
        XCTAssertTrue(body.contains("macOS 15.2"))
    }

    func testBodyEmptyNoteShowsPlaceholder() {
        let report = sampleReport(note: "")
        let body = IssueBodyFormatter.body(for: report)
        XCTAssertTrue(body.contains("(no note)"))
    }

    func testBodyEscapesBlockquoteMarker() {
        // A selected text that starts with `>` should not break the quote block
        let report = sampleReport(selectedText: "> This would break markdown")
        let body = IssueBodyFormatter.body(for: report)
        // Each line of the selected text should be prefixed with `> ` (our quote marker),
        // and any literal `>` at the start of a user line should be escaped to `\>`.
        XCTAssertTrue(body.contains("> \\> This would break markdown"))
    }

    func testBodySelectedTextWithNewlinesRendersEachLineQuoted() {
        let report = sampleReport(selectedText: "line one\nline two")
        let body = IssueBodyFormatter.body(for: report)
        XCTAssertTrue(body.contains("> line one"))
        XCTAssertTrue(body.contains("> line two"))
    }

    func testFallbackURLEncodesTitleAndBody() {
        let report = sampleReport(note: "hello & goodbye")
        let url = IssueBodyFormatter.fallbackURL(for: report)
        let urlString = url.absoluteString
        XCTAssertTrue(urlString.hasPrefix("https://github.com/jonyen/zephyr/issues/new?"))
        XCTAssertTrue(urlString.contains("title="))
        XCTAssertTrue(urlString.contains("body="))
        XCTAssertTrue(urlString.contains("labels=text-report"))
        // `&` in the note must be percent-encoded so it doesn't break query params
        XCTAssertFalse(urlString.contains("hello & goodbye"))
        XCTAssertTrue(urlString.contains("hello%20%26%20goodbye") || urlString.contains("hello+%26+goodbye"))
    }

    func testLocationStringSingleVerse() {
        XCTAssertEqual(IssueBodyFormatter.locationString(for: sampleReport(verseStart: 16, verseEnd: 16)), "John 3:16")
    }

    func testLocationStringMultiVerse() {
        XCTAssertEqual(IssueBodyFormatter.locationString(for: sampleReport(verseStart: 16, verseEnd: 18)), "John 3:16-18")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme ESVBible -only-testing:ESVBibleTests/IssueBodyFormatterTests 2>&1 | tail -30`

Expected: FAIL — `IssueReport` and `IssueBodyFormatter` do not exist.

- [ ] **Step 3: Implement `IssueReport` and `IssueBodyFormatter`**

Create `ESVBible/Services/IssueBodyFormatter.swift`:

```swift
import Foundation

struct IssueReport: Equatable {
    let book: String
    let chapter: Int
    let verseStart: Int
    let verseEnd: Int
    let selectedText: String
    let userNote: String
    let appVersion: String
    let osVersion: String
    let timestamp: Date
}

enum IssueBodyFormatter {
    static let repoOwner = "jonyen"
    static let repoName = "zephyr"
    static let label = "text-report"
    static let maxNoteInTitle = 50

    static func locationString(for report: IssueReport) -> String {
        if report.verseStart == report.verseEnd {
            return "\(report.book) \(report.chapter):\(report.verseStart)"
        }
        return "\(report.book) \(report.chapter):\(report.verseStart)-\(report.verseEnd)"
    }

    static func title(for report: IssueReport) -> String {
        let location = locationString(for: report)
        let prefix = "[text] \(location)"
        let trimmed = report.userNote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return prefix }
        if trimmed.count <= maxNoteInTitle {
            return "\(prefix) — \(trimmed)"
        }
        let cutIndex = trimmed.index(trimmed.startIndex, offsetBy: maxNoteInTitle)
        return "\(prefix) — \(trimmed[..<cutIndex])…"
    }

    static func body(for report: IssueReport) -> String {
        let location = locationString(for: report)
        let quotedSelection = quoteForMarkdown(report.selectedText)
        let trimmedNote = report.userNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteBlock = trimmedNote.isEmpty ? "(no note)" : trimmedNote

        let isoTimestamp = ISO8601DateFormatter().string(from: report.timestamp)

        return """
        **Location:** \(location)
        **Selected text:**
        \(quotedSelection)

        **What's wrong:**
        \(noteBlock)

        ---
        <sub>Zephyr \(report.appVersion) · \(report.osVersion) · \(isoTimestamp)</sub>
        """
    }

    static func fallbackURL(for report: IssueReport) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "github.com"
        components.path = "/\(repoOwner)/\(repoName)/issues/new"
        components.queryItems = [
            URLQueryItem(name: "title", value: title(for: report)),
            URLQueryItem(name: "body", value: body(for: report)),
            URLQueryItem(name: "labels", value: label)
        ]
        return components.url!
    }

    /// Renders `text` as a markdown block quote. Each line gets a `> ` prefix.
    /// A literal `>` at the start of a user line is escaped to `\>` so it doesn't
    /// produce a nested blockquote that collides with our formatting.
    private static func quoteForMarkdown(_ text: String) -> String {
        text
            .components(separatedBy: "\n")
            .map { line -> String in
                let escaped = line.hasPrefix(">") ? "\\" + line : line
                return "> \(escaped)"
            }
            .joined(separator: "\n")
    }
}
```

- [ ] **Step 4: Add files to Xcode project**

Add `IssueBodyFormatter.swift` to the `ESVBible` target and `IssueBodyFormatterTests.swift` to the `ESVBibleTests` target in `Zephyr.xcodeproj/project.pbxproj`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme ESVBible -only-testing:ESVBibleTests/IssueBodyFormatterTests 2>&1 | tail -30`

Expected: PASS (all 12 tests).

- [ ] **Step 6: Commit**

```bash
git add ESVBible/Services/IssueBodyFormatter.swift ESVBibleTests/IssueBodyFormatterTests.swift Zephyr.xcodeproj/project.pbxproj
git commit -m "feat: add IssueReport and IssueBodyFormatter"
```

---

## Task 4: `IssueReporterService`

**Files:**
- Create: `ESVBible/Services/IssueReporterService.swift`
- Test: `ESVBibleTests/IssueReporterServiceTests.swift`

**Context:** Observable service that holds configuration state and makes the actual GitHub API call. Pattern-matches `UpdateService`: `@Observable` class, takes an injectable `URLSession`. Reads the token on demand from `KeychainTokenStore` (not cached). Tests use a stub `URLProtocol` to intercept network requests — no real HTTP. The service also exposes `isConfigured`, `createIssue(_:)`, `testConnection()`, and delegates `fallbackURL(for:)` to `IssueBodyFormatter` for convenience.

- [ ] **Step 1: Write the failing tests**

Create `ESVBibleTests/IssueReporterServiceTests.swift`:

```swift
import XCTest
@testable import ESVBible

// Stub URLProtocol that lets tests control the response for any URLRequest.
// Must be registered in URLSessionConfiguration.protocolClasses.
final class StubURLProtocol: URLProtocol {
    static var responder: ((URLRequest) -> (HTTPURLResponse, Data?, Error?))?
    static var lastRequest: URLRequest?
    static var lastBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lastRequest = request
        // URLRequest.httpBody is nil for streamed bodies; capture via bodyStream if needed
        Self.lastBody = request.httpBody ?? Self.readBody(from: request)

        guard let responder = Self.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data, error) = responder(request)
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if let data = data {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(from request: URLRequest) -> Data? {
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read > 0 { data.append(buffer, count: read) } else { break }
        }
        return data
    }
}

final class IssueReporterServiceTests: XCTestCase {
    var tokenStore: KeychainTokenStore!
    var service: IssueReporterService!
    var session: URLSession!

    override func setUp() {
        super.setUp()
        tokenStore = KeychainTokenStore(service: "com.jonyen.zephyr.test.\(UUID().uuidString)")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        session = URLSession(configuration: config)

        service = IssueReporterService(tokenStore: tokenStore, session: session)

        StubURLProtocol.responder = nil
        StubURLProtocol.lastRequest = nil
        StubURLProtocol.lastBody = nil
    }

    override func tearDown() {
        try? tokenStore.delete()
        StubURLProtocol.responder = nil
        super.tearDown()
    }

    private func sampleReport() -> IssueReport {
        IssueReport(
            book: "John", chapter: 3, verseStart: 16, verseEnd: 16,
            selectedText: "For God so loved the world",
            userNote: "typo here",
            appVersion: "0.9.6", osVersion: "macOS 15.2",
            timestamp: Date(timeIntervalSince1970: 1_776_000_000)
        )
    }

    func testIsConfiguredReflectsToken() throws {
        XCTAssertFalse(service.isConfigured)
        try tokenStore.write("ghp_abc")
        XCTAssertTrue(service.isConfigured)
        try tokenStore.delete()
        XCTAssertFalse(service.isConfigured)
    }

    func testCreateIssueNotConfigured() async {
        let result = await service.createIssue(report: sampleReport())
        if case .failure(.notConfigured) = result { return }
        XCTFail("Expected .notConfigured, got \(result)")
    }

    func testCreateIssueSuccessParsesIssueNumber() async throws {
        try tokenStore.write("ghp_abc")
        StubURLProtocol.responder = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 201,
                httpVersion: nil, headerFields: nil
            )!
            let data = #"{"number": 42}"#.data(using: .utf8)!
            return (response, data, nil)
        }

        let result = await service.createIssue(report: sampleReport())
        guard case .success(let number) = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        XCTAssertEqual(number, 42)
    }

    func testCreateIssueSendsExpectedRequest() async throws {
        try tokenStore.write("ghp_abc")
        StubURLProtocol.responder = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, #"{"number": 1}"#.data(using: .utf8)!, nil)
        }

        _ = await service.createIssue(report: sampleReport())

        let req = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(req.url?.absoluteString, "https://api.github.com/repos/jonyen/zephyr/issues")
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer ghp_abc")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
        XCTAssertEqual(req.value(forHTTPHeaderField: "X-GitHub-Api-Version"), "2022-11-28")

        let body = try XCTUnwrap(StubURLProtocol.lastBody)
        let json = try JSONSerialization.jsonObject(with: body) as! [String: Any]
        XCTAssertEqual(json["title"] as? String, "[text] John 3:16 — typo here")
        XCTAssertNotNil(json["body"] as? String)
        XCTAssertEqual(json["labels"] as? [String], ["text-report"])
    }

    func testCreateIssue401ReturnsUnauthorized() async throws {
        try tokenStore.write("bad_token")
        StubURLProtocol.responder = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, nil, nil)
        }
        let result = await service.createIssue(report: sampleReport())
        if case .failure(.unauthorized) = result { return }
        XCTFail("Expected .unauthorized, got \(result)")
    }

    func testCreateIssue403ReturnsRateLimited() async throws {
        try tokenStore.write("ghp_abc")
        StubURLProtocol.responder = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, nil, nil)
        }
        let result = await service.createIssue(report: sampleReport())
        if case .failure(.rateLimited) = result { return }
        XCTFail("Expected .rateLimited, got \(result)")
    }

    func testCreateIssueOtherHTTPError() async throws {
        try tokenStore.write("ghp_abc")
        StubURLProtocol.responder = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, nil, nil)
        }
        let result = await service.createIssue(report: sampleReport())
        if case .failure(.httpStatus(500)) = result { return }
        XCTFail("Expected .httpStatus(500), got \(result)")
    }

    func testCreateIssueNetworkFailure() async throws {
        try tokenStore.write("ghp_abc")
        StubURLProtocol.responder = { _ in
            let response = HTTPURLResponse(url: URL(string: "https://api.github.com/")!, statusCode: 0, httpVersion: nil, headerFields: nil)!
            return (response, nil, URLError(.notConnectedToInternet))
        }
        let result = await service.createIssue(report: sampleReport())
        if case .failure(.network) = result { return }
        XCTFail("Expected .network, got \(result)")
    }

    func testTestConnectionUsesGETAndDoesNotCreateIssue() async throws {
        try tokenStore.write("ghp_abc")
        StubURLProtocol.responder = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, #"{"id": 1}"#.data(using: .utf8)!, nil)
        }

        let result = await service.testConnection()
        guard case .success = result else {
            XCTFail("Expected success, got \(result)")
            return
        }
        let req = try XCTUnwrap(StubURLProtocol.lastRequest)
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.url?.absoluteString, "https://api.github.com/repos/jonyen/zephyr")
        XCTAssertFalse(req.url?.path.contains("/issues") ?? true)
    }

    func testTestConnectionNotConfigured() async {
        let result = await service.testConnection()
        if case .failure(.notConfigured) = result { return }
        XCTFail("Expected .notConfigured, got \(result)")
    }

    func testFallbackURLDelegatesToFormatter() {
        let url = service.fallbackURL(for: sampleReport())
        XCTAssertTrue(url.absoluteString.hasPrefix("https://github.com/jonyen/zephyr/issues/new?"))
        XCTAssertTrue(url.absoluteString.contains("labels=text-report"))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme ESVBible -only-testing:ESVBibleTests/IssueReporterServiceTests 2>&1 | tail -30`

Expected: FAIL — `IssueReporterService` does not exist.

- [ ] **Step 3: Implement `IssueReporterService`**

Create `ESVBible/Services/IssueReporterService.swift`:

```swift
import Foundation

enum IssueReporterError: Error, Equatable {
    case notConfigured
    case network(String)
    case unauthorized
    case rateLimited
    case httpStatus(Int)
    case decoding
}

@Observable
class IssueReporterService {
    private let tokenStore: KeychainTokenStore
    private let session: URLSession

    init(tokenStore: KeychainTokenStore = KeychainTokenStore(), session: URLSession = .shared) {
        self.tokenStore = tokenStore
        self.session = session
    }

    var isConfigured: Bool {
        guard let token = tokenStore.read() else { return false }
        return !token.isEmpty
    }

    func fallbackURL(for report: IssueReport) -> URL {
        IssueBodyFormatter.fallbackURL(for: report)
    }

    func createIssue(report: IssueReport) async -> Result<Int, IssueReporterError> {
        guard let token = tokenStore.read(), !token.isEmpty else {
            return .failure(.notConfigured)
        }

        let url = URL(string: "https://api.github.com/repos/\(IssueBodyFormatter.repoOwner)/\(IssueBodyFormatter.repoName)/issues")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "title": IssueBodyFormatter.title(for: report),
            "body": IssueBodyFormatter.body(for: report),
            "labels": [IssueBodyFormatter.label]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.network("invalid response"))
            }
            switch http.statusCode {
            case 200..<300:
                guard let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let number = parsed["number"] as? Int else {
                    return .failure(.decoding)
                }
                return .success(number)
            case 401:
                return .failure(.unauthorized)
            case 403:
                return .failure(.rateLimited)
            default:
                return .failure(.httpStatus(http.statusCode))
            }
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func testConnection() async -> Result<Void, IssueReporterError> {
        guard let token = tokenStore.read(), !token.isEmpty else {
            return .failure(.notConfigured)
        }

        let url = URL(string: "https://api.github.com/repos/\(IssueBodyFormatter.repoOwner)/\(IssueBodyFormatter.repoName)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .failure(.network("invalid response"))
            }
            switch http.statusCode {
            case 200..<300: return .success(())
            case 401: return .failure(.unauthorized)
            case 403: return .failure(.rateLimited)
            default: return .failure(.httpStatus(http.statusCode))
            }
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}
```

- [ ] **Step 4: Add files to Xcode project**

Add `IssueReporterService.swift` to the `ESVBible` target and `IssueReporterServiceTests.swift` to the `ESVBibleTests` target.

- [ ] **Step 5: Run tests to verify they pass**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme ESVBible -only-testing:ESVBibleTests/IssueReporterServiceTests 2>&1 | tail -40`

Expected: PASS — all 12 tests. If `testCreateIssueSendsExpectedRequest` fails because `httpBody` is nil (some URLSession configurations pipe the body through `httpBodyStream`), the `StubURLProtocol.readBody(from:)` helper handles that path.

- [ ] **Step 6: Commit**

```bash
git add ESVBible/Services/IssueReporterService.swift ESVBibleTests/IssueReporterServiceTests.swift Zephyr.xcodeproj/project.pbxproj
git commit -m "feat: add IssueReporterService with GitHub API integration"
```

---

## Task 5: `FlagIssueSheet` SwiftUI view

**Files:**
- Create: `ESVBible/Views/FlagIssueSheet.swift`

**Context:** One-field composer presented as a sheet. Owns its own `@State` for the note text and the submit-in-flight flag. Calls the injected `onSubmit` closure with the final note; the parent view decides what to do with the result (API call, fallback URL, toast). This keeps the sheet itself free of networking code and easy to reason about.

No unit test for this view — SwiftUI views of this size are covered by manual verification (see Task 9). The logic it contains is 100% already tested in `IssueBodyFormatterTests` and `IssueReporterServiceTests`.

- [ ] **Step 1: Create the view**

Create `ESVBible/Views/FlagIssueSheet.swift`:

```swift
import SwiftUI

struct FlagIssueSheet: View {
    let location: String          // e.g., "John 3:16"
    let selectedText: String
    let onSubmit: (String) -> Void  // called with the trimmed user note
    let onCancel: () -> Void

    @State private var note: String = ""
    @State private var isSubmitting: Bool = false
    @FocusState private var noteFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flag a text issue")
                .font(.headline)

            Text(location)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView {
                Text(selectedText)
                    .font(.body)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 100)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)

            Text("What's wrong?")
                .font(.subheadline)

            TextField("Optional note", text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .focused($noteFocused)
                .disabled(isSubmitting)
                .onSubmit { submit() }

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isSubmitting)
                Button(isSubmitting ? "Submitting…" : "Submit") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(isSubmitting)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear { noteFocused = true }
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        onSubmit(note.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
```

- [ ] **Step 2: Add file to Xcode project**

Add `FlagIssueSheet.swift` to the `ESVBible` target.

- [ ] **Step 3: Verify the project still builds**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme ESVBible 2>&1 | tail -20`

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add ESVBible/Views/FlagIssueSheet.swift Zephyr.xcodeproj/project.pbxproj
git commit -m "feat: add FlagIssueSheet composer view"
```

---

## Task 6: Wire `Flag Text Issue…` menu item into `SelectableTextView`

**Files:**
- Modify: `ESVBible/Views/SelectableTextView.swift` (outer struct, `Coordinator`, `HighlightableTextView.menu(for:)`, plus a new `flagIssue(_:)` @objc method)

**Context:** We add one new menu item, one new callback path, and one aggregator for the selected range. This is the most delicate change — read the relevant sections of the existing file carefully before editing. Everything else in the file stays the same.

We introduce a lightweight struct `FlagSelection` carrying what the sheet needs: the verse range, the location string fragments, and the selected text. The menu handler computes this from `verseBoundaries` + `textView.string`.

- [ ] **Step 1: Add `FlagSelection` struct**

Near the top of `ESVBible/Views/SelectableTextView.swift` (just below the `import` lines), add:

```swift
struct FlagSelection {
    let bookName: String
    let chapterNumber: Int
    let verseStart: Int
    let verseEnd: Int
    let selectedText: String
}
```

- [ ] **Step 2: Add `onFlagIssue` parameter to `SelectableTextView` struct**

Locate the parameter list in `ESVBible/Views/SelectableTextView.swift` (starts at line 4). Add a new parameter to the struct (after `onRemoveHighlights`):

```swift
let onFlagIssue: (FlagSelection) -> Void
```

- [ ] **Step 3: Wire it in `makeNSView` and `updateNSView`**

In `makeNSView` (line 23), add this line near the other `context.coordinator.onXxx = ...` assignments (after `onRemoveHighlights`):

```swift
context.coordinator.onFlagIssue = onFlagIssue
```

In `updateNSView` (line 63), add the same line in the matching block.

- [ ] **Step 4: Add `onFlagIssue` to the `Coordinator` class**

In the `Coordinator` class (line 245), add a new property near the other `onXxx` properties:

```swift
var onFlagIssue: ((FlagSelection) -> Void)?
```

- [ ] **Step 5: Filter `.flag` out of the existing color menu loop**

In `HighlightableTextView.menu(for:)` (line 293), locate the loop:

```swift
for color in HighlightColor.allCases {
```

Replace with:

```swift
for color in HighlightColor.allCases where color != .flag {
```

This ensures `.flag` does not appear as a regular "Highlight Flag" menu item.

- [ ] **Step 6: Add the `Flag Text Issue…` menu item**

In `HighlightableTextView.menu(for:)`, after the `Add Note` item block and before the final `return menu`, add:

```swift
menu.addItem(NSMenuItem.separator())

let flagItem = NSMenuItem(title: "Flag Text Issue…", action: #selector(flagIssue(_:)), keyEquivalent: "")
flagItem.target = self
menu.addItem(flagItem)
```

- [ ] **Step 7: Implement the `flagIssue(_:)` @objc method**

Still in `HighlightableTextView`, after the `removeHighlight(_:)` method, add:

```swift
@objc private func flagIssue(_ sender: NSMenuItem) {
    guard let coordinator = (delegate as? SelectableTextView.Coordinator) else { return }
    let range = selectedRange()
    guard range.length > 0 else { return }

    // Collect per-verse substrings and also write a .flag highlight through the existing path.
    var verseStart = Int.max
    var verseEnd = Int.min
    var fragments: [String] = []

    let fullString = self.string as NSString

    for boundary in coordinator.verseBoundaries {
        let overlapStart = max(range.location, boundary.start)
        let overlapEnd = min(range.location + range.length, boundary.end)
        guard overlapStart < overlapEnd else { continue }

        let charStart = overlapStart - boundary.start
        let charEnd = overlapEnd - boundary.start

        // Write the persistent highlight through the existing callback path
        coordinator.onHighlight?(boundary.verse, charStart, charEnd, .flag)

        // Aggregate the selected text for the issue report
        let fragment = fullString.substring(with: NSRange(location: overlapStart, length: overlapEnd - overlapStart))
        fragments.append(fragment)

        verseStart = min(verseStart, boundary.verse)
        verseEnd = max(verseEnd, boundary.verse)
    }

    guard verseStart <= verseEnd else { return }

    // We don't have bookName/chapterNumber in the text view directly — they come from the
    // enclosing SwiftUI view. Pass sentinel values and let the enclosing view fill them in.
    // The coordinator's onFlagIssue callback receives a FlagSelection with the text view's view
    // of the world; the SwiftUI parent layer enriches it with book/chapter.
    let selectedText = fragments.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    let selection = FlagSelection(
        bookName: "",    // filled in by the SwiftUI wrapper via the closure
        chapterNumber: 0,
        verseStart: verseStart,
        verseEnd: verseEnd,
        selectedText: selectedText
    )
    coordinator.onFlagIssue?(selection)
}
```

- [ ] **Step 8: Have the SwiftUI wrapper inject book/chapter into the callback**

In `SelectableTextView.makeNSView` and `updateNSView` (where we assigned `context.coordinator.onFlagIssue = onFlagIssue`), replace that assignment with a closure that enriches the `FlagSelection` with `bookName` and `chapterNumber` from the outer struct:

```swift
let capturedBook = bookName
let capturedChapter = chapterNumber
let capturedCallback = onFlagIssue
context.coordinator.onFlagIssue = { incoming in
    let enriched = FlagSelection(
        bookName: capturedBook,
        chapterNumber: capturedChapter,
        verseStart: incoming.verseStart,
        verseEnd: incoming.verseEnd,
        selectedText: incoming.selectedText
    )
    capturedCallback(enriched)
}
```

Do this in both `makeNSView` AND `updateNSView` so the callback is re-bound whenever SwiftUI re-evaluates (book/chapter could change between updates).

- [ ] **Step 9: Update any existing call sites of `SelectableTextView` to pass a stub `onFlagIssue`**

There's exactly one call site: inside `ChapterView` in `ESVBible/ReadingPaneView.swift` around line 227–267. Add this parameter at the end of the existing parameter list (right after `theme: readingTheme`) — use a temporary empty closure for now; Task 7 wires it up properly:

```swift
theme: readingTheme,
onFlagIssue: { _ in }
```

- [ ] **Step 10: Verify the project builds**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme ESVBible 2>&1 | tail -30`

Expected: BUILD SUCCEEDED.

- [ ] **Step 11: Commit**

```bash
git add ESVBible/Views/SelectableTextView.swift ESVBible/ReadingPaneView.swift
git commit -m "feat: add Flag Text Issue menu item and callback plumbing"
```

---

## Task 7: Present `FlagIssueSheet` from `ChapterView` and handle submission

**Files:**
- Modify: `ESVBible/ReadingPaneView.swift` (`ChapterView` specifically, around lines 227–310 — adjust based on actual line numbers)

**Context:** `ChapterView` (a private view inside `ReadingPaneView.swift`) already owns `@State` for the note popover. It's the natural owner of the flag sheet state too. On submit, it asks `IssueReporterService` to file the issue; on failure or missing config, it opens the fallback URL in the browser. Toast messaging uses the existing alert/status pattern — if there's no existing toast mechanism, use a simple `.alert(isPresented:)` for now and iterate later.

The `IssueReporterService` instance needs to be available to `ChapterView`. Since it's stateless except for the injected dependencies, we can instantiate it lazily as a `@State` property (or construct it inline when needed). We'll use a `@State` property to satisfy `@Observable` observation.

- [ ] **Step 1: Add state and service to `ChapterView`**

Near the top of `ChapterView` in `ESVBible/ReadingPaneView.swift` (alongside the other `@State` declarations like `showNotePopover`, `editingNote`, etc.), add:

```swift
@State private var flagSelection: FlagSelection?
@State private var flagResultAlert: String?
@State private var issueReporter = IssueReporterService()
```

Also add a computed property at the bottom of the struct (before `body`) for app / OS version strings:

```swift
private var currentAppVersion: String {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
}

private var currentOSVersion: String {
    let v = ProcessInfo.processInfo.operatingSystemVersion
    return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
}
```

- [ ] **Step 2: Replace the stub `onFlagIssue` closure**

Where Task 6 left `onFlagIssue: { _ in }`, replace with:

```swift
onFlagIssue: { selection in
    flagSelection = selection
}
```

- [ ] **Step 3: Present the sheet and handle submission**

Add a `.sheet` modifier alongside the existing `.popover(isPresented: $showNotePopover)` modifier. The existing popover is attached to the `SelectableTextView`'s overlay/frame stack. Add the sheet after it:

```swift
.sheet(item: $flagSelection) { selection in
    FlagIssueSheet(
        location: locationString(for: selection),
        selectedText: selection.selectedText,
        onSubmit: { note in
            handleFlagSubmit(selection: selection, note: note)
        },
        onCancel: {
            flagSelection = nil
        }
    )
}
.alert("Flag text issue", isPresented: .constant(flagResultAlert != nil), actions: {
    Button("OK") { flagResultAlert = nil }
}, message: {
    Text(flagResultAlert ?? "")
})
```

For `.sheet(item:)` to work, `FlagSelection` needs to be `Identifiable`. Add the conformance in `SelectableTextView.swift` where `FlagSelection` is defined:

```swift
struct FlagSelection: Identifiable {
    let id = UUID()
    let bookName: String
    let chapterNumber: Int
    let verseStart: Int
    let verseEnd: Int
    let selectedText: String
}
```

- [ ] **Step 4: Implement `handleFlagSubmit` and `locationString` helpers**

Add these methods to `ChapterView`:

```swift
private func locationString(for selection: FlagSelection) -> String {
    if selection.verseStart == selection.verseEnd {
        return "\(selection.bookName) \(selection.chapterNumber):\(selection.verseStart)"
    }
    return "\(selection.bookName) \(selection.chapterNumber):\(selection.verseStart)-\(selection.verseEnd)"
}

private func handleFlagSubmit(selection: FlagSelection, note: String) {
    let report = IssueReport(
        book: selection.bookName,
        chapter: selection.chapterNumber,
        verseStart: selection.verseStart,
        verseEnd: selection.verseEnd,
        selectedText: selection.selectedText,
        userNote: note,
        appVersion: currentAppVersion,
        osVersion: currentOSVersion,
        timestamp: Date()
    )

    // Dismiss sheet immediately so the user isn't blocked on the network call
    flagSelection = nil

    Task {
        if issueReporter.isConfigured {
            let result = await issueReporter.createIssue(report: report)
            switch result {
            case .success(let number):
                await MainActor.run { flagResultAlert = "Filed issue #\(number)." }
            case .failure(let error):
                let message = fallbackMessage(for: error)
                await MainActor.run {
                    flagResultAlert = message
                    NSWorkspace.shared.open(issueReporter.fallbackURL(for: report))
                }
            }
        } else {
            await MainActor.run {
                NSWorkspace.shared.open(issueReporter.fallbackURL(for: report))
            }
        }
    }
}

private func fallbackMessage(for error: IssueReporterError) -> String {
    switch error {
    case .notConfigured:
        return "No token configured — opened in browser instead."
    case .network:
        return "Couldn't reach GitHub — opened in browser instead."
    case .unauthorized:
        return "Token rejected — check Settings → GitHub. Opened in browser instead."
    case .rateLimited:
        return "GitHub rate limited — opened in browser instead."
    case .httpStatus(let status):
        return "GitHub error (\(status)) — opened in browser instead."
    case .decoding:
        return "Couldn't parse GitHub response — opened in browser instead."
    }
}
```

- [ ] **Step 5: Add `import AppKit` if not already present**

Check the top of `ESVBible/ReadingPaneView.swift`. If only `SwiftUI` is imported, add `import AppKit` for `NSWorkspace`.

- [ ] **Step 6: Verify the project builds**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme ESVBible 2>&1 | tail -30`

Expected: BUILD SUCCEEDED. If compilation fails because `FlagSelection` isn't visible in `ReadingPaneView.swift`, confirm it's defined at file scope in `SelectableTextView.swift` (not nested inside the struct).

- [ ] **Step 7: Commit**

```bash
git add ESVBible/Views/SelectableTextView.swift ESVBible/ReadingPaneView.swift
git commit -m "feat: present FlagIssueSheet and dispatch to IssueReporterService"
```

---

## Task 8: GitHub settings pane

**Files:**
- Create: `ESVBible/Views/GitHubSettingsView.swift`
- Modify: `ESVBible/ESVBibleApp.swift` (add the new tab)

**Context:** A simple SwiftUI form with a `SecureField` for the token, Save/Clear buttons, and a "Test connection" button that hits `IssueReporterService.testConnection()`. The view owns its own reporter instance and a transient state string for the token input (never binds the SecureField directly to Keychain — we read Keychain on appear and write on Save).

- [ ] **Step 1: Create `GitHubSettingsView`**

Create `ESVBible/Views/GitHubSettingsView.swift`:

```swift
import SwiftUI

struct GitHubSettingsView: View {
    @State private var tokenInput: String = ""
    @State private var statusMessage: String = ""
    @State private var isTesting: Bool = false
    @State private var isSaved: Bool = false

    private let tokenStore = KeychainTokenStore()
    private let reporter = IssueReporterService()

    var body: some View {
        Form {
            Section {
                SecureField("Personal access token", text: $tokenInput)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save") { save() }
                        .disabled(tokenInput.isEmpty)
                    Button("Clear") { clear() }
                        .disabled(!isSaved)
                    Button(isTesting ? "Testing…" : "Test connection") { test() }
                        .disabled(isTesting || tokenInput.isEmpty && !isSaved)
                }

                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("GitHub")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Used by the **Flag Text Issue…** selection menu to file rendering bugs against `jonyen/zephyr`.")
                    Text("Create a fine-grained personal access token scoped to `jonyen/zephyr` with **Issues: Read and write** permission.")
                    Link("Create token →", destination: URL(string: "https://github.com/settings/personal-access-tokens/new")!)
                        .font(.caption)
                }
                .font(.caption)
            }
        }
        .padding(20)
        .frame(width: 480)
        .tabItem { Label("GitHub", systemImage: "exclamationmark.bubble") }
        .onAppear { loadExisting() }
    }

    private func loadExisting() {
        if let existing = tokenStore.read(), !existing.isEmpty {
            tokenInput = existing
            isSaved = true
        }
    }

    private func save() {
        do {
            try tokenStore.write(tokenInput)
            isSaved = true
            statusMessage = "Saved."
        } catch {
            statusMessage = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private func clear() {
        do {
            try tokenStore.delete()
            tokenInput = ""
            isSaved = false
            statusMessage = "Cleared."
        } catch {
            statusMessage = "Couldn't clear: \(error.localizedDescription)"
        }
    }

    private func test() {
        isTesting = true
        statusMessage = ""
        // Save the current input first if it differs from what's stored, so testConnection uses it
        if !tokenInput.isEmpty && !isSaved {
            try? tokenStore.write(tokenInput)
            isSaved = true
        }
        Task {
            let result = await reporter.testConnection()
            await MainActor.run {
                isTesting = false
                switch result {
                case .success:
                    statusMessage = "✓ Connected."
                case .failure(.notConfigured):
                    statusMessage = "No token saved."
                case .failure(.unauthorized):
                    statusMessage = "Token rejected (401)."
                case .failure(.rateLimited):
                    statusMessage = "Rate limited (403)."
                case .failure(.httpStatus(let s)):
                    statusMessage = "HTTP \(s)."
                case .failure(.network(let msg)):
                    statusMessage = "Network error: \(msg)"
                case .failure(.decoding):
                    statusMessage = "Unexpected response."
                }
            }
        }
    }
}
```

- [ ] **Step 2: Add the tab to `Settings`**

In `ESVBible/ESVBibleApp.swift` around line 189–196, modify the `Settings { TabView { … } }` block to add the new tab:

```swift
Settings {
    TabView {
        AppearanceSettingsView()
            .tabItem { Label("Appearance", systemImage: "paintbrush") }
        KeybindingsSettingsView()
            .tabItem { Label("Shortcuts", systemImage: "keyboard") }
        GitHubSettingsView()
            .tabItem { Label("GitHub", systemImage: "exclamationmark.bubble") }
    }
}
```

Note: `GitHubSettingsView` already declares its own `.tabItem { … }` inside the view body for convenience, but `TabView` uses the modifier applied to the child. Both declarations are harmless — the outer one wins. If Xcode complains about duplicates, remove the one inside `GitHubSettingsView`.

- [ ] **Step 3: Add file to Xcode project**

Add `GitHubSettingsView.swift` to the `ESVBible` target.

- [ ] **Step 4: Verify the project builds**

Run: `xcodebuild build -project Zephyr.xcodeproj -scheme ESVBible 2>&1 | tail -30`

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add ESVBible/Views/GitHubSettingsView.swift ESVBible/ESVBibleApp.swift Zephyr.xcodeproj/project.pbxproj
git commit -m "feat: add GitHub settings pane for PAT configuration"
```

---

## Task 9: Manual verification & final test pass

**Context:** SwiftUI views aren't in the automated test suite. These steps must be performed by a human (or an agent with a graphical debug session). Mark each checkbox only after confirming the behavior actually works in a running build.

- [ ] **Step 1: Run the full automated test suite**

Run: `xcodebuild test -project Zephyr.xcodeproj -scheme ESVBible 2>&1 | tail -30`

Expected: all tests pass, including the new `HighlightColorTests`, `KeychainTokenStoreTests`, `IssueBodyFormatterTests`, and `IssueReporterServiceTests`.

- [ ] **Step 2: Build and launch the app**

Run: `xcodebuild -project Zephyr.xcodeproj -scheme ESVBible -configuration Debug build 2>&1 | tail -10 && open build/Debug/Zephyr.app` (adjust path if the project's derived data is elsewhere; see `README.md`).

- [ ] **Step 3: Manually verify the flag UX (without a token configured)**

  1. Navigate to any chapter, e.g. John 3.
  2. Select a range of text spanning one or more verses.
  3. Right-click → confirm the menu now shows `Flag Text Issue…` between `Add Note` and `Copy`.
  4. Confirm the existing `Highlight Flag` item does NOT appear (should only see the original four colors).
  5. Click `Flag Text Issue…`. Confirm:
     - The selection gets highlighted with the reddish-orange flag color.
     - `FlagIssueSheet` opens with the correct location (e.g. `John 3:16`), selected text preview, and focused text field.
  6. Type a note, click Submit. Confirm the default browser opens to a prefilled GitHub new-issue URL on `jonyen/zephyr` with `labels=text-report`.
  7. Dismiss, re-select, click `Flag Text Issue…`, then Cancel. Confirm the highlight persists (it was added before the sheet opened) but the browser does NOT open.

- [ ] **Step 4: Manually verify the flag UX (with a token configured)**

  1. Open Settings → GitHub.
  2. Paste a valid fine-grained PAT. Click Save. Click Test connection. Confirm "✓ Connected."
  3. Return to the reader, select text, click `Flag Text Issue…`, add a note, click Submit.
  4. Confirm the sheet closes and an alert shows "Filed issue #N."
  5. Visit `https://github.com/jonyen/zephyr/issues/N` in a browser and confirm:
     - Title matches `[text] John 3:16 — <note>`.
     - Body contains location, quoted selection, note, and metadata footer.
     - The `text-report` label is applied.

- [ ] **Step 5: Manually verify failure paths**

  1. In Settings → GitHub, replace the token with garbage (e.g. `ghp_invalid`). Click Save. Don't bother testing — let the real flag flow surface the error.
  2. Flag a verse. Confirm the alert says "Token rejected — check Settings → GitHub. Opened in browser instead." and the browser opens to the fallback URL.
  3. Clear the token via the Clear button. Confirm that subsequent flags open the fallback URL without an error alert (the "not configured" path just opens silently).
  4. Turn off network (or physically disconnect). Re-save a valid token. Flag a verse. Confirm the alert says "Couldn't reach GitHub — opened in browser instead." and the browser opens to the fallback URL.

- [ ] **Step 6: Verify highlight persistence**

  1. Flag a verse (creates a reddish-orange highlight).
  2. Quit and relaunch the app.
  3. Navigate back to that chapter. Confirm the flag highlight is still visible.
  4. Right-click the flagged text → `Remove Highlight`. Confirm the highlight is cleared (same behavior as any other color highlight).

- [ ] **Step 7: Commit the verified state**

```bash
git status
# (should be clean if no lingering changes)
git log --oneline -10
# (review the series of commits)
```

If any manual step uncovered a bug, fix it in a new commit before finalizing.

---

## Self-Review

Spec coverage walk-through:

| Spec requirement | Task |
|---|---|
| `.flag` case in `HighlightColor` with distinct hue | Task 1 |
| `IssueReporterService` patterned on `UpdateService` | Task 4 |
| `KeychainTokenStore` with fixed service name | Task 2 |
| `FlagIssueSheet` with single field, ⌘↵/Esc | Task 5 |
| Menu item `Flag Text Issue…` in HighlightableTextView | Task 6 |
| `.flag` filtered out of the `Highlight <Color>` loop | Task 6 |
| Sheet presentation owned by ChapterView | Task 7 |
| Toast on success/failure | Task 7 (via alert for now) |
| Fallback URL opens in browser on failure or no config | Task 7 |
| Settings → GitHub tab with save/test/clear | Task 8 |
| Issue title format `[text] Ref — note (50 cap)` | Task 3 |
| Issue body with location, quoted text, note, metadata footer | Task 3 |
| `text-report` label applied on API + fallback URL | Tasks 3, 4 |
| Headers: `Authorization: Bearer`, `Accept: vnd.github+json`, `X-GitHub-Api-Version` | Task 4 |
| Error mapping: 401 → unauthorized, 403 → rateLimited, other → httpStatus | Task 4 |
| Flag highlight never rolled back on failure | Task 6 (highlight written before sheet opens) |
| No silent drops — always fall back to browser | Task 7 |
| No retries inside the app | Task 7 (single try, then fallback) |
| Test connection uses GET, never creates an issue | Task 4 |
| KeychainTokenStore tests use isolated service name | Task 2 |
| IssueReporterService tests use URLProtocol stub | Task 4 |
| HighlightManager `.flag` round-trips through JSON | Task 1 (tested via HighlightColor encode/decode) |
| Manual verification of popover/sheet/keybindings | Task 9 |

No gaps found.

Placeholder scan: none — every code step has full code, every test step has full test, every command has the exact invocation and expected output.

Type consistency: `IssueReport`, `IssueReporterError`, `FlagSelection`, `IssueBodyFormatter`, and `KeychainTokenStore` all use consistent names and signatures across tasks. `IssueReporterService.createIssue(report:)` matches the call in Task 7. `FlagSelection.id` added in Task 7 for `.sheet(item:)` does not conflict with its use in Task 6.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-04-12-flag-text-issue.md`. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
