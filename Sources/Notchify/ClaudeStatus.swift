import Foundation
import Combine

extension Notification.Name {
    static let notchifyReposition = Notification.Name("notchifyReposition")
}

enum ClaudeStatus: String, Equatable {
    case idle
    case start       // plays once on Claude Code launch, freezes on last frame
    case working
    case waiting
    case done        // mascot celebrates, stops on last frame
    case bye         // plays once on Claude Code exit → idle
    case error       // mascot shakes    → slides out → becomes errorBadge
    case doneBadge   // badge stays, no mascot
    case errorBadge  // badge stays, no mascot
}

final class StatusManager: ObservableObject {
    static let shared = StatusManager()

    @Published var status: ClaudeStatus = .idle

    /// Timestamp when the mascot entered `.waiting` state.
    /// Used by StatusServer to distinguish simultaneous Notification+Stop
    /// from a legitimate done after the user responds to a permission prompt.
    private(set) var waitingSince: Date?

    private var transitionTimer: Timer?
    private var startAnimationDone = false

    private init() {}

    /// Called by StartAnimationView when the last frame is reached.
    func markStartDone() {
        startAnimationDone = true
    }

    func update(_ newStatus: ClaudeStatus) {
        transitionTimer?.invalidate()
        transitionTimer = nil

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // While start animation is still playing, block hooks from overriding it.
            // Once it finishes (startAnimationDone = true), any status can take over.
            if self.status == .start && !self.startAnimationDone
                && newStatus != .start && newStatus != .bye && newStatus != .idle {
                return
            }
            if self.status == .bye && newStatus != .idle {
                return
            }

            // Force-reset to idle before start/bye so SwiftUI always
            // recreates the animation view even if the status hasn't changed.
            if newStatus == .start || newStatus == .bye {
                if newStatus == .start { self.startAnimationDone = false }
                if self.status == newStatus {
                    self.status = .idle
                }
            }

            self.status = newStatus
            self.waitingSince = newStatus == .waiting ? Date() : nil
            SoundManager.shared.play(for: newStatus)

            switch newStatus {
            case .error:
                // error → errorBadge after 1.5 s
                self.transitionTimer = Timer.scheduledTimer(
                    withTimeInterval: 1.5, repeats: false
                ) { [weak self] _ in
                    self?.status = .errorBadge
                }
            default:
                break
            }
        }
    }
}
