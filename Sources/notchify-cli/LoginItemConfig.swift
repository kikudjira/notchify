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

    @discardableResult
    static func enable() -> Bool {
        let binary = appPath() + "/Contents/MacOS/Notchify"
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
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    static func disable() -> Bool {
        try? FileManager.default.removeItem(at: plistURL)
        return !FileManager.default.fileExists(atPath: plistURL.path)
    }

    // MARK: - App path

    static func appPath() -> String { resolveAppPath() }
}
