import XCTest
@testable import ESVBible

final class UpdateServiceTests: XCTestCase {

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
