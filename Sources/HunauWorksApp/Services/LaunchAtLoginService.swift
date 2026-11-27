import Foundation

@MainActor
final class LaunchAtLoginService {
    private let label = "com.hunau.works"
    private let legacyLabel = "com.glasshomework.app"

    private var launchAgentsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
    }

    private var plistURL: URL {
        launchAgentsDir.appendingPathComponent("\(label).plist")
    }

    private var legacyPlistURL: URL {
        launchAgentsDir.appendingPathComponent("\(legacyLabel).plist")
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
            || FileManager.default.fileExists(atPath: legacyPlistURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try install()
        } else {
            try uninstall()
        }
    }

    func syncPathIfInstalled() {
        guard isInstalled else { return }
        try? install()
    }

    private func install() throws {
        try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)

        let installedAppPath = "/Applications/湘农作业.app"
        let targetAppPath: String
        if FileManager.default.fileExists(atPath: installedAppPath) {
            targetAppPath = installedAppPath
        } else {
            targetAppPath = Bundle.main.bundlePath
        }

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-a", targetAppPath],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: legacyPlistURL.path) {
            try? FileManager.default.removeItem(at: legacyPlistURL)
        }
    }

    private func uninstall() throws {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
        if FileManager.default.fileExists(atPath: legacyPlistURL.path) {
            try FileManager.default.removeItem(at: legacyPlistURL)
        }
    }
}
