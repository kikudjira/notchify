import Darwin

enum Key: Equatable {
    case up, down, left, right
    case space, enter
    case char(Character)
}

struct Terminal {
    private static var saved: termios?
    private static var savedStdin:  Int32 = -1
    private static var savedStdout: Int32 = -1

    static func enableRaw() {
        let tty = open("/dev/tty", O_RDWR)
        guard tty >= 0 else { return }

        savedStdin  = dup(STDIN_FILENO)
        savedStdout = dup(STDOUT_FILENO)
        dup2(tty, STDIN_FILENO)
        dup2(tty, STDOUT_FILENO)
        close(tty)

        var old = termios()
        guard tcgetattr(STDIN_FILENO, &old) == 0 else { return }
        saved = old
        var raw = old
        raw.c_lflag &= ~tcflag_t(ECHO | ICANON | ISIG | IEXTEN)
        raw.c_iflag &= ~tcflag_t(IXON | ICRNL | BRKINT | INPCK | ISTRIP)
        raw.c_cc.16 = 1  // VMIN
        raw.c_cc.17 = 0  // VTIME
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)

        let setup = "\u{1B}[?1049h\u{1B}[2J\u{1B}[H\u{1B}[?25l"
        setup.withCString { _ = Darwin.write(STDOUT_FILENO, $0, strlen($0)) }
    }

    static func restore() {
        // Exit alternate screen, show cursor
        print("\u{1B}[?1049l\u{1B}[?25h", terminator: "")
        fflush(stdout)
        if var t = saved { tcsetattr(STDIN_FILENO, TCSAFLUSH, &t) }
        saved = nil
        // Restore original stdin/stdout
        if savedStdin  >= 0 { dup2(savedStdin,  STDIN_FILENO);  close(savedStdin);  savedStdin  = -1 }
        if savedStdout >= 0 { dup2(savedStdout, STDOUT_FILENO); close(savedStdout); savedStdout = -1 }
    }

    static func readKey() -> Key {
        var b: UInt8 = 0
        while read(STDIN_FILENO, &b, 1) < 1 {}
        if b == 0x20 { return .space }
        if b == 0x0D || b == 0x0A { return .enter }
        if b != 0x1B {
            return .char(Character(Unicode.Scalar(b)))
        }
        // ESC: read sequence with 100ms timeout
        var cur = termios()
        tcgetattr(STDIN_FILENO, &cur)
        var timed = cur
        timed.c_cc.16 = 0  // VMIN
        timed.c_cc.17 = 1  // VTIME (100ms)
        tcsetattr(STDIN_FILENO, TCSANOW, &timed)
        var s1: UInt8 = 0, s2: UInt8 = 0
        let n1 = read(STDIN_FILENO, &s1, 1)
        let n2 = n1 == 1 ? read(STDIN_FILENO, &s2, 1) : 0
        tcsetattr(STDIN_FILENO, TCSANOW, &cur)
        guard n1 == 1, n2 == 1, s1 == 0x5B else { return .char("\u{1B}") }
        switch s2 {
        case 0x41: return .up
        case 0x42: return .down
        case 0x43: return .right
        case 0x44: return .left
        default:   return .char("\u{1B}")
        }
    }
}
