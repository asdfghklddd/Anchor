#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

enum HostedTaskAppearance {
    /// Stable identity colors do not change when a source, progress value, or list position changes.
    static func tint(_ task: AnchorSession) -> Color {
        let index = task.taskColorIndex ?? 0
        switch index {
        case 0: return AnchorIOSStyle.yellow
        case 1: return AnchorIOSStyle.cyan
        case 2: return AnchorIOSStyle.pink
        case 3: return AnchorIOSStyle.violet
        // Hand-picked hues stay clear of the named colors and of status green/red.
        case 4: return AnchorIOSStyle.generatedTaskColor(hue: 0.07)
        case 5: return AnchorIOSStyle.generatedTaskColor(hue: 0.62)
        case 6: return AnchorIOSStyle.generatedTaskColor(hue: 0.22)
        default:
            return AnchorIOSStyle.generatedTaskColor(
                hue: (Double(index) * 0.61803398875).truncatingRemainder(dividingBy: 1)
            )
        }
    }

    static func isComplete(_ task: AnchorSession) -> Bool {
        HostedTaskIndicator(task: task).isComplete
    }
}
#endif
