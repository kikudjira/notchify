import Darwin

enum ANSI {
    static let isTTY = isatty(STDOUT_FILENO) != 0

    static let reset   = isTTY ? "\u{1B}[0m"  : ""
    static let bold    = isTTY ? "\u{1B}[1m"  : ""
    static let dim     = isTTY ? "\u{1B}[2m"  : ""
    static let cyan    = isTTY ? "\u{1B}[36m" : ""
    static let green   = isTTY ? "\u{1B}[32m" : ""
    static let yellow  = isTTY ? "\u{1B}[33m" : ""
    static let red     = isTTY ? "\u{1B}[31m" : ""
    static let magenta = isTTY ? "\u{1B}[35m" : ""

    static func on()  -> String { "\(green)\(bold) ON \(reset)" }
    static func off() -> String { "\(dim) OFF\(reset)" }

    static func clearScreen() {
        if isTTY { print("\u{1B}[2J\u{1B}[H", terminator: "") }
    }

    static func header(_ title: String, subtitle: String? = nil) {
        let bar = String(repeating: "─", count: 46)
        print("\(cyan)\(bar)\(reset)")
        print("  \(bold)\(title)\(reset)")
        if let sub = subtitle { print("  \(dim)\(sub)\(reset)") }
        print("\(cyan)\(bar)\(reset)")
        print()
    }

    // Read a full line (for paths / sound names)
    static func readLine(prompt: String) -> String {
        print("\(dim)\(prompt)\(reset)", terminator: "")
        fflush(stdout)
        return Swift.readLine(strippingNewline: true) ?? ""
    }
}
