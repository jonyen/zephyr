import XCTest
import CryptoKit
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

    func testParseUpdateManifest() throws {
        let json = """
        {
            "version": "1.1.0",
            "notes": "Bug fixes and improvements",
            "zipURL": "https://jonyen.com/zephyr-updates/Zephyr-1.1.0.app.zip",
            "signature": "c2lnbmF0dXJl"
        }
        """.data(using: .utf8)!

        let manifest = try JSONDecoder().decode(UpdateService.UpdateManifest.self, from: json)
        XCTAssertEqual(manifest.version, "1.1.0")
        XCTAssertEqual(manifest.notes, "Bug fixes and improvements")
        XCTAssertEqual(manifest.zipURL, "https://jonyen.com/zephyr-updates/Zephyr-1.1.0.app.zip")
        XCTAssertEqual(manifest.signature, "c2lnbmF0dXJl")
    }

    /// A manifest missing the signature must fail to decode rather than yield an unsigned
    /// update — the download path refuses to install without one.
    func testManifestWithoutSignatureFailsToDecode() {
        let json = """
        {"version": "1.1.0", "notes": "x", "zipURL": "https://example.com/a.zip"}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(UpdateService.UpdateManifest.self, from: json))
    }

    // MARK: - Signature verification

    private static let testPublicKey = "OZVuZglmktdVMpL0cqRrBjBdyO0AWvsaK/QGXkrYP2A="

    private func writeTemp(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("update-test-\(UUID().uuidString).bin")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testVerifyRejectsGarbageSignature() throws {
        let url = try writeTemp("payload")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertFalse(UpdateService.verify(fileAt: url,
                                            signature: "bm90LWEtc2lnbmF0dXJl",
                                            publicKeys: [Self.testPublicKey]))
    }

    func testVerifyRejectsNonBase64Signature() throws {
        let url = try writeTemp("payload")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertFalse(UpdateService.verify(fileAt: url,
                                            signature: "!!! not base64 !!!",
                                            publicKeys: [Self.testPublicKey]))
    }

    func testVerifyRejectsMalformedPublicKey() throws {
        let url = try writeTemp("payload")
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertFalse(UpdateService.verify(fileAt: url,
                                            signature: "bm90LWEtc2lnbmF0dXJl",
                                            publicKeys: ["dG9vLXNob3J0"]))
    }

    func testVerifyRejectsMissingFile() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("definitely-not-here-\(UUID().uuidString).bin")
        XCTAssertFalse(UpdateService.verify(fileAt: missing,
                                            signature: "bm90LWEtc2lnbmF0dXJl",
                                            publicKeys: [Self.testPublicKey]))
    }

    /// Round-trips a real signature so the app's verifier is proven against the same
    /// CryptoKit primitives Scripts/sign-update.swift uses to produce one.
    func testVerifyAcceptsGenuineSignatureAndRejectsTamperedPayload() throws {
        let key = Curve25519.Signing.PrivateKey()
        let publicKey = key.publicKey.rawRepresentation.base64EncodedString()

        let url = try writeTemp("the real payload")
        defer { try? FileManager.default.removeItem(at: url) }
        let signature = try key.signature(for: Data(contentsOf: url)).base64EncodedString()

        XCTAssertTrue(UpdateService.verify(fileAt: url, signature: signature, publicKeys: [publicKey]))

        try "tampered payload".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertFalse(UpdateService.verify(fileAt: url, signature: signature, publicKeys: [publicKey]))
    }

    // MARK: - Key rotation

    /// The rotation guarantee: a build trusting [old, new] accepts a payload signed with
    /// either, so a release can introduce the next key while still being signed by the
    /// current one. Without this, rotating the signing key strands every existing install.
    func testVerifyAcceptsAnyTrustedKey() throws {
        let oldKey = Curve25519.Signing.PrivateKey()
        let newKey = Curve25519.Signing.PrivateKey()
        let trusted = [oldKey, newKey].map { $0.publicKey.rawRepresentation.base64EncodedString() }

        let url = try writeTemp("payload")
        defer { try? FileManager.default.removeItem(at: url) }
        let payload = try Data(contentsOf: url)

        let signedWithOld = try oldKey.signature(for: payload).base64EncodedString()
        let signedWithNew = try newKey.signature(for: payload).base64EncodedString()

        XCTAssertTrue(UpdateService.verify(fileAt: url, signature: signedWithOld, publicKeys: trusted))
        XCTAssertTrue(UpdateService.verify(fileAt: url, signature: signedWithNew, publicKeys: trusted))
    }

    /// A trusted key later in the list must still match — otherwise only the first would count.
    func testVerifyChecksBeyondTheFirstKey() throws {
        let signer = Curve25519.Signing.PrivateKey()
        let unrelated = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()

        let url = try writeTemp("payload")
        defer { try? FileManager.default.removeItem(at: url) }
        let signature = try signer.signature(for: Data(contentsOf: url)).base64EncodedString()

        XCTAssertTrue(UpdateService.verify(
            fileAt: url,
            signature: signature,
            publicKeys: [unrelated, signer.publicKey.rawRepresentation.base64EncodedString()]))
    }

    /// One unparseable entry must not short-circuit the keys after it.
    func testVerifyToleratesAMalformedKeyAlongsideAGoodOne() throws {
        let signer = Curve25519.Signing.PrivateKey()
        let url = try writeTemp("payload")
        defer { try? FileManager.default.removeItem(at: url) }
        let signature = try signer.signature(for: Data(contentsOf: url)).base64EncodedString()

        XCTAssertTrue(UpdateService.verify(
            fileAt: url,
            signature: signature,
            publicKeys: ["!!! not base64 !!!", signer.publicKey.rawRepresentation.base64EncodedString()]))
    }

    /// An empty trust list must reject everything rather than vacuously accept.
    func testVerifyRejectsWhenNoKeysAreTrusted() throws {
        let signer = Curve25519.Signing.PrivateKey()
        let url = try writeTemp("payload")
        defer { try? FileManager.default.removeItem(at: url) }
        let signature = try signer.signature(for: Data(contentsOf: url)).base64EncodedString()

        XCTAssertFalse(UpdateService.verify(fileAt: url, signature: signature, publicKeys: []))
    }

    /// A signature from a different key must not pass, or the embedded key would be pointless.
    func testVerifyRejectsSignatureFromWrongKey() throws {
        let url = try writeTemp("payload")
        defer { try? FileManager.default.removeItem(at: url) }
        let attacker = Curve25519.Signing.PrivateKey()
        let signature = try attacker.signature(for: Data(contentsOf: url)).base64EncodedString()

        XCTAssertFalse(UpdateService.verify(fileAt: url,
                                            signature: signature,
                                            publicKeys: [Self.testPublicKey]))
    }
}
