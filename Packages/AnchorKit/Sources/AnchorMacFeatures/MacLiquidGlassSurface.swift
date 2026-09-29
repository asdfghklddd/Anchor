#if os(macOS)
import AnchorDesign
import SwiftUI

private struct MacLiquidGlassSurface<SurfaceShape: Shape>: ViewModifier {
    let tint: Color?
    let shape: SurfaceShape

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(AnchorPalette.fluoriteSurface, in: shape)
                .overlay {
                    shape.stroke(
                        contrast == .increased
                            ? AnchorPalette.brandDeep.opacity(0.72)
                            : AnchorPalette.fluoriteBorder,
                        lineWidth: contrast == .increased ? 2 : 1
                    )
                }
        } else {
            content.glassEffect(
                .regular
                    .tint(tint)
                    .interactive(),
                in: shape
            )
        }
    }
}

extension View {
    func macLiquidGlass<SurfaceShape: Shape>(
        tint: Color? = nil,
        in shape: SurfaceShape
    ) -> some View {
        modifier(MacLiquidGlassSurface(tint: tint, shape: shape))
    }
}
#endif
