import Foundation

enum MascotDirection: String, Codable {
    /// New mascots appear to the right of the notch; older ones stay leftmost.
    case right
    /// New mascots appear to the left of the notch; older ones stay leftmost.
    case left
}

struct DisplaySettings: Codable {
    /// -1 = auto (prefer notch screen), 0...N = specific screen index
    var screenIndex: Int
    /// Horizontal offset in points. Negative = shift left, positive = right.
    var horizontalOffset: Int
    /// Vertical offset in points. Positive = shift down, negative = shift up.
    var verticalOffset: Int
    /// Which side of the notch new mascots appear on.
    var mascotDirection: MascotDirection

    init(screenIndex: Int = -1,
         horizontalOffset: Int = 0,
         verticalOffset: Int = 0,
         mascotDirection: MascotDirection = .right) {
        self.screenIndex = screenIndex
        self.horizontalOffset = horizontalOffset
        self.verticalOffset = verticalOffset
        self.mascotDirection = mascotDirection
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        screenIndex      = try c.decodeIfPresent(Int.self, forKey: .screenIndex)      ?? -1
        horizontalOffset = try c.decodeIfPresent(Int.self, forKey: .horizontalOffset) ?? 0
        verticalOffset   = try c.decodeIfPresent(Int.self, forKey: .verticalOffset)   ?? 0
        mascotDirection  = try c.decodeIfPresent(MascotDirection.self, forKey: .mascotDirection) ?? .right
    }

    static let `default` = DisplaySettings()
}

enum DisplayConfig {
    static var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/notchify/display.json")
    }

    static func load() -> DisplaySettings {
        guard let data = try? Data(contentsOf: configURL),
              let settings = try? JSONDecoder().decode(DisplaySettings.self, from: data)
        else { return .default }
        return settings
    }
}
