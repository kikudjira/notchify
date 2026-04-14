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
            print("  5.  Display            \(ANSI.dim)(screen & position)\(ANSI.reset)")
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
            case "5": displayMenu()
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
        if current {
            LoginItemConfig.disable()
            flash("Login item removed")
        } else {
            let ok = LoginItemConfig.enable()
            if ok {
                flash("Login item added — will start at next login")
            } else {
                print()
                print("  \(ANSI.yellow)⚠\(ANSI.reset)  Could not write ~/Library/LaunchAgents/")
                Thread.sleep(forTimeInterval: 2.0)
            }
        }
    }

    // MARK: - Display menu

    private static func displayMenu() {
        while true {
            ANSI.clearScreen()
            var settings = DisplayConfig.load()
            let screens  = DisplayConfig.screenList()

            ANSI.header("Display", subtitle: "~/.config/notchify/display.json")

            print("  Screens:")
            for s in screens {
                let notch  = s.hasNotch ? " \(ANSI.dim)[notch]\(ANSI.reset)" : ""
                let active = s.isCurrent ? " \(ANSI.green)←\(ANSI.reset)" : ""
                print("  \(s.index + 1).  \(s.name)\(notch)\(active)")
            }
            let autoMark = settings.screenIndex == -1 ? " \(ANSI.green)←\(ANSI.reset)" : ""
            print("  a.  Auto (notch screen)\(autoMark)")
            print()
            print("  Horizontal  \(ANSI.cyan)\(settings.horizontalOffset) pt\(ANSI.reset)  \(ANSI.dim)h<N>  e.g. h-20  h40\(ANSI.reset)")
            print("  Vertical    \(ANSI.cyan)\(settings.verticalOffset) pt\(ANSI.reset)  \(ANSI.dim)v<N>  e.g. v8   v-4\(ANSI.reset)")
            print("  0   Reset both offsets")
            print()
            print("  \(ANSI.dim)b.  Back\(ANSI.reset)")
            print()

            print("\(ANSI.cyan)›\(ANSI.reset) ", terminator: "")
            fflush(stdout)
            guard let input = readLine(strippingNewline: true)?.trimmingCharacters(in: .whitespaces),
                  !input.isEmpty else { continue }
            let lower = input.lowercased()

            if lower == "b" { return }
            if lower == "a" {
                settings.screenIndex = -1
                DisplayConfig.save(settings); sendReposition()
                flash("Screen: auto")
                continue
            }
            if lower == "0" {
                settings.horizontalOffset = 0
                settings.verticalOffset   = 0
                DisplayConfig.save(settings); sendReposition()
                flash("Offsets reset")
                continue
            }
            // screen selection: single number within screen list range
            if let n = Int(lower), n >= 1, n <= screens.count {
                settings.screenIndex = n - 1
                DisplayConfig.save(settings); sendReposition()
                flash("Screen: \(screens[n - 1].name)"); continue
            }
            // h<N>  — set exact horizontal offset (e.g. h-20, h40)
            if lower.hasPrefix("h"), let n = Int(lower.dropFirst()) {
                settings.horizontalOffset = n
                DisplayConfig.save(settings); sendReposition()
                flash("Horizontal: \(n) pt"); continue
            }
            // v<N>  — set exact vertical offset (e.g. v8, v-4)
            if lower.hasPrefix("v"), let n = Int(lower.dropFirst()) {
                settings.verticalOffset = n
                DisplayConfig.save(settings); sendReposition()
                flash("Vertical: \(n) pt"); continue
            }
        }
    }

    private static func sendReposition() {
        // Tell the running app to re-read config and reposition immediately.
        // Reuse the socket helper from main.swift via a local inline send.
        let socketPath = "/tmp/notchify.sock"
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return }
        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        socketPath.withCString { cStr in
            withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
                UnsafeMutableRawPointer(ptr).copyMemory(from: cStr, byteCount: strlen(cStr) + 1)
            }
        }
        let ok = withUnsafePointer(to: addr) { p in
            p.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard ok == 0 else { close(fd); return }
        "reposition".withCString { _ = Darwin.write(fd, $0, 10) }
        close(fd)
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
