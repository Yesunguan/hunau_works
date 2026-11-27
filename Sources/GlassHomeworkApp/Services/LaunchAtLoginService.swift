import Foundation

@MainActor
final class LaunchAtLoginService {
    private let label = "com.glasshomework.app"

    private var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
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
        let dir = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

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
    }

    private func uninstall() throws {
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }
}
