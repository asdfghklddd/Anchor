import SwiftUI

/// A solid information surface with one light-catching edge and one ambient shadow.
public struct FluoriteSurfaceStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    private let fill: Color
    private let border: Color
    private let cornerRadius: CGFloat
    private let elevated: Bool

    public init(
        fill: Color = AnchorPalette.fluoriteSurface,
        border: Color = AnchorPalette.fluoriteBorder,
        cornerRadius: CGFloat = 14,
        elevated: Bool = false
    ) {
        self.fill = fill
        self.border = border
        self.cornerRadius = cornerRadius
        self.elevated = elevated
    }

    public func body(content: Content) -> some View {
#if os(iOS)
        content
            .background(fill, in: .rect(cornerRadius: min(cornerRadius, AnchorIOSStyle.heroRadius)))
            .overlay {
                RoundedRectangle(cornerRadius: min(cornerRadius, AnchorIOSStyle.heroRadius))
                    .strokeBorder(
                        contrast == .increased ? AnchorIOSStyle.heading : border.opacity(0.45),
                        lineWidth: contrast == .increased ? 2 : 0.5
                    )
            }
            .shadow(color: AnchorIOSStyle.heading.opacity(elevated ? 0.08 : 0.05), radius: 12, y: 5)
#else
        content
            .background(fill, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.92),
                                contrast == .increased ? AnchorPalette.brandDeep.opacity(0.72) : border,
                                contrast == .increased ? AnchorPalette.brandDeep.opacity(0.58) : border.opacity(0.82),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: contrast == .increased ? 2 : 1
                    )
            }
            .shadow(
                color: AnchorPalette.brandDeep.opacity(elevated ? 0.09 : 0.045),
                radius: elevated ? 16 : 9,
                y: elevated ? 8 : 5
            )
#endif
    }
}

public extension View {
    func fluoriteSurface(
        fill: Color = AnchorPalette.fluoriteSurface,
        border: Color = AnchorPalette.fluoriteBorder,
        cornerRadius: CGFloat = 14,
        elevated: Bool = false
    ) -> some View {
        modifier(
            FluoriteSurfaceStyle(
                fill: fill,
                border: border,
                cornerRadius: cornerRadius,
                elevated: elevated
            )
        )
    }
}
