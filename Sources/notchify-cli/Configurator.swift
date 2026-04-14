import Foundation

struct Configurator {
    static func run() {
        mainMenu()
    }

    // MARK: - Main menu

    private static func mainMenu() {
        // Check slow state once upfront, update only after user action
        var startup = ShellWrapperConfig.isEnabled()
        var login   = LoginItemConfig.isEnabled()

        while true {
            ANSI.clearScreen()
            ANSI.header("Notchify Config")
            print("  1.  Hooks              \(ANSI.dim)(Claude Code triggers)\(ANSI.reset)")
            print("  2.  Sounds             \(ANSI.dim)(per-state audio)\(ANSI.reset)")
            print("  3.  Startup animation  \(startup ? ANSI.on() : ANSI.off())")
            print("  4.  Login item         \(login   ? ANSI.on() : ANSI.off())")
            print()
            print("  \(ANSI.dim)notchify launch  — start the app\(ANSI.reset)")
            print("  \(ANSI.dim)q.  Quit\(ANSI.reset)")
            print()

            switch prompt() {
            case "1": hooksMenu()
            case "2": soundsMenu()
            case "3":
                toggleStartup()
                startup = ShellWrapperConfig.isEnabled()
            case "4":
                toggleLoginItem()
                login = LoginItemConfig.isEnabled()
            case "q", nil: return
            default: break
            }
        }
    }

    // MARK: - Hooks menu

    private static func hooksMenu() {
        while true {
            ANSI.clearScreen()
            let state = HooksConfig.load()

            ANSI.header("Hooks", subtitle: "~/.claude/settings.json")
            print("  1.  working  \(ANSI.dim)(UserPromptSubmit + PreToolUse)\(ANSI.reset)  \(state.working ? ANSI.on() : ANSI.off())")
            print("  2.  done     \(ANSI.dim)(Stop)\(ANSI.reset)                           \(state.done    ? ANSI.on() : ANSI.off())")
            print("  3.  waiting  \(ANSI.dim)(Notification)\(ANSI.reset)                   \(state.waiting ? ANSI.on() : ANSI.off())")
            print()
            print("  \(ANSI.dim)b.  Back\(ANSI.reset)")
            print()

            switch prompt() {
            case "1": HooksConfig.setWorking(!state.working); flash(state.working ? "working hook disabled" : "working hook enabled")
            case "2": HooksConfig.setDone(!state.done);       flash(state.done    ? "done hook disabled"    : "done hook enabled")
            case "3": HooksConfig.setWaiting(!state.waiting); flash(state.waiting ? "waiting hook disabled" : "waiting hook enabled")
            case "b", nil: return
            default: break
            }
        }
    }

    // MARK: - Sounds menu

    private static func soundsMenu() {
        while true {
            ANSI.clearScreen()
            var config = SoundsConfig.load()

            ANSI.header("Sounds", subtitle: "~/.config/notchify/sounds.json")
            let states: [(String, SoundEntry)] = [
                ("start",   config.start),
                ("working", config.working),
                ("waiting", config.waiting),
                ("done",    config.done),
                ("bye",     config.bye),
                ("error",   config.error),
                ("idle",    config.idle),
            ]
            for (i, (name, entry)) in states.enumerated() {
                let label = name.padding(toLength: 8, withPad: " ", startingAt: 0)
                let value = entry == .none
                    ? "\(ANSI.dim)(none)\(ANSI.reset)"
                    : "\(ANSI.green)\(entry.displayString)\(ANSI.reset)"
                print("  \(i + 1).  \(label) \(value)")
            }
            print()
            print("  \(ANSI.dim)b.  Back\(ANSI.reset)")
            print()

            guard let ch = prompt() else { return }
            if ch == "b" { return }
            guard let idx = ch.wholeNumberValue, idx >= 1, idx <= 7 else { continue }

            let (stateName, _) = states[idx - 1]
            if let newEntry = pickSound(for: stateName) {
                switch stateName {
                case "start":   config.start   = newEntry
                case "working": config.working = newEntry
                case "waiting": config.waiting = newEntry
                case "done":    config.done    = newEntry
                case "bye":     config.bye     = newEntry
                case "error":   config.error   = newEntry
                case "idle":    config.idle    = newEntry
                default: break
                }
                config.save()
            }
        }
    }

    private static func pickSound(for state: String) -> SoundEntry? {
        while true {
            ANSI.clearScreen()
            let current = SoundsConfig.load()
            let currentEntry: SoundEntry
            switch state {
            case "start":   currentEntry = current.start
            case "working": currentEntry = current.working
            case "waiting": currentEntry = current.waiting
            case "done":    currentEntry = current.done
            case "bye":     currentEntry = current.bye
            case "error":   currentEntry = current.error
            default:        currentEntry = current.idle
            }

            ANSI.header("Sound for: \(state)", subtitle: "current: \(currentEntry.displayString)")

            let sounds = SoundsConfig.systemSounds
            let cols = 4
            print("  System sounds:")
            for row in stride(from: 0, to: sounds.count, by: cols) {
                let line = (row..<min(row + cols, sounds.count)).map { i in
                    let num = String(i + 1).padding(toLength: 2, withPad: " ", startingAt: 0)
                    return "  \(ANSI.cyan)\(num).\(ANSI.reset) \(sounds[i].padding(toLength: 10, withPad: " ", startingAt: 0))"
                }.joined()
                print(line)
            }
            print()
            print("  \(ANSI.dim)f.  Custom file path\(ANSI.reset)")
            print("  \(ANSI.dim)n.  None (disable sound)\(ANSI.reset)")
            print("  \(ANSI.dim)b.  Back\(ANSI.reset)")
            print()

            // Read full line to support two-digit numbers
            print("\(ANSI.cyan)›\(ANSI.reset) ", terminator: "")
            fflush(stdout)
            guard let input = readLine(strippingNewline: true)?.trimmingCharacters(in: .whitespaces), !input.isEmpty else { return nil }

            let lower = input.lowercased()
            if lower == "b" { return nil }
            if lower == "n" { return .some(.none) }
            if lower == "f" {
                let path = ANSI.readLine(prompt: "File path (~/...): ")
                if !path.isEmpty { return .some(.file(path)) }
                continue
            }
            if let num = Int(input), num >= 1, num <= sounds.count {
                return .some(.system(sounds[num - 1]))
            }
            // Maybe the user typed a sound name directly
            if let match = sounds.first(where: { $0.lowercased() == lower }) {
                return .some(.system(match))
            }
        }
    }

    // MARK: - Toggle helpers

    private static func toggleStartup() {
        let current = ShellWrapperConfig.isEnabled()
        if current { ShellWrapperConfig.disable() } else { ShellWrapperConfig.enable() }
        flash(current ? "Startup animation disabled (restart terminal to apply)" : "Startup animation enabled (restart terminal to apply)")
    }

    private static func toggleLoginItem() {
        let current = LoginItemConfig.isEnabled()
        if current { LoginItemConfig.disable() } else { LoginItemConfig.enable() }
        flash(current ? "Login item removed" : "Login item added")
    }

    // MARK: - Utilities

    private static func prompt() -> Character? {
        print("\(ANSI.cyan)›\(ANSI.reset) ", terminator: "")
        fflush(stdout)
        guard let line = readLine(strippingNewline: true), !line.isEmpty else { return nil }
        return line.lowercased().first
    }

    private static func flash(_ message: String) {
        print()
        print("  \(ANSI.green)✓\(ANSI.reset) \(message)")
        Thread.sleep(forTimeInterval: 0.8)
    }
}
