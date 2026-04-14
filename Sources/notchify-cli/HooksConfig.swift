import Foundation

struct HookState {
    var working: Bool
    var done: Bool
    var waiting: Bool
}

enum HooksConfig {
    static let settingsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")

    private static let workingCommands = [
        "~/bin/notchify set working"
    ]
    private static let doneCommands    = ["~/bin/notchify set done"]
    private static let waitingCommands = ["~/bin/notchify set waiting"]

    // Events that carry the "working" hooks
    private static let workingEvents = ["UserPromptSubmit"]

    static func load() -> HookState {
        guard let json = loadJSON() else { return HookState(working: false, done: false, waiting: false) }
        let hooks = json["hooks"] as? [String: Any] ?? [:]

        let workingOn = workingEvents.allSatisfy { event in
            commandPresent(workingCommands[0], in: hooks, event: event)
        }
        return HookState(
            working: workingOn,
            done:    commandPresent(doneCommands[0],    in: hooks, event: "Stop"),
            waiting: commandPresent(waitingCommands[0], in: hooks, event: "Notification")
        )
    }

    static func setWorking(_ enabled: Bool) {
        var json = loadJSON() ?? [:]
        var hooks = json["hooks"] as? [String: Any] ?? [:]
        for event in workingEvents {
            if enabled {
                addHook(command: workingCommands[0], event: event, hooks: &hooks)
            } else {
                removeHook(command: workingCommands[0], event: event, hooks: &hooks)
            }
        }
        json["hooks"] = hooks
        saveJSON(json)
    }

    static func setDone(_ enabled: Bool) {
        var json = loadJSON() ?? [:]
        var hooks = json["hooks"] as? [String: Any] ?? [:]
        if enabled {
            addHook(command: doneCommands[0], event: "Stop", hooks: &hooks)
        } else {
            removeHook(command: doneCommands[0], event: "Stop", hooks: &hooks)
        }
        json["hooks"] = hooks
        saveJSON(json)
    }

    static func setWaiting(_ enabled: Bool) {
        var json = loadJSON() ?? [:]
        var hooks = json["hooks"] as? [String: Any] ?? [:]
        if enabled {
            addHook(command: waitingCommands[0], event: "Notification", hooks: &hooks)
        } else {
            removeHook(command: waitingCommands[0], event: "Notification", hooks: &hooks)
        }
        json["hooks"] = hooks
        saveJSON(json)
    }

    // MARK: - Helpers

    private static func commandPresent(_ command: String, in hooks: [String: Any], event: String) -> Bool {
        guard let entries = hooks[event] as? [[String: Any]] else { return false }
        return entries.contains { entry in
            (entry["hooks"] as? [[String: Any]] ?? []).contains { $0["command"] as? String == command }
        }
    }

    private static func addHook(command: String, event: String, hooks: inout [String: Any]) {
        var entries = hooks[event] as? [[String: Any]] ?? []
        let alreadyPresent = entries.contains { entry in
            (entry["hooks"] as? [[String: Any]] ?? []).contains { $0["command"] as? String == command }
        }
        guard !alreadyPresent else { return }
        entries.append(["hooks": [["type": "command", "command": command]]])
        hooks[event] = entries
    }

    private static func removeHook(command: String, event: String, hooks: inout [String: Any]) {
        guard var entries = hooks[event] as? [[String: Any]] else { return }
        entries = entries.filter { entry in
            let inner = entry["hooks"] as? [[String: Any]] ?? []
            return !inner.contains { $0["command"] as? String == command }
        }
        if entries.isEmpty {
            hooks.removeValue(forKey: event)
        } else {
            hooks[event] = entries
        }
    }

    private static func loadJSON() -> [String: Any]? {
        guard let data = try? Data(contentsOf: settingsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    private static func saveJSON(_ json: [String: Any]) {
        guard let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        try? data.write(to: settingsURL, options: .atomic)
    }
}
