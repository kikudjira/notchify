import AppKit
import SwiftUI
import Combine

/// Transparent overlay panel positioned INSIDE the notch dead-zone,
/// flush against the right side of the notch zone.
/// NotchView draws a black pill background — visually the mascot
/// appears to live on the notch itself.
final class NotchWindowController: NSObject {
    private var panel: NSPanel?
    private var agentCountCancellable: AnyCancellable?

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
        let frame = windowFrame(screen: screen, agentCount: 1)

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
        let hostView = NSHostingView(rootView: rootView)
        // Prevent NSHostingView from flashing white before SwiftUI paints
        hostView.wantsLayer = true
        hostView.layer?.backgroundColor = .clear
        panel.contentView = hostView

        panel.orderFrontRegardless()
        self.panel = panel

        // Resize panel when the number of active agents changes.
        // dropFirst() skips the initial emission so we don't animate on setup.
        agentCountCancellable = StatusManager.shared.$agents
            .map(\.count)
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] count in
                self?.resizePanelForAgentCount(max(1, min(count, StatusManager.maxAgents)))
            }
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
        // Cancel subscription before teardown so the sink doesn't fire
        // on the closing panel while a new one is being set up.
        agentCountCancellable?.cancel()
        agentCountCancellable = nil
        panel?.close()
        panel = nil
        setupPanel()
    }

    // MARK: - Dynamic resize

    private func resizePanelForAgentCount(_ count: Int) {
        guard let panel, let screen = targetScreen() else { return }
        let newFrame = windowFrame(screen: screen, agentCount: count)
        panel.setFrame(newFrame, display: true, animate: true)
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

    private func windowFrame(screen: NSScreen, agentCount: Int = 1) -> CGRect {
        let settings = DisplayConfig.load()
        let sf = screen.frame
        let menuBarH  = menuBarHeight(screen: screen)
        let windowH   = max(menuBarH, mascotHeight)
        let windowW   = mascotWidth * CGFloat(agentCount)
        let hOffset   = CGFloat(settings.horizontalOffset)
        let vOffset   = CGFloat(settings.verticalOffset)  // positive = down

        let x: CGFloat
        if let rightArea = screen.auxiliaryTopRightArea {
            // Notch screen: anchor left edge to notch-left boundary, grow right
            x = sf.minX + (sf.width - rightArea.width) - 2 + hOffset
        } else {
            // Non-notch: center the panel in the menu bar
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
