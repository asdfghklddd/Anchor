#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

enum HostedTaskAppearance {
    /// Stable identity colors do not change when a source, progress value, or list position changes.
    static func tint(_ task: AnchorSession) -> Color {
        AnchorTaskIdentity.color(for: task)
    }

    static func isComplete(_ task: AnchorSession) -> Bool {
        HostedTaskIndicator(task: task).isComplete
    }
}
#endif
