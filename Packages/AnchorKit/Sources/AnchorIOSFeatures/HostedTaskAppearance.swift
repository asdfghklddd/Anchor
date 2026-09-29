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
        case 3: return Color(red: 0.30, green: 0.81, blue: 0.94)
        default: return Color(hue: (Double(index) * 0.61803398875).truncatingRemainder(dividingBy: 1), saturation: 0.64, brightness: 0.88)
        }
    }

    static func isComplete(_ task: AnchorSession) -> Bool {
        !task.taskProcesses.isEmpty && task.taskProcesses.allSatisfy { $0.status == .completed }
    }
}
#endif
