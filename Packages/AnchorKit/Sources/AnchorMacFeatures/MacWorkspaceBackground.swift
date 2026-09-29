#if os(macOS)
import AnchorDesign
import SwiftUI

struct MacWorkspaceBackground: View {
    var body: some View {
        ZStack {
            AnchorPalette.canvas
            LinearGradient(
                colors: [
                    AnchorPalette.softBlue.opacity(0.34),
                    AnchorPalette.aiBlue.opacity(0.12),
                    AnchorPalette.canvas.opacity(0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .accessibilityHidden(true)
    }
}
#endif
