#if os(iOS)
import AnchorDesign
import SwiftUI

struct WorkspaceEmptyProcessesView: View {
    var body: some View {
        ContentUnavailableView(
            L10n.noEvents,
            systemImage: "macbook.and.iphone",
            description: Text(L10n.emptyDetail)
        )
        .frame(maxWidth: .infinity, minHeight: 190)
        .background(
            AnchorPalette.fluoriteSurface,
            in: .rect(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(AnchorPalette.fluoriteBorder, lineWidth: 1)
        }
        .accessibilityIdentifier("workspace.empty.processes")
    }
}
#endif
