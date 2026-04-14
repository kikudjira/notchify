import Foundation

enum ShellWrapperConfig {
    private static let marker = "notchify set start"
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
  notchify set start
  command claude "$@"
  notchify set bye
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

    /// Replaces the old ~/bin/notchify wrapper with the plain-notchify wrapper in-place.
    /// Called on every `notchify launch` so the migration is transparent to the user.
    static func migrateIfNeeded() {
        let old = "~/bin/notchify set"
        for rc in rcFiles {
            let path = (rc as NSString).expandingTildeInPath
            guard var contents = try? String(contentsOfFile: path, encoding: .utf8),
                  contents.contains(old) else { continue }
            contents = contents.replacingOccurrences(of: "~/bin/notchify set", with: "notchify set")
            try? contents.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    static func disable() {
        for rc in rcFiles {
            let path = (rc as NSString).expandingTildeInPath
            guard let contents = try? String(contentsOfFile: path, encoding: .utf8),
                  contents.contains(marker) else { continue }

            // Remove the block: from the comment line (or function line) to closing }
            var lines = contents.components(separatedBy: "\n")
            var i = 0
            while i < lines.count {
                let line = lines[i].trimmingCharacters(in: .whitespaces)
                if line.contains("Added by Notchify setup") || line.hasPrefix("function claude()") {
                    // Find the closing brace of the function
                    let start = (line.contains("Added by Notchify setup")) ? i : i
                    var end = start
                    // Skip to closing }
                    for j in start..<lines.count {
                        if lines[j].trimmingCharacters(in: .whitespaces) == "}" {
                            end = j
                            break
                        }
                    }
                    // Also eat the blank line before the comment if present
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
