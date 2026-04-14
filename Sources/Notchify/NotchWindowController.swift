import AppKit
import SwiftUI
import Combine

/// Transparent overlay panel positioned INSIDE the notch dead-zone,
/// flush against the right side of the notch zone.
/// NotchView draws a black pill background — visually the mascot
/// appears to live on the notch itself.
final class NotchWindowController: NSObject {
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()

    // Canvas size (must match CrabView: 20×12 pixels at ps=3.0)
    private let mascotWidth:  CGFloat = 20 * 3   // 60 pt
    private let mascotHeight: CGFloat = 12 * 3   // 36 pt

    override init() {
        super.init()
        setupPanel()
        observeStatus()
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

    private func observeStatus() {
        StatusManager.shared.$status
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] _ in _ = self }
            .store(in: &cancellables)
    }

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(repositionPanel),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func repositionPanel() {
        guard let panel, let screen = targetScreen() else { return }
        let frame = windowFrame(screen: screen)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    // MARK: - Screen selection

    /// Prefer the screen that has a notch (auxiliaryTopRightArea != nil).
    private func targetScreen() -> NSScreen? {
        NSScreen.screens.first(where: { $0.auxiliaryTopRightArea != nil })
            ?? NSScreen.main
    }

    // MARK: - Frame

    private func windowFrame(screen: NSScreen) -> CGRect {
        let sf = screen.frame
        let menuBarH = menuBarHeight(screen: screen)

        let x: CGFloat
        if let rightArea = screen.auxiliaryTopRightArea {
            // Sit the window's right edge 2 pt left of where system icons begin.
            // That tiny 2pt overlap gives the black background a seamless connection
            // to the dark notch zone, without hiding the mascot behind the camera hardware.
            x = sf.minX + (sf.width - rightArea.width) - 2
        } else {
            // Non-notch display fallback
            x = sf.maxX - 220 - mascotWidth
        }

        // Align window bottom with menu-bar bottom.
        // The 36pt canvas is taller than the 32pt menu bar on notch Macs —
        // the top few rows (empty canvas space) overflow and are clipped by the screen edge.
        let y = sf.maxY - menuBarH

        return CGRect(x: x, y: y, width: mascotWidth, height: menuBarH)
    }

    private func menuBarHeight(screen: NSScreen) -> CGFloat {
        screen.auxiliaryTopLeftArea?.height
            ?? screen.auxiliaryTopRightArea?.height
            ?? 24
    }
}
