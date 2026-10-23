#if os(iOS)
import AnchorCore
import Foundation
import Observation

/// User-authored text survives closing the sheet and temporary rotation.
@MainActor
@Observable
final class AnchorSetupDraft {
    let hostedTaskID = UUID()
    let goalID = UUID()
    var goalTitle = ""
    var actionPlan = ""
    var imageData: [Data] = []
    var isImportingImages = false
    var isConsumed = false
    /// The anchor was dropped (not discarded); the home plays its success ending.
    var wasCreated = false

    var hasContent: Bool {
        !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !imageData.isEmpty
    }

    /// Lines, or a spoken sequence ("先…然后…"), become steps. Read several
    /// times per render, so the split runs once per change to the plan.
    var steps: [String] {
        if splitPlan != actionPlan {
            splitSteps = PlanStepSplitter.steps(from: actionPlan)
            splitPlan = actionPlan
        }
        return splitSteps
    }
    @ObservationIgnored private var splitPlan: String?
    @ObservationIgnored private var splitSteps: [String] = []
    /// A title is enough to drop an anchor; a plan is recommended, not required.
    var isValid: Bool { !goalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var titleUnits: Int { AnchorTitleLength.units(of: goalTitle) }
    var titleIsTooLong: Bool { titleUnits > AnchorTitleLength.limit }
    var originalText: String { [goalTitle, actionPlan].filter { !$0.isEmpty }.joined(separator: "\n\n") }

    /// A title is one line that fits the boards. Extra lines, and words past the
    /// limit, move to the top of the plan instead of being lost.
    /// Returns whether anything moved.
    @discardableResult
    func settleTitle() -> Bool {
        let lines = goalTitle.components(separatedBy: .newlines)
        let split = AnchorTitleLength.split(lines.first ?? "")
        let moved = ([split.rest] + lines.dropFirst())
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if goalTitle != split.title { goalTitle = split.title }
        guard !moved.isEmpty else { return false }
        let plan = actionPlan.trimmingCharacters(in: .newlines)
        actionPlan = (moved + (plan.isEmpty ? [] : [plan])).joined(separator: "\n")
        return true
    }
}
#endif
