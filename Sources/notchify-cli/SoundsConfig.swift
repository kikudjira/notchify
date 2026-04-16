import Foundation

enum SoundEntry: Equatable {
    case system(String)
    case file(String)
    case none

    var displayString: String {
        switch self {
        case .system(let n): return "system: \(n)"
        case .file(let p):   return "file: \(p)"
        case .none:          return "(none)"
        }
    }
}

struct SoundsConfig {
    /// Global volume 0.0–1.0, applied to every sound. Scaled further by macOS system volume.
    var volume: Float = 1.0

    var start:   SoundEntry = .system("Hero")
    var working: SoundEntry = .none
    var waiting: SoundEntry = .system("Ping")
    var done:    SoundEntry = .system("Glass")
    var bye:     SoundEntry = .none
    var error:   SoundEntry = .system("Basso")
    var idle:    SoundEntry = .none

    static let configURL: URL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/notchify/sounds.json")

    static let systemSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass",
        "Hero", "Morse", "Ping", "Pop", "Purr", "Sosumi",
        "Submarine", "Tink"
    ]

    static func load() -> SoundsConfig {
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return SoundsConfig() }

        var config = SoundsConfig()
        config.volume  = parseVolume(json["volume"])
        config.start   = parseEntry(json["start"])
        config.working = parseEntry(json["working"])
        config.waiting = parseEntry(json["waiting"])
        config.done    = parseEntry(json["done"])
        config.bye     = parseEntry(json["bye"])
        config.error   = parseEntry(json["error"])
        config.idle    = parseEntry(json["idle"])
        return config
    }

    func save() {
        let dir = SoundsConfig.configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var json: [String: Any] = [
            "start":   encodeEntry(start),
            "working": encodeEntry(working),
            "waiting": encodeEntry(waiting),
            "done":    encodeEntry(done),
            "bye":     encodeEntry(bye),
            "error":   encodeEntry(error),
            "idle":    encodeEntry(idle)
        ]
        if volume < 0.999 { json["volume"] = volume }

        guard let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        try? data.write(to: SoundsConfig.configURL, options: .atomic)
    }

    // MARK: - Codable helpers

    private static func parseEntry(_ value: Any?) -> SoundEntry {
        guard let value = value, !(value is NSNull) else { return .none }
        guard let dict = value as? [String: String] else { return .none }
        if let name = dict["system"] { return .system(name) }
        if let path = dict["file"]   { return .file(path) }
        return .none
    }

    private static func parseVolume(_ value: Any?) -> Float {
        guard let value = value else { return 1.0 }
        if let n = value as? NSNumber { return max(0.0, min(1.0, n.floatValue)) }
        if let s = value as? String, let n = Float(s) { return max(0.0, min(1.0, n)) }
        return 1.0
    }

    private func encodeEntry(_ entry: SoundEntry) -> Any {
        switch entry {
        case .none:          return NSNull()
        case .system(let n): return ["system": n]
        case .file(let p):   return ["file": p]
        }
    }
}
