#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The iPhone look of a next action; the words live in `PlanText`.
enum PlanCopy {
    static func symbol(for action: TaskNextAction) -> (name: String, color: Color) {
        switch action {
        case .fix: ("xmark.octagon.fill", AnchorStateTone.failed.ink)
        case .review: ("eye.fill", AnchorStateTone.attention.ink)
        case .wait: ("hourglass", AnchorIOSStyle.secondaryText)
        case .start: ("arrow.right.circle.fill", AnchorIOSStyle.action)
        case .finish: ("checkmark.seal.fill", AnchorStateTone.done.ink)
        }
    }
}
#endif
