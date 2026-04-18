import Foundation
import Combine
import AppKit

extension Notification.Name {
    static let notchifyReposition = Notification.Name("notchifyReposition")
}

enum ClaudeStatus: String, Equatable {
    case idle
    case start       // plays once on Claude Code launch, freezes on last frame
    case working
    case waiting
    case done        // mascot celebrates, stops on last frame
    case bye         // plays once on Claude Code exit → slot removed
    case error       // mascot shakes → becomes errorBadge after 1.5 s
    case doneBadge   // badge stays, no mascot
    case errorBadge  // badge stays, no mascot
}

struct AgentState: Identifiable {
    let id: String
    var status: ClaudeStatus
    var joinTime: Date
    var startAnimationDone: Bool
    var lastActivity: Date
}

final class StatusManager: ObservableObject {
    static let shared = StatusManager()
    static let maxAgents = 3

    @Published var agents: [AgentState] = []

    /// Per-agent timers for error → errorBadge transition.
    private var errorTimers: [String: DispatchWorkItem] = [:]

    /// Fires `bye` when a tracked shell PID disappears (terminal closed without `exit`).
    private let watcher = ProcessWatcher()

    private static let claudeBundleID = "com.anthropic.claudefordesktop"

    private init() {
        watcher.onDead = { [weak self] id in
            self?.update(.bye, agentID: id)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == Self.claudeBundleID
            else { return }
            self?.byeAllUntrackedAgents()
        }
    }

    private func byeAllUntrackedAgents() {
        // Agents without a numeric agentID have no ProcessWatcher coverage
        // (e.g. sessions started from Claude.app where NOTCHIFY_AGENT_ID isn't set)
        let untracked = agents.filter { pid_t($0.id) == nil }
        for agent in untracked {
            update(.bye, agentID: agent.id)
        }
    }

    // MARK: - Mutations (must be called on main queue)

    func markStartDone(agentID: String) {
        guard let idx = agents.firstIndex(where: { $0.id == agentID }) else { return }
        agents[idx].startAnimationDone = true
    }

    /// Called by ByeAnimationView when the farewell animation completes.
    func removeAgent(id: String) {
        agents.removeAll { $0.id == id }
        errorTimers[id]?.cancel()
        errorTimers.removeValue(forKey: id)
        watcher.untrack(agentID: id)
    }

    // MARK: - Update

    func update(_ newStatus: ClaudeStatus, agentID: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Cancel any pending error-transition timer for this agent
            self.errorTimers[agentID]?.cancel()
            self.errorTimers.removeValue(forKey: agentID)

            if let idx = self.agents.firstIndex(where: { $0.id == agentID }) {
                // ── Existing agent ──────────────────────────────────────────
                let agent = self.agents[idx]

                // While start animation plays, block hook overrides (except start/bye/idle)
                if agent.status == .start && !agent.startAnimationDone
                    && newStatus != .start && newStatus != .bye && newStatus != .idle {
                    return
                }
                // Once bye is running, ignore everything until the slot is removed
                if agent.status == .bye && newStatus != .idle {
                    return
                }
                // done → waiting: idle_prompt fires after Stop and must not erase the
                // celebration animation. Only working/start/bye/idle can clear done.
                if agent.status == .done && newStatus == .waiting {
                    return
                }

                // Force-reset to idle before start/bye so SwiftUI always recreates
                // the animation view even when the status hasn't changed.
                if newStatus == .start || newStatus == .bye {
                    if newStatus == .start { self.agents[idx].startAnimationDone = false }
                    if self.agents[idx].status == newStatus {
                        self.agents[idx].status = .idle
                    }
                }

                self.agents[idx].status       = newStatus
                self.agents[idx].lastActivity = Date()

            } else {
                // ── New agent ───────────────────────────────────────────────
                guard self.agents.count < Self.maxAgents else { return }

                let newAgent = AgentState(
                    id: agentID,
                    status: newStatus,
                    joinTime: Date(),
                    startAnimationDone: false,
                    lastActivity: Date()
                )
                self.agents.append(newAgent)
            }

            // Shell-PID liveness tracking: untrack on bye (animation is running),
            // otherwise (re)register the agent's shell PID so we can auto-fire bye
            // if the terminal is closed without running `exit`.
            if newStatus == .bye {
                self.watcher.untrack(agentID: agentID)
            } else if let pid = pid_t(agentID) {
                self.watcher.track(agentID: agentID, pid: pid)
            }

            SoundManager.shared.play(for: newStatus)

            // Schedule error → errorBadge after 1.5 s
            if newStatus == .error {
                let work = DispatchWorkItem { [weak self] in
                    guard let self,
                          let idx = self.agents.firstIndex(where: { $0.id == agentID })
                    else { return }
                    self.agents[idx].status = .errorBadge
                }
                self.errorTimers[agentID] = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
            }
        }
    }

    // MARK: - Backward-compatible single-agent shims

    func update(_ newStatus: ClaudeStatus) {
        update(newStatus, agentID: "default")
    }

    func markStartDone() {
        markStartDone(agentID: "default")
    }
}
