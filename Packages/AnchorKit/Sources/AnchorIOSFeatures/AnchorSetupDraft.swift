#if os(iOS)
import AnchorCore
import Foundation
import Observation

/// User-authored segments survive temporary sheet dismissal during rotation.
@MainActor
@Observable
final class AnchorSetupDraft {
    let hostedTaskID = UUID()
    let goalID = UUID()
    var goalTitle = ""
    var completionCriteria = ""
    var actionPlan = ""
    var imageData: [Data] = []
    var isImportingImages = false
    var isKeyboardEditing = false
    var segment: AnchorSetupSegment = .goal
    var isReviewing = false

    var criteria: [String] { lines(completionCriteria) }
    var steps: [String] { lines(actionPlan) }
    var isValid: Bool { !goalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !criteria.isEmpty && !steps.isEmpty }
    var originalText: String { [goalTitle, completionCriteria, actionPlan].filter { !$0.isEmpty }.joined(separator: "\n\n") }

    func text(for segment: AnchorSetupSegment) -> String {
        switch segment {
        case .goal: goalTitle
        case .criteria: completionCriteria
        case .steps: actionPlan
        }
    }

    func setText(_ text: String, for segment: AnchorSetupSegment) {
        switch segment {
        case .goal: goalTitle = text
        case .criteria: completionCriteria = text
        case .steps: actionPlan = text
        }
    }

    private func lines(_ text: String) -> [String] {
        // Only explicit line breaks split items; speech is never interpreted as a plan.
        text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
#endif
