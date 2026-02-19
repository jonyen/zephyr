import Foundation
import AppKit

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

    func checkForUpdate(manual: Bool = false) async {
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

            guard let httpResponse = response as? HTTPURLResponse else {
                state = .idle
                return
            }

            // 404 means no releases exist yet — not an error
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 404 {
                    state = .idle
                } else {
                    state = .error("Failed to check for updates (HTTP \(httpResponse.statusCode))")
                }
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let remoteVersion = release.tagName

            guard Self.isNewer(remoteVersion, than: currentAppVersion) else {
                state = manual ? .upToDate : .idle
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
