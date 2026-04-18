import Foundation
import Darwin

struct Configurator {
    static func run() {
        Terminal.enableRaw()
        defer { Terminal.restore() }
        mainMenu()
    }

    // MARK: - Main Menu

    private static func mainMenu() {
        var sel = 0
        let rowCount = 6  // 5 items + Quit

        while true {
            let startup = ShellWrapperConfig.isEnabled()
            let login   = LoginItemConfig.isEnabled()
            renderMain(sel: sel, startup: startup, login: login)

            switch Terminal.readKey() {
            case .up:               sel = (sel - 1 + rowCount) % rowCount
            case .down:             sel = (sel + 1) % rowCount
            case .space, .enter:
                switch sel {
                case 0: displayMenu()
                case 1: soundsMenu()
                case 2: hooksMenu()
                case 3: toggleStartup(startup)
                case 4: toggleLoginItem(login)
                case 5: return
                default: break
                }
            case .char("q"), .char("\u{03}"): return
            default: break
            }
        }
    }

    private static func renderMain(sel: Int, startup: Bool, login: Bool) {
        ANSI.clearScreen()
        ANSI.header("Notchify Config")

        func row(_ i: Int, _ label: String, _ detail: String, _ right: String) {
            let cur = i == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
            let lbl = i == sel ? "\(ANSI.bold)\(label)\(ANSI.reset)" : label
            let det = detail.isEmpty ? "" : "  \(ANSI.dim)\(detail)\(ANSI.reset)"
            print("  \(cur) \(lbl)\(det)  \(right)")
        }

        row(0, "Display",              "screen/position",  "›")
        row(1, "Sounds",              "per-state audio",  "›")
        print()
        row(2, "Hooks",               "Claude Code triggers", "›")
        row(3, "Intro/outro animation","shell wrapper",   startup ? ANSI.on() : ANSI.off())
        print()
        row(4, "Login item",          "",                 login ? ANSI.on() : ANSI.off())
        print()
        let qCur = 5 == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let qLbl = 5 == sel ? "\(ANSI.bold)Quit\(ANSI.reset)" : "Quit"
        print("  \(qCur) \(qLbl)")
        print()
        footer("↑↓ move   enter/space select   q/b quit/back")
        print()
        let d = ANSI.dim; let r = ANSI.reset
        let col = 22
        func cmd(_ c: String, _ desc: String) {
            print("  \(d)\(c.padding(toLength: col, withPad: " ", startingAt: 0))\(desc)\(r)")
        }
        cmd("notchify launch",      "start the app")
        cmd("notchify config",      "this menu")
        cmd("notchify quit",        "quit the app")
        cmd("notchify set working", "· waiting · done · error · start · bye · idle")
        fflush(stdout)
    }

    // MARK: - Hooks Menu

    private static func hooksMenu() {
        var sel = 0
        let rowCount = 4  // 3 toggles + Back

        while true {
            let state = HooksConfig.load()
            renderHooks(sel: sel, state: state)

            switch Terminal.readKey() {
            case .up:              sel = (sel - 1 + rowCount) % rowCount
            case .down:            sel = (sel + 1) % rowCount
            case .space, .enter:
                switch sel {
                case 0: HooksConfig.setWorking(!state.working)
                case 1: HooksConfig.setDone(!state.done)
                case 2: HooksConfig.setWaiting(!state.waiting)
                case 3: return
                default: break
                }
            case .char("b"), .char("q"), .char("\u{03}"): return
            default: break
            }
        }
    }

    private static func renderHooks(sel: Int, state: HookState) {
        ANSI.clearScreen()
        ANSI.header("Hooks", subtitle: "~/.claude/settings.json")

        let rows: [(String, String, Bool)] = [
            ("working", "UserPromptSubmit/PostToolUse", state.working),
            ("done",    "Stop",                           state.done),
            ("waiting", "Notification",                   state.waiting),
        ]
        for (i, (name, detail, on)) in rows.enumerated() {
            let cur = i == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
            let pad = name.padding(toLength: 8, withPad: " ", startingAt: 0)
            let lbl = i == sel ? "\(ANSI.bold)\(pad)\(ANSI.reset)" : pad
            print("  \(cur) \(lbl)  \(ANSI.dim)\(detail)\(ANSI.reset)  \(on ? ANSI.on() : ANSI.off())")
        }
        print()
        let bCur = 3 == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let bLbl = 3 == sel ? "\(ANSI.bold)Back\(ANSI.reset)" : "Back"
        print("  \(bCur) \(bLbl)")
        print()
        footer("↑↓ move   enter/space toggle   q/b quit/back")
    }

    // MARK: - Sounds Menu

    private static let soundStates = ["start", "working", "waiting", "done", "bye", "error", "idle"]

    private static func soundsMenu() {
        var sel = 0
        let rowCount = 1 + soundStates.count + 1  // volume + states + Back

        while true {
            var config = SoundsConfig.load()
            renderSounds(sel: sel, config: config)
            let key = Terminal.readKey()

            switch key {
            case .up:   sel = (sel - 1 + rowCount) % rowCount
            case .down: sel = (sel + 1) % rowCount

            case .left where sel == 0:
                let v = max(0, Int((config.volume * 100).rounded()) - 5)
                config.volume = Float(v) / 100.0
                config.save()

            case .right where sel == 0:
                let v = min(100, Int((config.volume * 100).rounded()) + 5)
                config.volume = Float(v) / 100.0
                config.save()

            case .space where sel > 0, .enter where sel > 0:
                let backRow = 1 + soundStates.count
                if sel == backRow { return }
                let state = soundStates[sel - 1]
                if let entry = pickSound(for: state, config: config) {
                    setSoundEntry(entry, state: state, config: &config)
                    config.save()
                }

            case .char("b"), .char("q"), .char("\u{03}"): return
            default: break
            }
        }
    }

    private static func renderSounds(sel: Int, config: SoundsConfig) {
        ANSI.clearScreen()
        ANSI.header("Sounds", subtitle: "~/.config/notchify/sounds.json")

        let volPct = Int((config.volume * 100).rounded())
        let cur0 = sel == 0 ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let lbl0 = sel == 0 ? "\(ANSI.bold)Volume  \(ANSI.reset)" : "Volume  "
        let hint0 = sel == 0 ? "  \(ANSI.dim)← →\(ANSI.reset)" : ""
        print("  \(cur0) \(lbl0)  \(ANSI.cyan)\(volPct)%\(ANSI.reset)\(hint0)")
        print()

        let entries: [SoundEntry] = [
            config.start, config.working, config.waiting,
            config.done, config.bye, config.error, config.idle
        ]
        for (i, (name, entry)) in zip(soundStates, entries).enumerated() {
            let row = i + 1
            let cur = row == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
            let pad = name.padding(toLength: 8, withPad: " ", startingAt: 0)
            let lbl = row == sel ? "\(ANSI.bold)\(pad)\(ANSI.reset)" : pad
            let val = entry == .none
                ? "\(ANSI.dim)(none)\(ANSI.reset)"
                : "\(ANSI.green)\(entry.displayString)\(ANSI.reset)"
            print("  \(cur) \(lbl)  \(val)")
        }
        print()
        let bRow = 1 + soundStates.count
        let bCur = bRow == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let bLbl = bRow == sel ? "\(ANSI.bold)Back\(ANSI.reset)" : "Back"
        print("  \(bCur) \(bLbl)")
        print()
        footer("↑↓ move   ←→ volume   enter/space pick   q/b quit/back")
    }

    private static func setSoundEntry(_ entry: SoundEntry, state: String, config: inout SoundsConfig) {
        switch state {
        case "start":   config.start   = entry
        case "working": config.working = entry
        case "waiting": config.waiting = entry
        case "done":    config.done    = entry
        case "bye":     config.bye     = entry
        case "error":   config.error   = entry
        case "idle":    config.idle    = entry
        default: break
        }
    }

    private static func currentSoundEntry(_ state: String, config: SoundsConfig) -> SoundEntry {
        switch state {
        case "start":   return config.start
        case "working": return config.working
        case "waiting": return config.waiting
        case "done":    return config.done
        case "bye":     return config.bye
        case "error":   return config.error
        default:        return config.idle
        }
    }

    // MARK: - Sound Picker

    private static func pickSound(for state: String, config: SoundsConfig) -> SoundEntry? {
        let sounds = SoundsConfig.systemSounds
        let current = currentSoundEntry(state, config: config)
        var sel: Int
        if current == .none {
            sel = 0
        } else if case .system(let name) = current, let i = sounds.firstIndex(of: name) {
            sel = i + 1
        } else {
            sel = sounds.count + 1
        }
        let rowCount = 1 + sounds.count + 2  // none + system sounds + custom + Back

        while true {
            renderPickSound(sel: sel, state: state, current: current, sounds: sounds)

            switch Terminal.readKey() {
            case .up:   sel = (sel - 1 + rowCount) % rowCount
            case .down: sel = (sel + 1) % rowCount
            case .space, .enter:
                if sel == 0 { return SoundEntry.none }
                if sel <= sounds.count { return .system(sounds[sel - 1]) }
                if sel == sounds.count + 2 { return nil }
                // Custom file — leave raw mode for text input
                Terminal.restore()
                ANSI.clearScreen()
                print()
                print("  \(ANSI.dim)File path (~/...): \(ANSI.reset)", terminator: "")
                fflush(stdout)
                let path = readLine(strippingNewline: true) ?? ""
                Terminal.enableRaw()
                if !path.isEmpty { return .file(path) }
            case .char("b"), .char("q"), .char("\u{03}"): return nil
            default: break
            }
        }
    }

    private static func renderPickSound(sel: Int, state: String, current: SoundEntry, sounds: [String]) {
        ANSI.clearScreen()
        ANSI.header("Sound · \(state)", subtitle: "current: \(current.displayString)")

        func row(_ i: Int, _ label: String) {
            let cur = i == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
            let lbl = i == sel ? "\(ANSI.bold)\(label)\(ANSI.reset)" : label
            print("  \(cur) \(lbl)")
        }

        row(0, "(none)")
        for (i, name) in sounds.enumerated() { row(i + 1, name) }
        row(sounds.count + 1, "Custom file...")

        print()
        let bCur = sel == sounds.count + 2 ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let bLbl = sel == sounds.count + 2 ? "\(ANSI.bold)Back\(ANSI.reset)" : "Back"
        print("  \(bCur) \(bLbl)")
        print()
        footer("↑↓ move   enter/space select   q/b quit/back")
    }

    // MARK: - Toggle Helpers

    private static func toggleStartup(_ current: Bool) {
        if current { ShellWrapperConfig.disable() } else { ShellWrapperConfig.enable() }
    }

    private static func toggleLoginItem(_ current: Bool) {
        if current {
            LoginItemConfig.disable()
        } else {
            let ok = LoginItemConfig.enable()
            if !ok {
                ANSI.clearScreen()
                print()
                print("  \(ANSI.yellow)⚠\(ANSI.reset)  Could not write ~/Library/LaunchAgents/")
                Thread.sleep(forTimeInterval: 2.0)
            }
        }
    }

    // MARK: - Display Menu

    private static func displayMenu() {
        var sel = 0

        while true {
            var settings = DisplayConfig.load()
            let screens  = DisplayConfig.screenList()
            let n = screens.count
            let rowCount = n + 1 + 4 + 1  // screens + auto + h + v + dir + reset + Back

            renderDisplay(sel: sel, settings: settings, screens: screens)
            let key = Terminal.readKey()

            switch key {
            case .up:   sel = (sel - 1 + rowCount) % rowCount
            case .down: sel = (sel + 1) % rowCount

            case .left:
                if sel == n + 1 {
                    settings.horizontalOffset -= 1
                    DisplayConfig.save(settings); sendToSocket("reposition")
                } else if sel == n + 2 {
                    settings.verticalOffset -= 1
                    DisplayConfig.save(settings); sendToSocket("reposition")
                }

            case .right:
                if sel == n + 1 {
                    settings.horizontalOffset += 1
                    DisplayConfig.save(settings); sendToSocket("reposition")
                } else if sel == n + 2 {
                    settings.verticalOffset += 1
                    DisplayConfig.save(settings); sendToSocket("reposition")
                }

            case .space, .enter:
                if sel < n {
                    settings.screenIndex = sel
                    DisplayConfig.save(settings); sendToSocket("reposition")
                } else if sel == n {
                    settings.screenIndex = -1
                    DisplayConfig.save(settings); sendToSocket("reposition")
                } else if sel == n + 3 {
                    settings.mascotDirection = settings.mascotDirection == .right ? .left : .right
                    DisplayConfig.save(settings); sendToSocket("reposition")
                } else if sel == n + 4 {
                    settings.horizontalOffset = 0
                    settings.verticalOffset   = 0
                    DisplayConfig.save(settings); sendToSocket("reposition")
                } else if sel == n + 5 {
                    return
                }

            case .char("b"), .char("q"), .char("\u{03}"): return
            default: break
            }
        }
    }

    private static func renderDisplay(
        sel: Int,
        settings: DisplaySettings,
        screens: [(index: Int, name: String, hasNotch: Bool, isCurrent: Bool)]
    ) {
        ANSI.clearScreen()
        ANSI.header("Display", subtitle: "~/.config/notchify/display.json")

        let n = screens.count

        print("  \(ANSI.dim)Screen\(ANSI.reset)")
        for (i, s) in screens.enumerated() {
            let cur   = i == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
            let lbl   = i == sel ? "\(ANSI.bold)\(s.name)\(ANSI.reset)" : s.name
            let notch = s.hasNotch ? " \(ANSI.dim)[notch]\(ANSI.reset)" : ""
            let mark  = settings.screenIndex == i ? " \(ANSI.green)✓\(ANSI.reset)" : ""
            print("  \(cur) \(lbl)\(notch)\(mark)")
        }
        let autoCur  = sel == n ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let autoLbl  = sel == n ? "\(ANSI.bold)Auto – notch screen\(ANSI.reset)" : "Auto – notch screen"
        let autoMark = settings.screenIndex == -1 ? " \(ANSI.green)✓\(ANSI.reset)" : ""
        print("  \(autoCur) \(autoLbl)\(autoMark)")
        print()

        func valueRow(_ i: Int, _ label: String, _ value: String, _ hint: String) {
            let cur = i == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
            let pad = label.padding(toLength: 12, withPad: " ", startingAt: 0)
            let lbl = i == sel ? "\(ANSI.bold)\(pad)\(ANSI.reset)" : pad
            let h   = i == sel ? "  \(ANSI.dim)\(hint)\(ANSI.reset)" : ""
            print("  \(cur) \(lbl)  \(ANSI.cyan)\(value)\(ANSI.reset)\(h)")
        }

        let arrow = settings.mascotDirection == .right ? "right →" : "← left"
        valueRow(n + 1, "Horizontal", "\(settings.horizontalOffset) pt",  "← →")
        valueRow(n + 2, "Vertical",   "\(settings.verticalOffset) pt",    "← →")
        valueRow(n + 3, "Direction",  arrow,                              "space toggle")

        let rCur = sel == n + 4 ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let rLbl = sel == n + 4 ? "\(ANSI.bold)Reset offsets\(ANSI.reset)" : "Reset offsets"
        print("  \(rCur) \(rLbl)  \(ANSI.dim)(h=0 v=0)\(ANSI.reset)")

        print()
        let bCur = sel == n + 5 ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let bLbl = sel == n + 5 ? "\(ANSI.bold)Back\(ANSI.reset)" : "Back"
        print("  \(bCur) \(bLbl)")
        print()
        footer("↑↓ move   ←→ adjust   enter/space select   q/b quit/back")
    }

    // MARK: - Shared

    private static func footer(_ help: String) {
        let bar = String(repeating: "─", count: 46)
        print("\(ANSI.cyan)\(bar)\(ANSI.reset)")
        print("  \(ANSI.dim)\(help)\(ANSI.reset)")
        fflush(stdout)
    }
}
