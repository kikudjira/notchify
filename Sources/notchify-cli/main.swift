import Foundation
import Darwin

let rawArgs = CommandLine.arguments

/// Extracts `--config-dir <path>` occurrences (repeatable). Returns the remaining
/// argv and the override list (nil = no flag given, use configured targets).
func parseConfigDirFlag(_ args: [String]) -> (rest: [String], override: [URL]?) {
    var rest: [String] = []
    var dirs: [URL] = []
    var i = 0
    while i < args.count {
        if args[i] == "--config-dir", i + 1 < args.count {
            dirs.append(HookTargetsConfig.expand(args[i + 1]))
            i += 2
        } else {
            rest.append(args[i])
            i += 1
        }
    }
    return (rest, dirs.isEmpty ? nil : dirs)
}

let (args, configDirOverride) = parseConfigDirFlag(rawArgs)
let command = args.count >= 2 ? args[1] : ""

// ---- help ----
if command == "help" || command == "--help" || command == "-h" || command.isEmpty {
    print("""
    notchify — pixel mascot for Claude Code in the MacBook notch area

    USAGE
      notchify set <status>          Send a status to the running app
      notchify clear                 Clear all stuck animations (keeps app running)
      notchify launch                Launch the app
      notchify quit                  Quit the running app
      notchify config                Interactive configurator (hooks, sounds, startup)
      notchify hooks targets list    List Claude config dirs receiving hooks
      notchify hooks targets add     Add a config dir (e.g. ~/.claude-work)
      notchify hooks targets remove  Remove a config dir
      notchify hooks reinstall       Re-apply current hook state to every target
      notchify help                  Show this help

    FLAGS
      --config-dir <path>   Override hook target for this invocation (repeatable).
                            Works with: launch, hooks reinstall

    STATUSES
      working   Claude is using a tool
      waiting   Claude needs your attention
      done      Claude finished a turn
      error     Something went wrong
      start     Show startup animation
      bye       Show goodbye animation
      idle      Hide the mascot

    EXAMPLES
      notchify set working
      notchify launch
      notchify hooks targets add ~/.claude-work
      CLAUDE_CONFIG_DIR=~/.claude-work claude
    """)
    exit(0)
}

// ---- config ----
if command == "config" {
    Configurator.run()
    exit(0)
}

// ---- quit ----
if command == "quit" {
    sendToSocket("quit")
    exit(0)
}

// ---- clear ----
if command == "clear" {
    sendToSocket("clear")
    exit(0)
}

// ---- hooks ----
if command == "hooks" {
    let sub = args.count >= 3 ? args[2] : ""
    switch sub {
    case "targets":
        let action = args.count >= 4 ? args[3] : "list"
        switch action {
        case "list":
            for url in HookTargetsConfig.load() { print(url.path) }
        case "add":
            guard args.count >= 5 else {
                fputs("Usage: notchify hooks targets add <path>\n", stderr); exit(1)
            }
            HookTargetsConfig.add(HookTargetsConfig.expand(args[4]))
            HooksConfig.reinstall()
        case "remove":
            guard args.count >= 5 else {
                fputs("Usage: notchify hooks targets remove <path>\n", stderr); exit(1)
            }
            HookTargetsConfig.remove(HookTargetsConfig.expand(args[4]))
        default:
            fputs("Usage: notchify hooks targets [list|add <path>|remove <path>]\n", stderr); exit(1)
        }
    case "reinstall":
        HooksConfig.reinstall(override: configDirOverride)
    default:
        fputs("Usage: notchify hooks [targets ...|reinstall] [--config-dir <path>]\n", stderr); exit(1)
    }
    exit(0)
}

// ---- launch ----
if command == "launch" {
    // First-run hint for users with split Claude config dirs (~/.claude-work etc.)
    let fm = FileManager.default
    let hookTargetsExists = fm.fileExists(atPath: HookTargetsConfig.configURL.path)
    if !hookTargetsExists && configDirOverride == nil {
        let candidates = HookTargetsConfig.detectCandidates()
        if candidates.count > 1 {
            let names = candidates.map { $0.lastPathComponent }.joined(separator: ", ")
            fputs("notchify: detected multiple Claude config dirs (\(names)).\n", stderr)
            fputs("         Run `notchify config` → Hooks → Config targets to enable animations in all of them.\n", stderr)
        }
    }

    // Migrate old hooks/wrapper before checking state
    HooksConfig.migrate(override: configDirOverride)
    ShellWrapperConfig.migrateIfNeeded()
    // Auto-enable all hooks and startup animation on first launch if none are configured yet
    let hookState = HooksConfig.load(override: configDirOverride)
    if !hookState.working { HooksConfig.setWorking(true, override: configDirOverride) }
    if !hookState.done    { HooksConfig.setDone(true,    override: configDirOverride) }
    if !hookState.waiting { HooksConfig.setWaiting(true, override: configDirOverride) }

    let appPath = resolveAppPath()
    guard appPath.hasSuffix(".app"), FileManager.default.fileExists(atPath: appPath) else {
        fputs("notchify launch: Notchify.app not found (resolved: \(appPath))\n", stderr)
        fputs("Hint: re-install or run 'brew reinstall notchify'\n", stderr)
        exit(1)
    }
    // Strip quarantine so Launch Services won't block the unsigned app
    let xattr = Process()
    xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
    xattr.arguments = ["-dr", "com.apple.quarantine", appPath]
    xattr.standardOutput = FileHandle.nullDevice
    xattr.standardError = FileHandle.nullDevice
    try? xattr.run()
    xattr.waitUntilExit()
    // Open via Launch Services — required for proper AppKit/window server init
    let openProc = Process()
    openProc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    openProc.arguments = [appPath]
    do {
        try openProc.run()
        openProc.waitUntilExit()  // wait for Launch Services handoff to complete
    } catch {
        fputs("notchify launch: \(error)\n", stderr)
        exit(1)
    }
    exit(0)
}

// ---- set ----
guard command == "set", args.count >= 3 else {
    fputs("Usage: notchify set <status> [--agent <id>] | notchify quit | notchify config | notchify help\n", stderr)
    exit(1)
}

let statusStr = args[2]
var agentID: String? = nil
var argIdx = 3
while argIdx < args.count {
    if args[argIdx] == "--agent", argIdx + 1 < args.count {
        let id = args[argIdx + 1]
        if !id.isEmpty { agentID = id }
        argIdx += 2
    } else {
        argIdx += 1
    }
}
let message = agentID.map { "\(statusStr) \($0)" } ?? statusStr
sendToSocket(message)

// MARK: - Socket helper

func sendToSocket(_ message: String) {
    let socketPath = "/tmp/notchify.sock" // must match StatusServer.socketPath

    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    guard fd >= 0 else { return }

    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    socketPath.withCString { cStr in
        withUnsafeMutablePointer(to: &addr.sun_path) { ptr in
            UnsafeMutableRawPointer(ptr).copyMemory(from: cStr, byteCount: strlen(cStr) + 1)
        }
    }

    let connectResult = withUnsafePointer(to: addr) { addrPtr in
        addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
        }
    }

    // If the app is not running, exit silently so Claude Code hooks don't fail
    guard connectResult == 0 else {
        close(fd)
        return
    }

    var msg = message
    msg.withUTF8 { ptr in
        _ = write(fd, ptr.baseAddress, ptr.count)
    }
    close(fd)
}
