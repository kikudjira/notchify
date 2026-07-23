import Foundation

/// Finds Notchify.app regardless of install method.
/// Search order:
///   1. ~/.config/notchify/app_path  (written by post_install or setup.sh)
///   2. Homebrew opt symlink         (version-stable, survives upgrades)
///   3. Homebrew Cellar              (newest version first)
///   4. /Applications/Notchify.app
///   5. Walk up from this binary     (local dev / swift run)
/// Homebrew's version-independent symlink. Unlike a Cellar path it keeps
/// pointing at the current build after `brew upgrade`.
let stableAppPath = "/opt/homebrew/opt/notchify/Notchify.app"

func resolveAppPath() -> String {
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

    // 2. Homebrew opt symlink — stays valid across `brew upgrade`
    if fm.fileExists(atPath: stableAppPath) { return stableAppPath }

    // 3. Homebrew Cellar (works even when post_install sandbox blocks the write)
    let cellarBase = "/opt/homebrew/Cellar/notchify"
    if let versions = try? fm.contentsOfDirectory(atPath: cellarBase) {
        for version in versions.sorted().reversed() {
            let candidate = "\(cellarBase)/\(version)/Notchify.app"
            if fm.fileExists(atPath: candidate) { return candidate }
        }
    }

    // 4. /Applications
    let appDir = "/Applications/Notchify.app"
    if fm.fileExists(atPath: appDir) { return appDir }

    // 5. Walk up from this binary (local dev / swift run)
    let raw = CommandLine.arguments[0]
    let abs = raw.hasPrefix("/") ? raw : fm.currentDirectoryPath + "/" + raw
    var url = URL(fileURLWithPath: abs).resolvingSymlinksInPath()
    while url.pathComponents.count > 1 {
        if url.pathExtension == "app" { return url.path }
        url = url.deletingLastPathComponent()
    }
    return ""
}
