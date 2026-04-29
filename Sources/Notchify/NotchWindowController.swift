import AppKit
import SwiftUI

/// Transparent overlay panel positioned INSIDE the notch dead-zone,
/// flush against the right side of the notch zone.
/// NotchView draws a black pill background — visually the mascot
/// appears to live on the notch itself.
final class NotchWindowController: NSObject {
    private var panel: NSPanel?

    // Canvas size (must match CrabView: 20×12 pixels at ps=3.0)
    private let mascotWidth:   CGFloat = 20 * 3   // 60 pt
    private let mascotHeight:  CGFloat = 12 * 3   // 36 pt
    // Negative spacing between mascot slots in NotchView — must match HStack(spacing:)
    private let mascotSpacing: CGFloat = -20

    // Panel is always the maximum width (enough for StatusManager.maxAgents slots).
    // This avoids AppKit resize flashes — transparent areas simply show nothing.
    private var maxPanelWidth: CGFloat {
        mascotWidth + (mascotWidth + mascotSpacing) * CGFloat(StatusManager.maxAgents - 1)
    }

    override init() {
        super.init()
        setupPanel()
        observeScreenChanges()
    }

    // MARK: - Setup

    private func setupPanel() {
        guard let screen = targetScreen() else { return }
        let settings = DisplayConfig.load()
        let profile  = profile(for: screen, settings: settings)
        let frame    = windowFrame(screen: screen, profile: profile)

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        let rootView = NotchView(direction: profile.mascotDirection)
            .environmentObject(StatusManager.shared)
        let hostView = NSHostingView(rootView: rootView)
        // Prevent NSHostingView from flashing white before SwiftUI paints
        hostView.wantsLayer = true
        hostView.layer?.backgroundColor = .clear
        panel.contentView = hostView

        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionPanel),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionPanel),
            name: .notchifyReposition,
            object: nil
        )
    }

    @objc private func repositionPanel() {
        panel?.close()
        panel = nil
        setupPanel()
    }

    // MARK: - Screen selection

    /// Returns the target screen based on DisplayConfig.
    private func targetScreen() -> NSScreen? {
        let settings = DisplayConfig.load()
        let screens = NSScreen.screens
        if settings.screenIndex >= 0, settings.screenIndex < screens.count {
            return screens[settings.screenIndex]
        }
        // Auto: prefer notch screen
        return screens.first(where: { $0.auxiliaryTopRightArea != nil }) ?? NSScreen.main
    }

    // MARK: - Profile selection

    private func profile(for screen: NSScreen, settings: DisplaySettings) -> ProfileSettings {
        screen.auxiliaryTopRightArea != nil ? settings.notch : settings.external
    }

    // MARK: - Frame

    private func windowFrame(screen: NSScreen, profile: ProfileSettings) -> CGRect {
        let sf       = screen.frame
        let menuBarH = menuBarHeight(screen: screen)
        let windowH  = max(menuBarH, mascotHeight)
        let windowW  = maxPanelWidth   // always max — transparent area causes no flash
        let hOffset  = CGFloat(profile.horizontalOffset)
        let vOffset  = CGFloat(profile.verticalOffset)  // positive = down

        let x: CGFloat
        if let rightArea = screen.auxiliaryTopRightArea {
            // Notch screen — only .right / .left reach here (.center coerced away at load).
            let notchRightEdge = sf.minX + (sf.width - rightArea.width)
            switch profile.mascotDirection {
            case .right, .center:
                // Anchor panel's left edge just left of the notch's right boundary;
                // HStack(.leading) places the first mascot flush against the notch.
                x = notchRightEdge - 2 + hOffset
            case .left:
                // Anchor panel's right edge just right of the notch's left boundary;
                // HStack(.trailing) places the newest mascot flush against the notch.
                let notchLeftEdge = screen.auxiliaryTopLeftArea?.maxX ?? (notchRightEdge - 200)
                x = notchLeftEdge + 2 - windowW + hOffset
            }
        } else {
            // External / non-notch screen: panel centered in menu bar; HStack alignment
            // (driven by mascotDirection) decides where the mascot sits inside the panel.
            // .center → mascots centered. .right/.left → flush against panel edge.
            x = sf.minX + (sf.width - windowW) / 2 + hOffset
        }

        let y = sf.maxY - windowH - vOffset

        return CGRect(x: x, y: y, width: windowW, height: windowH)
    }

    private func menuBarHeight(screen: NSScreen) -> CGFloat {
        screen.auxiliaryTopLeftArea?.height
            ?? screen.auxiliaryTopRightArea?.height
            ?? 24
    }
}
