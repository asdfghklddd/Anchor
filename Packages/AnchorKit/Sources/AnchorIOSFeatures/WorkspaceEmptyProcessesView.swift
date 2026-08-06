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
            AnchorPalette.surface.opacity(0.72),
            in: .rect(cornerRadius: 24, style: .continuous)
        )
        .accessibilityIdentifier("workspace.empty.processes")
    }
}
#endif
