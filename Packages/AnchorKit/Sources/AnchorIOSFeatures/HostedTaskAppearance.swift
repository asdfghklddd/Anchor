#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

enum HostedTaskAppearance {
    /// Stable identity colors do not change when a source, progress value, or list position changes.
    static func tint(_ task: AnchorSession) -> Color {
        AnchorTaskIdentity.color(for: task)
    }

    /// Landscape tabs use the owner-approved Figma palette rather than the
    /// global task-identity palette used by status-adjacent surfaces elsewhere.
    static func landscapeTabTint(_ task: AnchorSession) -> Color {
        Color(AnchorColorTokens.landscapeTaskTab(index: task.taskColorIndex ?? 0))
    }

    static let landscapeTabInk = Color(AnchorColorTokens.onLandscapeTaskTab)

    static func isComplete(_ task: AnchorSession) -> Bool {
        HostedTaskIndicator(task: task).isComplete
    }
}
#endif
