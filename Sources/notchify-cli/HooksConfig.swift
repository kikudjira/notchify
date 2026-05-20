import Foundation

struct HookState {
    var working: Bool
    var done: Bool
    var waiting: Bool
}

enum HooksConfig {
    private static let workingCommands = [
        "notchify set working --agent \"$NOTCHIFY_AGENT_ID\""
    ]
    private static let doneCommands    = ["notchify set done --agent \"$NOTCHIFY_AGENT_ID\""]
    private static let waitingCommands = ["notchify set waiting --agent \"$NOTCHIFY_AGENT_ID\""]

    // Old bare commands (pre-multi-agent) — used for migration detection
    private static let oldWorkingCommand = "notchify set working"
    private static let oldDoneCommand    = "notchify set done"
    private static let oldWaitingCommand = "notchify set waiting"

    // Events that carry the "working" hooks.
    // PostToolUse fires after permission is granted and tool executes —
    // needed to resume working animation when user approves a tool.
    private static let workingEvents = ["UserPromptSubmit", "PostToolUse"]

    // Events that carry the "waiting" hooks.
    // PermissionRequest fires when Claude Code shows a tool approval dialog.
    private static let waitingEvents = ["Notification", "PermissionRequest"]

    /// Resolve target settings.json URLs. Pass an explicit list to override `hook_targets.json`
    /// (used by `--config-dir`); pass `nil` to use the configured targets.
    static func targets(override: [URL]? = nil) -> [URL] {
        let dirs = override ?? HookTargetsConfig.load()
        return dirs.map { $0.appendingPathComponent("settings.json") }
    }

    /// Aggregate read: a hook is reported "on" only if it is enabled in **every** target.
    /// Missing targets (no settings.json yet) count as "off" for that hook.
    static func load(override: [URL]? = nil) -> HookState {
        let urls = targets(override: override)
        guard !urls.isEmpty else { return HookState(working: false, done: false, waiting: false) }

        let workingOn = urls.allSatisfy { url in
            let hooks = hooksDict(at: url)
            return workingEvents.allSatisfy { commandPresent(workingCommands[0], in: hooks, event: $0) }
        }
        let waitingOn = urls.allSatisfy { url in
            let hooks = hooksDict(at: url)
            return waitingEvents.allSatisfy { commandPresent(waitingCommands[0], in: hooks, event: $0) }
        }
        let doneOn = urls.allSatisfy { url in
            commandPresent(doneCommands[0], in: hooksDict(at: url), event: "Stop")
        }
        return HookState(working: workingOn, done: doneOn, waiting: waitingOn)
    }

    static func setWorking(_ enabled: Bool, override: [URL]? = nil) {
        mutate(events: workingEvents, command: workingCommands[0], enabled: enabled, override: override)
    }

    static func setDone(_ enabled: Bool, override: [URL]? = nil) {
        mutate(events: ["Stop"], command: doneCommands[0], enabled: enabled, override: override)
    }

    static func setWaiting(_ enabled: Bool, override: [URL]? = nil) {
        mutate(events: waitingEvents, command: waitingCommands[0], enabled: enabled, override: override)
    }

    /// Re-apply hook state to every target using **union** semantics: a hook present in
    /// any target is propagated to all. This is what makes "add a new config dir" work —
    /// the new (empty) target picks up hooks from the existing ones rather than dragging
    /// them down.
    static func reinstall(override: [URL]? = nil) {
        let urls = targets(override: override)
        guard !urls.isEmpty else { return }

        let workingOn = urls.contains { url in
            let hooks = hooksDict(at: url)
            return workingEvents.contains { commandPresent(workingCommands[0], in: hooks, event: $0) }
        }
        let waitingOn = urls.contains { url in
            let hooks = hooksDict(at: url)
            return waitingEvents.contains { commandPresent(waitingCommands[0], in: hooks, event: $0) }
        }
        let doneOn = urls.contains { url in
            commandPresent(doneCommands[0], in: hooksDict(at: url), event: "Stop")
        }

        setWorking(workingOn, override: override)
        setDone(doneOn,       override: override)
        setWaiting(waitingOn, override: override)
    }

    /// Replaces old bare-command hooks (without --agent) with the new form.
    /// Called on every `notchify launch` — idempotent across every configured target.
    static func migrate(override: [URL]? = nil) {
        for url in targets(override: override) {
            migrateOne(url: url)
        }
    }

    // MARK: - Per-target operations

    private static func mutate(events: [String], command: String, enabled: Bool, override: [URL]?) {
        for url in targets(override: override) {
            var json = loadJSON(url: url) ?? [:]
            var hooks = json["hooks"] as? [String: Any] ?? [:]
            for event in events {
                if enabled {
                    addHook(command: command, event: event, hooks: &hooks)
                } else {
                    removeHook(command: command, event: event, hooks: &hooks)
                }
            }
            json["hooks"] = hooks
            saveJSON(json, url: url)
        }
    }

    private static func migrateOne(url: URL) {
        var json = loadJSON(url: url) ?? [:]
        var hooks = json["hooks"] as? [String: Any] ?? [:]
        var changed = false

        let migrations: [(old: String, new: String, events: [String])] = [
            (oldWorkingCommand, workingCommands[0], workingEvents),
            (oldDoneCommand,    doneCommands[0],    ["Stop"]),
            (oldWaitingCommand, waitingCommands[0], waitingEvents),
        ]

        for m in migrations {
            for event in m.events {
                if commandPresent(m.old, in: hooks, event: event)
                    && !commandPresent(m.new, in: hooks, event: event) {
                    removeHook(command: m.old, event: event, hooks: &hooks)
                    addHook(command: m.new, event: event, hooks: &hooks)
                    changed = true
                }
            }
        }

        // Add PermissionRequest if Notification waiting hook exists but PermissionRequest doesn't
        if commandPresent(waitingCommands[0], in: hooks, event: "Notification")
            && !commandPresent(waitingCommands[0], in: hooks, event: "PermissionRequest") {
            addHook(command: waitingCommands[0], event: "PermissionRequest", hooks: &hooks)
            changed = true
        }

        if changed {
            json["hooks"] = hooks
            saveJSON(json, url: url)
        }
    }

    // MARK: - Helpers

    private static func hooksDict(at url: URL) -> [String: Any] {
        (loadJSON(url: url)?["hooks"] as? [String: Any]) ?? [:]
    }

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

    private static func loadJSON(url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    private static func saveJSON(_ json: [String: Any], url: URL) {
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let data = try? JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
