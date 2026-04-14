import Foundation
import Darwin

let args = CommandLine.arguments
let command = args.count >= 2 ? args[1] : ""

// ---- help ----
if command == "help" || command == "--help" || command == "-h" || command.isEmpty {
    print("""
    notchify — pixel mascot for Claude Code in the MacBook notch area

    USAGE
      notchify set <status>   Send a status to the running app
      notchify launch         Launch the app
      notchify quit           Quit the running app
      notchify config         Interactive configurator (hooks, sounds, startup)
      notchify help           Show this help

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
      notchify set idle
      notchify launch
      notchify quit
      notchify config
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

// ---- launch ----
if command == "launch" {
    let appPath = resolveAppPath()
    guard FileManager.default.fileExists(atPath: appPath) else {
        fputs("notchify launch: app not found at \(appPath)\n", stderr)
        exit(1)
    }
    // Strip quarantine so Launch Services won't block the unsigned app
    let xattr = Process()
    xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
    xattr.arguments = ["-dr", "com.apple.quarantine", appPath]
    try? xattr.run()
    xattr.waitUntilExit()
    // Open via Launch Services — required for proper AppKit/window server init
    let openProc = Process()
    openProc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    openProc.arguments = [appPath]
    do {
        try openProc.run()
    } catch {
        fputs("notchify launch: \(error)\n", stderr)
        exit(1)
    }
    exit(0)
}

// ---- set ----
guard command == "set", args.count >= 3 else {
    fputs("Usage: notchify set <status> | notchify quit | notchify config | notchify help\n", stderr)
    exit(1)
}

sendToSocket(args[2])

// MARK: - App path resolution

/// Finds Notchify.app regardless of install method (setup.sh or Homebrew).
/// 1. Reads ~/.config/notchify/app_path saved by setup.sh
/// 2. Falls back to walking up from this binary's resolved path
func resolveAppPath() -> String {
    let savedPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/notchify/app_path").path
    if let saved = try? String(contentsOfFile: savedPath, encoding: .utf8) {
        let trimmed = saved.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && FileManager.default.fileExists(atPath: trimmed) {
            return trimmed
        }
    }
    // Walk up from the resolved binary path to find the enclosing .app
    let raw = CommandLine.arguments[0]
    let abs = raw.hasPrefix("/") ? raw : FileManager.default.currentDirectoryPath + "/" + raw
    var url = URL(fileURLWithPath: abs).resolvingSymlinksInPath()
    while url.pathComponents.count > 1 {
        if url.pathExtension == "app" { return url.path }
        url = url.deletingLastPathComponent()
    }
    return url.path
}

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
