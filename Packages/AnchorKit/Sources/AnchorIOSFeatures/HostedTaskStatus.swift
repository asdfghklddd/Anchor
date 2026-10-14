#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// One task's reported state, shared by library cards and landscape rows so
/// both always say the same thing. Mixed states are never collapsed (D02):
/// `primary` is the most urgent, `remainder` names the rest.
struct HostedTaskStatus {
    var running = 0, attention = 0, failed = 0, interrupted = 0, completed = 0
    let isComplete: Bool
    let hasSources: Bool

    init(task: AnchorSession) {
        let processes = task.taskProcesses
        hasSources = !processes.isEmpty
        isComplete = HostedTaskIndicator(task: task).isComplete
        for process in processes {
            if process.isInterrupted { interrupted += 1; continue }
            switch process.status {
            case .running: running += 1
            case .needsDecision, .blocked, .disconnected: attention += 1
            case .failed: failed += 1
            case .completed: completed += 1
            case .queued: break
            }
        }
    }

    enum Primary { case done, awaiting, failed, attention, interrupted, running, quiet }

    var primary: Primary {
        if isComplete { return .done }
        if !hasSources { return .awaiting }
        if failed > 0 { return .failed }
        if attention > 0 { return .attention }
        if interrupted > 0 { return .interrupted }
        if running > 0 { return .running }
        return .quiet
    }

    /// Short word for reading from the desk.
    var word: String {
        switch primary {
        case .done: L10n.tideState(.completed)
        case .awaiting: L10n.cardAwaitingSource
        case .failed: L10n.tideState(.failed)
        case .attention: L10n.tideState(.attention)
        case .interrupted: L10n.tideState(.interrupted)
        case .running: L10n.tideState(.running)
        case .quiet: L10n.glanceQuiet
        }
    }

    var symbol: (name: String, color: Color) {
        switch primary {
        case .done: ("checkmark.circle.fill", AnchorStateTone.done.ink)
        case .awaiting: ("circle.dashed", AnchorIOSStyle.secondaryText)
        case .failed: ("xmark.octagon.fill", AnchorStateTone.failed.ink)
        case .attention: ("exclamationmark.circle.fill", AnchorStateTone.attention.ink)
        case .interrupted: ("pause.circle.fill", AnchorStateTone.attention.ink)
        case .running: ("play.circle.fill", AnchorStateTone.running.ink)
        case .quiet: ("moon.zzz.fill", AnchorIOSStyle.secondaryText)
        }
    }

    /// Every reported state with its count ("1 项失败 · 1 项运行中").
    var summary: String {
        if isComplete { return L10n.tideState(.completed) }
        if !hasSources { return L10n.cardAwaitingSource }
        let text = L10n.cardStateSummary(running: running, attention: attention, failed: failed, interrupted: interrupted)
        return text.isEmpty ? L10n.glanceQuiet : text
    }

    /// The states the primary word did not mention.
    var remainder: String {
        L10n.cardStateSummary(
            running: primary == .running ? 0 : running,
            attention: primary == .attention ? 0 : attention,
            failed: primary == .failed ? 0 : failed,
            interrupted: primary == .interrupted ? 0 : interrupted
        )
    }
}
#endif
