import Foundation

enum LoginItemConfig {
    private static let label = "com.notchify.app"

    private static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// The binary launchd should start. Prefers the version-stable Homebrew
    /// symlink: a Cellar path breaks on the next `brew upgrade`, leaving the
    /// login item enabled but failing to spawn (EX_CONFIG).
    private static func launchBinary() -> String {
        let resolved = appPath()
        if resolved.hasPrefix("/opt/homebrew/Cellar/notchify/"),
           FileManager.default.fileExists(atPath: stableAppPath) {
            return stableAppPath + "/Contents/MacOS/Notchify"
        }
        return resolved + "/Contents/MacOS/Notchify"
    }

    /// Rewrites the plist when it points at a binary that no longer exists
    /// (typical after a Homebrew upgrade wiped the old Cellar version).
    @discardableResult
    static func repairIfStale() -> Bool {
        guard isEnabled(),
              let plist = try? String(contentsOf: plistURL, encoding: .utf8)
        else { return false }

        let current = launchBinary()
        guard !plist.contains("<string>\(current)</string>") else { return false }
        return enable()
    }

    @discardableResult
    static func enable() -> Bool {
        let binary = launchBinary()
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
            "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binary)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
        </dict>
        </plist>
        """
        do {
            try plist.write(to: plistURL, atomically: true, encoding: .utf8)
            reloadService()
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func disable() -> Bool {
        launchctl(["bootout", domainTarget])
        try? FileManager.default.removeItem(at: plistURL)
        return !FileManager.default.fileExists(atPath: plistURL.path)
    }

    // MARK: - launchd

    private static var domainTarget: String { "gui/\(getuid())/\(label)" }

    /// Re-registers the job so a fresh or repaired plist takes effect now
    /// instead of at the next login.
    private static func reloadService() {
        launchctl(["bootout", domainTarget])
        launchctl(["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    private static func launchctl(_ args: [String]) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = args
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
    }

    // MARK: - App path

    static func appPath() -> String { resolveAppPath() }
}
