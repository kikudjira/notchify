import Foundation
import AppKit

/// Reads ~/.config/notchify/sounds.json and plays the configured sound for each status.
///
/// Config format:
/// {
///   "volume":  0.5,
///   "start":   { "system": "Hero" },
///   "done":    { "system": "Glass" },
///   "waiting": { "system": "Ping" },
///   "error":   { "system": "Basso" },
///   "working": { "file": "~/sounds/working.mp3" },
///   "idle":    null
/// }
///
/// - "volume":  top-level 0.0–1.0 multiplier applied to every sound, scaled
///              further by the macOS system output volume. Missing = 1.0.
/// - "system":  name of a macOS system sound (Hero, Glass, Ping, Basso, Blow,
///              Bottle, Frog, Funk, Morse, Pop, Purr, Sosumi, Submarine, Tink)
/// - "file":    path to a custom audio file (mp3, wav, aiff); ~ is expanded
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
        let (entry, volume) = loadEntry(for: status.rawValue)
        guard let entry else { return }

        let sound: NSSound?
        if let systemName = entry["system"] {
            sound = NSSound(named: NSSound.Name(systemName))
        } else if let filePath = entry["file"] {
            let expanded = (filePath as NSString).expandingTildeInPath
            sound = NSSound(contentsOf: URL(fileURLWithPath: expanded), byReference: false)
        } else {
            sound = nil
        }
        guard let sound else { return }
        sound.volume = volume
        sound.play()
    }

    private static let defaults: [String: [String: String]] = [
        "start":   ["system": "Hero"],
        "done":    ["system": "Glass"],
        "waiting": ["system": "Ping"],
        "error":   ["system": "Basso"],
    ]

    /// Returns (entry, globalVolume). entry == nil → no sound for this state.
    private func loadEntry(for key: String) -> (entry: [String: String]?, volume: Float) {
        // If config file exists, use it (null or missing key = no sound)
        if FileManager.default.fileExists(atPath: configURL.path),
           let data = try? Data(contentsOf: configURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let volume = Self.clampVolume(json["volume"])
            guard let value = json[key], !(value is NSNull) else { return (nil, volume) }
            return (value as? [String: String], volume)
        }
        // No config file → fall back to built-in defaults at full volume
        return (SoundManager.defaults[key], 1.0)
    }

    private static func clampVolume(_ value: Any?) -> Float {
        guard let value = value else { return 1.0 }
        let raw: Float
        if let n = value as? NSNumber { raw = n.floatValue }
        else if let s = value as? String, let n = Float(s) { raw = n }
        else { return 1.0 }
        return max(0.0, min(1.0, raw))
    }
}
