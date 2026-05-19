import Foundation

enum HookTargetsConfig {
    static let configURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/notchify/hook_targets.json")

    static let defaultTarget: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude")

    /// Returns the list of Claude config directories where hooks should be installed.
    /// Missing file or parse error falls back to `[~/.claude]` so first-run behavior is unchanged.
    static func load() -> [URL] {
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = json["targets"] as? [String]
        else {
            return [defaultTarget]
        }
        let urls = raw.map { expand($0) }
        return urls.isEmpty ? [defaultTarget] : urls
    }

    static func save(_ urls: [URL]) {
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let payload: [String: Any] = ["targets": urls.map { $0.path }]
        guard let data = try? JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        try? data.write(to: configURL, options: .atomic)
    }

    static func add(_ url: URL) {
        var current = load()
        let key = canonical(url)
        if !current.contains(where: { canonical($0) == key }) {
            current.append(url)
            save(current)
        }
    }

    static func remove(_ url: URL) {
        let key = canonical(url)
        let filtered = load().filter { canonical($0) != key }
        save(filtered)
    }

    /// Returns directories matching `~/.claude*` plus `$CLAUDE_CONFIG_DIR` (if set).
    /// Symlinks are resolved so a `claude-personal → .claude` link does not double-list.
    static func detectCandidates() -> [URL] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var seen = Set<String>()
        var result: [URL] = []

        func append(_ url: URL) {
            let key = canonical(url)
            guard !seen.contains(key) else { return }
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else { return }
            seen.insert(key)
            result.append(url)
        }

        // Always offer ~/.claude even if it doesn't exist yet — most users have it.
        append(home.appendingPathComponent(".claude"))

        if let entries = try? fm.contentsOfDirectory(atPath: home.path) {
            for name in entries.sorted() where name.hasPrefix(".claude") {
                append(home.appendingPathComponent(name))
            }
        }

        if let env = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"], !env.isEmpty {
            append(expand(env))
        }

        return result
    }

    // MARK: - Helpers

    /// Expand leading `~` to the user's home directory.
    static func expand(_ path: String) -> URL {
        if path.hasPrefix("~/") {
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(String(path.dropFirst(2)))
        }
        if path == "~" {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    /// Canonical absolute path with symlinks resolved. Used for dedup only.
    private static func canonical(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }
}
