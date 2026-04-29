import Foundation

enum MascotDirection: String, Codable {
    /// New mascots appear to the right of the notch; older ones stay leftmost.
    case right
    /// New mascots appear to the left of the notch; older ones stay leftmost.
    case left
    /// Mascot group is symmetrically centered. External-screen profile only.
    case center
}

struct ProfileSettings: Codable {
    /// Horizontal offset in points. Negative = shift left, positive = right.
    var horizontalOffset: Int
    /// Vertical offset in points. Positive = shift down, negative = shift up.
    var verticalOffset: Int
    /// Mascot layout direction inside the panel.
    var mascotDirection: MascotDirection

    init(horizontalOffset: Int = 0,
         verticalOffset: Int = 0,
         mascotDirection: MascotDirection = .right) {
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset
        self.mascotDirection = mascotDirection
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        horizontalOffset = try c.decodeIfPresent(Int.self, forKey: .horizontalOffset) ?? 0
        verticalOffset   = try c.decodeIfPresent(Int.self, forKey: .verticalOffset)   ?? 0
        mascotDirection  = try c.decodeIfPresent(MascotDirection.self, forKey: .mascotDirection) ?? .right
    }

    static let defaultNotch    = ProfileSettings(mascotDirection: .right)
    static let defaultExternal = ProfileSettings(mascotDirection: .center)
}

struct DisplaySettings: Codable {
    /// -1 = auto (prefer notch screen), 0...N = specific screen index
    var screenIndex: Int
    /// Profile applied when current screen has a notch.
    var notch: ProfileSettings
    /// Profile applied when current screen has no notch.
    var external: ProfileSettings

    init(screenIndex: Int = -1,
         notch: ProfileSettings = .defaultNotch,
         external: ProfileSettings = .defaultExternal) {
        self.screenIndex = screenIndex
        self.notch = notch
        self.external = external
        coerce()
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        screenIndex = try c.decodeIfPresent(Int.self, forKey: .screenIndex) ?? -1

        if c.contains(.notch) || c.contains(.external) {
            notch    = try c.decodeIfPresent(ProfileSettings.self, forKey: .notch)    ?? .defaultNotch
            external = try c.decodeIfPresent(ProfileSettings.self, forKey: .external) ?? .defaultExternal
        } else {
            // Legacy flat schema (pre-profile): pour values into notch, default external.
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            let h = try legacy.decodeIfPresent(Int.self, forKey: .horizontalOffset) ?? 0
            let v = try legacy.decodeIfPresent(Int.self, forKey: .verticalOffset)   ?? 0
            let d = try legacy.decodeIfPresent(MascotDirection.self, forKey: .mascotDirection) ?? .right
            notch    = ProfileSettings(horizontalOffset: h,
                                       verticalOffset: v,
                                       mascotDirection: d)
            external = .defaultExternal
        }
        coerce()
    }

    /// Centre direction is external-only. Coerce hand-edited notch.center back to .right.
    private mutating func coerce() {
        if notch.mascotDirection == .center {
            notch.mascotDirection = .right
        }
    }

    enum CodingKeys: String, CodingKey {
        case screenIndex, notch, external
    }

    private enum LegacyKeys: String, CodingKey {
        case horizontalOffset, verticalOffset, mascotDirection
    }

    static let `default` = DisplaySettings()
}

enum DisplayConfig {
    static var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/notchify/display.json")
    }

    static func load() -> DisplaySettings {
        guard let data = try? Data(contentsOf: configURL) else { return .default }
        guard let settings = try? JSONDecoder().decode(DisplaySettings.self, from: data) else {
            return .default
        }
        // Detect legacy or partial schema and rewrite once so file matches current shape.
        if let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           raw["notch"] == nil || raw["external"] == nil {
            save(settings)
        }
        return settings
    }

    static func save(_ settings: DisplaySettings) {
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(settings) {
            try? data.write(to: configURL, options: .atomic)
        }
    }
}
