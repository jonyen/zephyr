import Foundation
import AppKit
import CryptoKit

@Observable
class UpdateService {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case updateAvailable(version: String, notes: String, downloadURL: URL)
        case downloading(progress: Double)
        case readyToInstall(localURL: URL)
        case error(String)

        static func == (lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.checking, .checking), (.upToDate, .upToDate): return true
            case let (.updateAvailable(v1, n1, u1), .updateAvailable(v2, n2, u2)):
                return v1 == v2 && n1 == n2 && u1 == u2
            case let (.downloading(p1), .downloading(p2)): return p1 == p2
            case let (.readyToInstall(u1), .readyToInstall(u2)): return u1 == u2
            case let (.error(e1), .error(e2)): return e1 == e2
            default: return false
            }
        }
    }

    /// What the release workflow publishes to the update host.
    ///
    /// The GitHub releases API can't be used: this repo is private, so unauthenticated
    /// requests get a 404 and the app has no way to see its own releases.
    struct UpdateManifest: Codable {
        let version: String
        let notes: String
        let zipURL: String
        /// Base64 Ed25519 signature over the zip's bytes.
        let signature: String
    }

    private(set) var state: State = .idle

    private let manifestURL = "https://jonyen.com/zephyr-updates/manifest.json"

    /// Verifies the downloaded zip actually came from our release workflow.
    ///
    /// `installAndRelaunch` replaces the running app bundle with whatever was downloaded, so
    /// HTTPS alone isn't enough — anything able to write to the update host could otherwise
    /// hand the app arbitrary code to run. The matching private key exists only as the
    /// UPDATE_SIGNING_KEY secret in CI. Public keys are not secrets; this one is meant to ship.
    private let updatePublicKey = "OZVuZglmktdVMpL0cqRrBjBdyO0AWvsaK/QGXkrYP2A="

    /// Signature for the update currently on offer, carried from the manifest to the download.
    private var pendingSignature: String?

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

    func checkForUpdate(manual: Bool = false) async {
        state = .checking
        pendingSignature = nil

        guard let url = URL(string: manifestURL) else {
            state = .error("Invalid update manifest URL")
            return
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            // The manifest changes on release and is small; a cached copy would hide new versions.
            request.cachePolicy = .reloadIgnoringLocalCacheData

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                state = manual ? .error("Update check got no response") : .idle
                return
            }

            // Any non-200 means the manifest couldn't be read. A previous version treated 404
            // as "no releases yet" and silently reported success, which is exactly how a
            // completely unreachable update feed went unnoticed. Say so instead.
            guard httpResponse.statusCode == 200 else {
                state = manual
                    ? .error("Couldn't reach updates (HTTP \(httpResponse.statusCode))")
                    : .idle
                return
            }

            let manifest = try JSONDecoder().decode(UpdateManifest.self, from: data)

            guard Self.isNewer(manifest.version, than: currentAppVersion) else {
                state = manual ? .upToDate : .idle
                return
            }

            guard let downloadURL = URL(string: manifest.zipURL) else {
                state = .error("Update manifest has an invalid download URL")
                return
            }

            pendingSignature = manifest.signature
            let cleanVersion = manifest.version.hasPrefix("v")
                ? String(manifest.version.dropFirst())
                : manifest.version
            state = .updateAvailable(
                version: cleanVersion,
                notes: manifest.notes.isEmpty ? "No release notes." : manifest.notes,
                downloadURL: downloadURL
            )
        } catch {
            state = manual ? .error("Update check failed: \(error.localizedDescription)") : .idle
        }
    }

    // MARK: - Download update

    func downloadUpdate(from url: URL) async {
        state = .downloading(progress: 0)

        guard let signature = pendingSignature else {
            state = .error("Update is unsigned — refusing to install")
            return
        }

        do {
            let (tempURL, _) = try await URLSession.shared.download(from: url, delegate: nil)

            let destURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("ZephyrUpdate-\(UUID().uuidString).zip")
            try FileManager.default.moveItem(at: tempURL, to: destURL)

            // Verify before the zip can reach installAndRelaunch, which would otherwise
            // extract it over the running app. A payload that fails here is deleted, not kept.
            guard Self.verify(fileAt: destURL, signature: signature, publicKey: updatePublicKey) else {
                try? FileManager.default.removeItem(at: destURL)
                state = .error("Update failed signature check — not installing")
                return
            }

            state = .readyToInstall(localURL: destURL)
        } catch {
            state = .error("Download failed: \(error.localizedDescription)")
        }
    }

    /// Checks an Ed25519 signature over a file's bytes. Any malformed input fails closed.
    static func verify(fileAt url: URL, signature: String, publicKey: String) -> Bool {
        guard let signatureData = Data(base64Encoded: signature),
              let publicKeyData = Data(base64Encoded: publicKey),
              let payload = try? Data(contentsOf: url),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData) else {
            return false
        }
        return key.isValidSignature(signatureData, for: payload)
    }

    // MARK: - Install and relaunch

    func installAndRelaunch(from zipURL: URL) {
        guard let appBundlePath = Bundle.main.bundlePath as String? else {
            state = .error("Cannot determine app location")
            return
        }

        let extractDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ZephyrExtract-\(UUID().uuidString)")

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

        let contents = (try? FileManager.default.contentsOfDirectory(atPath: extractDir.path)) ?? []
        guard let appName = contents.first(where: { $0.hasSuffix(".app") }) else {
            state = .error("No .app found in update")
            return
        }
        let newAppPath = extractDir.appendingPathComponent(appName).path

        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        #!/bin/bash
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        rm -rf "\(appBundlePath)"
        mv "\(newAppPath)" "\(appBundlePath)"
        rm -rf "\(extractDir.path)"
        rm -f "\(zipURL.path)"
        open "\(appBundlePath)"
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

        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }

    func dismiss() {
        state = .idle
    }
}
