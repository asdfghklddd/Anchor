#if os(iOS)
import Foundation

enum AnchorSetupSegment: Int, CaseIterable, Identifiable {
    case goal, criteria, steps
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .goal: SetupCopy.goal
        case .criteria: SetupCopy.criteria
        case .steps: SetupCopy.steps
        }
    }
    var prompt: String {
        switch self {
        case .goal: SetupCopy.goalPrompt
        case .criteria: SetupCopy.criteriaPrompt
        case .steps: SetupCopy.stepsPrompt
        }
    }
    var placeholder: String {
        switch self {
        case .goal: SetupCopy.goalPlaceholder
        case .criteria: SetupCopy.criteriaPlaceholder
        case .steps: SetupCopy.stepsPlaceholder
        }
    }
    var hint: String {
        switch self {
        case .goal: SetupCopy.goalHint
        case .criteria: SetupCopy.criteriaHint
        case .steps: SetupCopy.stepsHint
        }
    }
    var fieldID: String {
        switch self {
        case .goal: "setup.goal.field"
        case .criteria: "setup.criteria.field"
        case .steps: "setup.steps.field"
        }
    }
}
#endif
