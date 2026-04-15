import Foundation

enum ShellWrapperConfig {
    // Marker present in the new wrapper (absent from the old one)
    private static let marker = "NOTCHIFY_AGENT_ID"
    private static let rcFiles = ["~/.zshrc", "~/.bashrc"]

    static func isEnabled() -> Bool {
        for rc in rcFiles {
            let path = (rc as NSString).expandingTildeInPath
            if let contents = try? String(contentsOfFile: path, encoding: .utf8),
               contents.contains(marker) {
                return true
            }
        }
        return false
    }

    static func enable() {
        let block = """

# Added by Notchify setup — startup animation
function claude() {
  export NOTCHIFY_AGENT_ID=$$
  notchify set start --agent "$NOTCHIFY_AGENT_ID"
  command claude "$@"
  notchify set bye --agent "$NOTCHIFY_AGENT_ID"
}
"""
        for rc in rcFiles {
            let path = (rc as NSString).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: path) else { continue }
            guard let contents = try? String(contentsOfFile: path, encoding: .utf8),
                  !contents.contains(marker) else { continue }
            let updated = contents + block
            try? updated.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    /// Transparently migrates old wrappers on every `notchify launch`.
    /// Pass 1: ~/bin/notchify → notchify (original migration)
    /// Pass 2: old wrapper without NOTCHIFY_AGENT_ID → new wrapper with agent ID
    static func migrateIfNeeded() {
        let oldBin = "~/bin/notchify set"
        for rc in rcFiles {
            let path = (rc as NSString).expandingTildeInPath
            guard var contents = try? String(contentsOfFile: path, encoding: .utf8) else { continue }

            // Pass 1: ~/bin/notchify → plain notchify
            if contents.contains(oldBin) {
                contents = contents.replacingOccurrences(of: "~/bin/notchify set", with: "notchify set")
                try? contents.write(toFile: path, atomically: true, encoding: .utf8)
            }

            // Pass 2: old wrapper (has "notchify set start" but not NOTCHIFY_AGENT_ID)
            if contents.contains("notchify set start") && !contents.contains(marker) {
                // Remove the old block then re-append the new one
                var lines = contents.components(separatedBy: "\n")
                var i = 0
                while i < lines.count {
                    let line = lines[i].trimmingCharacters(in: .whitespaces)
                    if line.contains("Added by Notchify setup") || line.hasPrefix("function claude()") {
                        let start = i
                        var end = start
                        for j in start..<lines.count {
                            if lines[j].trimmingCharacters(in: .whitespaces) == "}" {
                                end = j
                                break
                            }
                        }
                        let removeFrom = (start > 0 && lines[start - 1].trimmingCharacters(in: .whitespaces).isEmpty)
                            ? start - 1 : start
                        lines.removeSubrange(removeFrom...end)
                        i = removeFrom
                    } else {
                        i += 1
                    }
                }
                contents = lines.joined(separator: "\n")
                try? contents.write(toFile: path, atomically: true, encoding: .utf8)
                // Now append the new block via enable()
            }
        }
        // Re-run enable() to add the new block to any file that now lacks it
        enable()
    }

    static func disable() {
        for rc in rcFiles {
            let path = (rc as NSString).expandingTildeInPath
            // Check for either old or new marker
            guard let contents = try? String(contentsOfFile: path, encoding: .utf8),
                  contents.contains("notchify set start") || contents.contains(marker)
            else { continue }

            var lines = contents.components(separatedBy: "\n")
            var i = 0
            while i < lines.count {
                let line = lines[i].trimmingCharacters(in: .whitespaces)
                if line.contains("Added by Notchify setup") || line.hasPrefix("function claude()") {
                    let start = i
                    var end = start
                    for j in start..<lines.count {
                        if lines[j].trimmingCharacters(in: .whitespaces) == "}" {
                            end = j
                            break
                        }
                    }
                    let removeFrom = (start > 0 && lines[start - 1].trimmingCharacters(in: .whitespaces).isEmpty)
                        ? start - 1 : start
                    lines.removeSubrange(removeFrom...end)
                    i = removeFrom
                } else {
                    i += 1
                }
            }
            let updated = lines.joined(separator: "\n")
            try? updated.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}
