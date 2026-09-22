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
        .fluoriteSurface(cornerRadius: 14)
        .accessibilityIdentifier("workspace.empty.processes")
    }
}
#endif
