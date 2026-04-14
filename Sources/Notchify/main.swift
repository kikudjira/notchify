import AppKit

// Run as a background agent — no Dock icon, no menu bar item
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchWindowController?
    private var statusServer: StatusServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        notchController = NotchWindowController()

        statusServer = StatusServer()
        statusServer?.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusServer?.stop()
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
