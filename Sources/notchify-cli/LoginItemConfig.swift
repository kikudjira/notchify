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

    private static func resolveAppPath() -> String {
        let fm = FileManager.default

        // 1. Explicit app_path file
        let savedPath = fm.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/notchify/app_path").path
        if let saved = try? String(contentsOfFile: savedPath, encoding: .utf8) {
            let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed.hasSuffix(".app") && fm.fileExists(atPath: trimmed) {
                return trimmed
            }
        }

        // 2. Homebrew Cellar
        let cellarBase = "/opt/homebrew/Cellar/notchify"
        if let versions = try? fm.contentsOfDirectory(atPath: cellarBase) {
            for version in versions.sorted().reversed() {
                let candidate = "\(cellarBase)/\(version)/Notchify.app"
                if fm.fileExists(atPath: candidate) { return candidate }
            }
        }

        // 3. /Applications
        let appDir = "/Applications/Notchify.app"
        if fm.fileExists(atPath: appDir) { return appDir }

        // 4. Walk up from this binary (local dev)
        let raw = CommandLine.arguments[0]
        let abs = raw.hasPrefix("/") ? raw : fm.currentDirectoryPath + "/" + raw
        var url = URL(fileURLWithPath: abs).resolvingSymlinksInPath()
        while url.pathComponents.count > 1 {
            if url.pathExtension == "app" { return url.path }
            url = url.deletingLastPathComponent()
        }
        return ""
    }
}
