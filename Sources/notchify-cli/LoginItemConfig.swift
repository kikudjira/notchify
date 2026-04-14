import Foundation

enum LoginItemConfig {
    static func isEnabled() -> Bool {
        let script = #"tell application "System Events" to get the name of every login item"#
        return runOsascript(script).output.contains("Notchify")
    }

    @discardableResult
    static func enable() -> Bool {
        let appPath = resolveAppPath()
        let script = """
tell application "System Events" to make login item at end with properties {path:"\(appPath)", hidden:true}
"""
        return runOsascript(script).exitCode == 0
    }

    @discardableResult
    static func disable() -> Bool {
        return runOsascript(#"tell application "System Events" to delete login item "Notchify""#).exitCode == 0
    }

    // MARK: - Helpers

    static func appPath() -> String { resolveAppPath() }

    private static func resolveAppPath() -> String {
        // Primary: read path saved by setup.sh
        let savedPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/notchify/app_path").path
        if let saved = try? String(contentsOfFile: savedPath, encoding: .utf8) {
            let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && FileManager.default.fileExists(atPath: trimmed) {
                return trimmed
            }
        }

        // Fallback: walk up from fully-resolved argv[0] looking for .app
        let cliRaw = CommandLine.arguments[0]
        let absPath = cliRaw.hasPrefix("/") ? cliRaw
            : FileManager.default.currentDirectoryPath + "/" + cliRaw
        var url = URL(fileURLWithPath: absPath).resolvingSymlinksInPath()
        while url.pathComponents.count > 1 {
            if url.pathExtension == "app" { return url.path }
            url = url.deletingLastPathComponent()
        }
        return url.path
    }

    private struct OsascriptResult {
        let output: String
        let exitCode: Int32
    }

    private static func runOsascript(_ script: String) -> OsascriptResult {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        try? proc.run()
        proc.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return OsascriptResult(output: output, exitCode: proc.terminationStatus)
    }
}
