import Foundation
import Darwin

/// Watches shell PIDs of active agents and fires `onDead` when a PID disappears.
/// Catches the case where a terminal window is closed without the shell wrapper
/// getting a chance to run `notchify set bye` (SIGHUP, SIGKILL, crash).
///
/// All public methods must be called on the main queue.
final class ProcessWatcher {
    var onDead: ((String) -> Void)?

    private var tracked: [String: pid_t] = [:]
    private var timer: DispatchSourceTimer?

    private static let interval: DispatchTimeInterval = .seconds(3)
    private static let leeway: DispatchTimeInterval  = .milliseconds(500)

    func track(agentID: String, pid: pid_t) {
        guard pid > 0 else { return }
        tracked[agentID] = pid
        if timer == nil { startTimer() }
    }

    func untrack(agentID: String) {
        tracked.removeValue(forKey: agentID)
        if tracked.isEmpty { stopTimer() }
    }

    private func startTimer() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + Self.interval,
                   repeating: Self.interval,
                   leeway: Self.leeway)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        var dead: [String] = []
        for (id, pid) in tracked {
            // kill(pid, 0) == 0            → process exists, we can signal
            // errno == ESRCH after -1      → no such process (dead)
            // errno == EPERM after -1      → exists, we can't signal (still alive)
            if kill(pid, 0) != 0 && errno == ESRCH {
                dead.append(id)
            }
        }
        for id in dead {
            tracked.removeValue(forKey: id)
            onDead?(id)
        }
        if tracked.isEmpty { stopTimer() }
    }
}
