import Foundation

struct DisplaySettings: Codable {
    /// -1 = auto (prefer notch screen), 0...N = specific screen index
    var screenIndex: Int
    /// Horizontal offset in points. Negative = shift left, positive = right.
    var horizontalOffset: Int
    /// Vertical offset in points. Positive = shift down, negative = shift up.
    var verticalOffset: Int

    static let `default` = DisplaySettings(screenIndex: -1, horizontalOffset: 0, verticalOffset: 0)
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
