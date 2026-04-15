import AppKit
import SwiftUI

/// Transparent overlay panel positioned INSIDE the notch dead-zone,
/// flush against the right side of the notch zone.
/// NotchView draws a black pill background — visually the mascot
/// appears to live on the notch itself.
final class NotchWindowController: NSObject {
    private var panel: NSPanel?

    // Canvas size (must match CrabView: 20×12 pixels at ps=3.0)
    private let mascotWidth:  CGFloat = 20 * 3   // 60 pt
    private let mascotHeight: CGFloat = 12 * 3   // 36 pt

    override init() {
        super.init()
        setupPanel()
        observeScreenChanges()
    }

    // MARK: - Setup

    private func setupPanel() {
        guard let screen = targetScreen() else { return }
        let frame = windowFrame(screen: screen)

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

        let rootView = NotchView().environmentObject(StatusManager.shared)
        panel.contentView = NSHostingView(rootView: rootView)

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
        // Close existing panel and recreate — ensures correct screen association
        // and proper display on both notch and non-notch screens.
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

    // MARK: - Frame

    private func windowFrame(screen: NSScreen) -> CGRect {
        let settings = DisplayConfig.load()
        let sf = screen.frame
        let menuBarH = menuBarHeight(screen: screen)
        let windowH  = max(menuBarH, mascotHeight)
        let hOffset  = CGFloat(settings.horizontalOffset)
        let vOffset  = CGFloat(settings.verticalOffset)  // positive = down

        let x: CGFloat
        if let rightArea = screen.auxiliaryTopRightArea {
            x = sf.minX + (sf.width - rightArea.width) - 2 + hOffset
        } else {
            // Non-notch: center the mascot in the menu bar
            x = sf.minX + (sf.width - mascotWidth) / 2 + hOffset
        }

        // Anchor top of window to screen top so the mascot isn't clipped,
        // then apply vertical offset (positive shifts down).
        let y = sf.maxY - windowH - vOffset

        return CGRect(x: x, y: y, width: mascotWidth, height: windowH)
    }

    private func menuBarHeight(screen: NSScreen) -> CGFloat {
        screen.auxiliaryTopLeftArea?.height
            ?? screen.auxiliaryTopRightArea?.height
            ?? 24
    }
}
