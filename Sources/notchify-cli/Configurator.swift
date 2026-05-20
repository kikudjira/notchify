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
        let rowCount = 5  // 4 items + Quit

        while true {
            let login = LoginItemConfig.isEnabled()
            renderMain(sel: sel, login: login)

            switch Terminal.readKey() {
            case .up:               sel = (sel - 1 + rowCount) % rowCount
            case .down:             sel = (sel + 1) % rowCount
            case .space, .enter:
                switch sel {
                case 0: displayMenu()
                case 1: soundsMenu()
                case 2: integrationsMenu()
                case 3: toggleLoginItem(login)
                case 4: return
                default: break
                }
            case .char("q"), .char("\u{03}"): return
            default: break
            }
        }
    }

    private static func renderMain(sel: Int, login: Bool) {
        ANSI.clearScreen()
        ANSI.header("Notchify Config")

        func row(_ i: Int, _ label: String, _ detail: String, _ right: String) {
            let cur = i == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
            let lbl = i == sel ? "\(ANSI.bold)\(label)\(ANSI.reset)" : label
            let det = detail.isEmpty ? "" : "  \(ANSI.dim)\(detail)\(ANSI.reset)"
            print("  \(cur) \(lbl)\(det)  \(right)")
        }

        row(0, "Display",      "screen/position",   "›")
        row(1, "Sounds",       "per-state audio",   "›")
        print()
        row(2, "Integrations", "hooks + shell wrapper", "›")
        print()
        row(3, "Login item",   "",                  login ? ANSI.on() : ANSI.off())
        print()
        let qCur = 4 == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let qLbl = 4 == sel ? "\(ANSI.bold)Quit\(ANSI.reset)" : "Quit"
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
        cmd("notchify clear",       "clear stuck animations")
        cmd("notchify set working", "· waiting · done · error · start · bye · idle")
        fflush(stdout)
    }

    // MARK: - Integrations Menu

    private static func integrationsMenu() {
        var sel = 0
        let rowCount = 7  // targets + master + 3 hooks + intro/outro + Back

        while true {
            let state   = HooksConfig.load()
            let wrapper = ShellWrapperConfig.isEnabled()
            let targets = HookTargetsConfig.load()
            let master  = state.working && state.done && state.waiting && wrapper
            renderIntegrations(sel: sel, state: state, wrapper: wrapper, master: master, targets: targets)

            switch Terminal.readKey() {
            case .up:              sel = (sel - 1 + rowCount) % rowCount
            case .down:            sel = (sel + 1) % rowCount
            case .space, .enter:
                switch sel {
                case 0: pickHookTargets()
                case 1: toggleMaster(currentlyOn: master)
                case 2: HooksConfig.setWorking(!state.working)
                case 3: HooksConfig.setDone(!state.done)
                case 4: HooksConfig.setWaiting(!state.waiting)
                case 5:
                    if wrapper { ShellWrapperConfig.disable() }
                    else       { ShellWrapperConfig.enable()  }
                case 6: return
                default: break
                }
            case .char("b"), .char("q"), .char("\u{03}"): return
            default: break
            }
        }
    }

    private static func toggleMaster(currentlyOn: Bool) {
        let enable = !currentlyOn
        HooksConfig.setWorking(enable)
        HooksConfig.setDone(enable)
        HooksConfig.setWaiting(enable)
        if enable { ShellWrapperConfig.enable() }
        else      { ShellWrapperConfig.disable() }
    }

    private static func renderIntegrations(
        sel: Int,
        state: HookState,
        wrapper: Bool,
        master: Bool,
        targets: [URL]
    ) {
        ANSI.clearScreen()
        ANSI.header("Integrations", subtitle: targetsSubtitle(targets))

        // Row 0 — Config targets
        let tCur = 0 == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let tLbl = 0 == sel ? "\(ANSI.bold)Config targets\(ANSI.reset)" : "Config targets"
        let tCount = "\(ANSI.cyan)\(targets.count)\(ANSI.reset) selected"
        print("  \(tCur) \(tLbl)  \(tCount)  \(ANSI.dim)›\(ANSI.reset)")
        print()

        // Row 1 — master toggle
        let mCur = 1 == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let mLbl = 1 == sel ? "\(ANSI.bold)Integrations\(ANSI.reset)" : "Integrations"
        print("  \(mCur) \(mLbl)  \(master ? ANSI.on() : ANSI.off())  \(ANSI.dim)master — all of below\(ANSI.reset)")
        print()

        // Animation hooks group
        print("  \(ANSI.dim)Animation hooks  ·  Claude Code triggers\(ANSI.reset)")
        let hookRows: [(idx: Int, name: String, detail: String, on: Bool)] = [
            (2, "working", "UserPromptSubmit/PostToolUse",   state.working),
            (3, "done",    "Stop",                           state.done),
            (4, "waiting", "Notification/PermissionRequest", state.waiting),
        ]
        for r in hookRows {
            let cur = r.idx == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
            let pad = r.name.padding(toLength: 8, withPad: " ", startingAt: 0)
            let lbl = r.idx == sel ? "\(ANSI.bold)\(pad)\(ANSI.reset)" : pad
            print("  \(cur) \(lbl)  \(ANSI.dim)\(r.detail)\(ANSI.reset)  \(r.on ? ANSI.on() : ANSI.off())")
        }
        print()

        // Shell wrapper group
        print("  \(ANSI.dim)Shell wrapper  ·  ~/.zshrc, ~/.bashrc\(ANSI.reset)")
        let wCur = 5 == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let wLbl = 5 == sel ? "\(ANSI.bold)intro/outro animation\(ANSI.reset)" : "intro/outro animation"
        print("  \(wCur) \(wLbl)  \(wrapper ? ANSI.on() : ANSI.off())")
        print()

        // Back
        let bCur = 6 == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let bLbl = 6 == sel ? "\(ANSI.bold)Back\(ANSI.reset)" : "Back"
        print("  \(bCur) \(bLbl)")
        print()
        footer("↑↓ move   enter/space toggle   q/b quit/back")
    }

    private static func targetsSubtitle(_ targets: [URL]) -> String {
        if targets.isEmpty { return "no targets" }
        if targets.count == 1 { return "\(displayPath(targets[0]))/settings.json" }
        if targets.count <= 3 {
            return targets.map { displayPath($0) }.joined(separator: ", ")
        }
        return "\(targets.count) targets"
    }

    // MARK: - Hook Targets Picker

    private static func pickHookTargets() {
        var selected = Set(HookTargetsConfig.load().map { $0.standardizedFileURL.path })
        var candidates = HookTargetsConfig.detectCandidates().map { $0.standardizedFileURL }

        // Include any currently-selected paths that aren't in the autodetect list.
        for path in selected where !candidates.contains(where: { $0.path == path }) {
            candidates.append(URL(fileURLWithPath: path))
        }

        var cursor = 0

        while true {
            let rowCount = candidates.count + 3  // candidates + "Add custom..." + Save + Cancel
            renderPickTargets(cursor: cursor, candidates: candidates, selected: selected)

            switch Terminal.readKey() {
            case .up:   cursor = (cursor - 1 + rowCount) % rowCount
            case .down: cursor = (cursor + 1) % rowCount
            case .space, .enter:
                if cursor < candidates.count {
                    let path = candidates[cursor].path
                    if selected.contains(path) {
                        selected.remove(path)
                    } else {
                        selected.insert(path)
                    }
                } else if cursor == candidates.count {
                    // Add custom path
                    Terminal.restore()
                    ANSI.clearScreen()
                    print()
                    print("  \(ANSI.dim)Claude config dir (~/...): \(ANSI.reset)", terminator: "")
                    fflush(stdout)
                    let raw = readLine(strippingNewline: true) ?? ""
                    Terminal.enableRaw()
                    let trimmed = raw.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        let url = HookTargetsConfig.expand(trimmed).standardizedFileURL
                        if !candidates.contains(where: { $0.path == url.path }) {
                            candidates.append(url)
                        }
                        selected.insert(url.path)
                    }
                } else if cursor == candidates.count + 1 {
                    // Save
                    let urls = candidates.filter { selected.contains($0.path) }
                    let final = urls.isEmpty ? [HookTargetsConfig.defaultTarget] : urls
                    HookTargetsConfig.save(final)
                    HooksConfig.reinstall()
                    return
                } else if cursor == candidates.count + 2 {
                    // Cancel
                    return
                }
            case .char("a"):
                cursor = candidates.count  // jump to "Add custom..."
            case .char("b"), .char("q"), .char("\u{03}"): return
            default: break
            }
        }
    }

    private static func renderPickTargets(cursor: Int, candidates: [URL], selected: Set<String>) {
        ANSI.clearScreen()
        ANSI.header("Hook targets", subtitle: "~/.config/notchify/hook_targets.json")

        for (i, url) in candidates.enumerated() {
            let cur  = i == cursor ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
            let mark = selected.contains(url.path)
                ? "\(ANSI.green)[x]\(ANSI.reset)"
                : "\(ANSI.dim)[ ]\(ANSI.reset)"
            let path = displayPath(url)
            let lbl  = i == cursor ? "\(ANSI.bold)\(path)\(ANSI.reset)" : path
            print("  \(cur) \(mark) \(lbl)")
        }
        print()

        let aRow = candidates.count
        let aCur = aRow == cursor ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let aLbl = aRow == cursor ? "\(ANSI.bold)Add custom path...\(ANSI.reset)" : "Add custom path..."
        print("  \(aCur) \(aLbl)")

        let sRow = candidates.count + 1
        let sCur = sRow == cursor ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let sLbl = sRow == cursor ? "\(ANSI.bold)Save\(ANSI.reset)" : "Save"
        print("  \(sCur) \(sLbl)  \(ANSI.dim)apply selection and reinstall hooks\(ANSI.reset)")

        let cRow = candidates.count + 2
        let cCur = cRow == cursor ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let cLbl = cRow == cursor ? "\(ANSI.bold)Cancel\(ANSI.reset)" : "Cancel"
        print("  \(cCur) \(cLbl)")
        print()
        footer("↑↓ move   space toggle   a add   enter select   q/b cancel")
    }

    private static func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.standardizedFileURL.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
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

    private enum ProfileKey { case notch, external }

    /// Row indices inside displayMenu, computed from screen count `n`.
    /// Layout: screens[0..n) → auto(n) → notch h/v/dir/reset(n+1..n+4) → external h/v/dir/reset(n+5..n+8) → back(n+9)
    private static func displayMenu() {
        var sel = 0

        while true {
            var settings = DisplayConfig.load()
            let screens  = DisplayConfig.screenList()
            let n = screens.count
            let rowCount = n + 10

            renderDisplay(sel: sel, settings: settings, screens: screens)
            let key = Terminal.readKey()

            switch key {
            case .up:   sel = (sel - 1 + rowCount) % rowCount
            case .down: sel = (sel + 1) % rowCount

            case .left:
                handleArrow(sel: sel, n: n, delta: -1, settings: &settings)

            case .right:
                handleArrow(sel: sel, n: n, delta: +1, settings: &settings)

            case .space, .enter:
                if sel < n {
                    settings.screenIndex = sel
                    DisplayConfig.save(settings); sendToSocket("reposition")
                } else if sel == n {
                    settings.screenIndex = -1
                    DisplayConfig.save(settings); sendToSocket("reposition")
                } else if sel == n + 3 {
                    settings.notch.mascotDirection = nextDirection(settings.notch.mascotDirection, profile: .notch)
                    coerceNotch(&settings)
                    DisplayConfig.save(settings); sendToSocket("reposition")
                } else if sel == n + 4 {
                    settings.notch.horizontalOffset = 0
                    settings.notch.verticalOffset   = 0
                    DisplayConfig.save(settings); sendToSocket("reposition")
                } else if sel == n + 7 {
                    settings.external.mascotDirection = nextDirection(settings.external.mascotDirection, profile: .external)
                    DisplayConfig.save(settings); sendToSocket("reposition")
                } else if sel == n + 8 {
                    settings.external.horizontalOffset = 0
                    settings.external.verticalOffset   = 0
                    DisplayConfig.save(settings); sendToSocket("reposition")
                } else if sel == n + 9 {
                    return
                }

            case .char("b"), .char("q"), .char("\u{03}"): return
            default: break
            }
        }
    }

    private static func handleArrow(sel: Int, n: Int, delta: Int, settings: inout DisplaySettings) {
        switch sel {
        case n + 1: settings.notch.horizontalOffset    += delta
        case n + 2: settings.notch.verticalOffset      += delta
        case n + 5: settings.external.horizontalOffset += delta
        case n + 6: settings.external.verticalOffset   += delta
        default: return
        }
        DisplayConfig.save(settings); sendToSocket("reposition")
    }

    private static func coerceNotch(_ settings: inout DisplaySettings) {
        if settings.notch.mascotDirection == .center {
            settings.notch.mascotDirection = .right
        }
    }

    private static func nextDirection(_ current: MascotDirection, profile: ProfileKey) -> MascotDirection {
        switch profile {
        case .notch:
            return current == .right ? .left : .right
        case .external:
            switch current {
            case .right:  return .left
            case .left:   return .center
            case .center: return .right
            }
        }
    }

    private static func directionLabel(_ d: MascotDirection) -> String {
        switch d {
        case .right:  return "right →"
        case .left:   return "← left"
        case .center: return "• center"
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

        renderProfile(
            title: "Notch profile",
            subtitle: "applied on screen with notch",
            profile: settings.notch,
            sel: sel,
            baseRow: n + 1,
            allowCenter: false
        )

        renderProfile(
            title: "External profile",
            subtitle: "applied on screen without notch",
            profile: settings.external,
            sel: sel,
            baseRow: n + 5,
            allowCenter: true
        )

        let bCur = sel == n + 9 ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let bLbl = sel == n + 9 ? "\(ANSI.bold)Back\(ANSI.reset)" : "Back"
        print("  \(bCur) \(bLbl)")
        print()
        footer("↑↓ move   ←→ adjust   enter/space select   q/b quit/back")
    }

    private static func renderProfile(
        title: String,
        subtitle: String,
        profile: ProfileSettings,
        sel: Int,
        baseRow: Int,
        allowCenter: Bool
    ) {
        print("  \(ANSI.dim)\(title)  ·  \(subtitle)\(ANSI.reset)")

        func valueRow(_ i: Int, _ label: String, _ value: String, _ hint: String) {
            let cur = i == sel ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
            let pad = label.padding(toLength: 12, withPad: " ", startingAt: 0)
            let lbl = i == sel ? "\(ANSI.bold)\(pad)\(ANSI.reset)" : pad
            let h   = i == sel ? "  \(ANSI.dim)\(hint)\(ANSI.reset)" : ""
            print("  \(cur) \(lbl)  \(ANSI.cyan)\(value)\(ANSI.reset)\(h)")
        }

        let dirHint = allowCenter ? "space cycles right→left→center" : "space toggles right↔left"
        valueRow(baseRow,     "Horizontal", "\(profile.horizontalOffset) pt",        "← →")
        valueRow(baseRow + 1, "Vertical",   "\(profile.verticalOffset) pt",          "← →")
        valueRow(baseRow + 2, "Direction",  directionLabel(profile.mascotDirection), dirHint)

        let rCur = sel == baseRow + 3 ? "\(ANSI.cyan)▸\(ANSI.reset)" : " "
        let rLbl = sel == baseRow + 3 ? "\(ANSI.bold)Reset offsets\(ANSI.reset)" : "Reset offsets"
        print("  \(rCur) \(rLbl)  \(ANSI.dim)(h=0 v=0)\(ANSI.reset)")
        print()
    }

    // MARK: - Shared

    private static func footer(_ help: String) {
        let bar = String(repeating: "─", count: 46)
        print("\(ANSI.cyan)\(bar)\(ANSI.reset)")
        print("  \(ANSI.dim)\(help)\(ANSI.reset)")
        fflush(stdout)
    }
}
