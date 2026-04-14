import Foundation
import AppKit

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
        if let data = try? JSONEncoder().encode(settings) {
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
