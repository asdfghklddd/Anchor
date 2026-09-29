#if os(iOS)
import AnchorDesign
import SwiftUI

/// Keeps native Form/List behavior while placing grouped rows on the shared iOS canvas.
private struct IOSListSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .foregroundStyle(AnchorIOSStyle.text)
            .background { HarborBackground() }
            .tint(AnchorIOSStyle.action)
    }
}

extension View {
    func anchorIOSListSurface() -> some View {
        modifier(IOSListSurface())
    }
}
#endif
