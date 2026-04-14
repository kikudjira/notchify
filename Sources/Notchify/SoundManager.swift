import Foundation
import AppKit

/// Reads ~/.config/notchify/sounds.json and plays the configured sound for each status.
///
/// Config format:
/// {
///   "start":   { "system": "Hero" },
///   "done":    { "system": "Glass" },
///   "waiting": { "system": "Ping" },
///   "error":   { "system": "Basso" },
///   "working": { "file": "~/sounds/working.mp3" },
///   "idle":    null
/// }
///
/// - "system": name of a macOS system sound (Hero, Glass, Ping, Basso, Blow,
///             Bottle, Frog, Funk, Morse, Pop, Purr, Sosumi, Submarine, Tink)
/// - "file":   path to a custom audio file (mp3, wav, aiff); ~ is expanded
/// - null or missing key: no sound for that state

final class SoundManager {
    static let shared = SoundManager()

    private let configURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/notchify")
        return dir.appendingPathComponent("sounds.json")
    }()

    private init() {}

    func play(for status: ClaudeStatus) {
        guard let entry = loadEntry(for: status.rawValue) else { return }

        if let systemName = entry["system"] {
            NSSound(named: NSSound.Name(systemName))?.play()
        } else if let filePath = entry["file"] {
            let expanded = (filePath as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expanded)
            NSSound(contentsOf: url, byReference: false)?.play()
        }
    }

    private static let defaults: [String: [String: String]] = [
        "start":   ["system": "Hero"],
        "done":    ["system": "Glass"],
        "waiting": ["system": "Ping"],
        "error":   ["system": "Basso"],
    ]

    private func loadEntry(for key: String) -> [String: String]? {
        // If config file exists, use it (null or missing key = no sound)
        if FileManager.default.fileExists(atPath: configURL.path),
           let data = try? Data(contentsOf: configURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            guard let value = json[key], !(value is NSNull) else { return nil }
            return value as? [String: String]
        }
        // No config file → fall back to built-in defaults
        return SoundManager.defaults[key]
    }
}
