import Foundation
import AppKit

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
    private static var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/notchify/display.json")
    }

    static func load() -> DisplaySettings {
        guard let data = try? Data(contentsOf: configURL),
              let settings = try? JSONDecoder().decode(DisplaySettings.self, from: data)
        else { return .default }
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

    static func screenList() -> [(index: Int, name: String, hasNotch: Bool, isCurrent: Bool)] {
        let settings = load()
        return NSScreen.screens.enumerated().map { i, screen in
            let hasNotch = screen.auxiliaryTopRightArea != nil
            let scale = screen.backingScaleFactor
            let f = screen.frame
            let pw = Int(f.width  * scale)
            let ph = Int(f.height * scale)
            let name = "\(pw)×\(ph)"
            let isCurrent = settings.screenIndex == i
            return (i, name, hasNotch, isCurrent)
        }
    }
}
