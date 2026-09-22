import SwiftUI

/// A solid information surface with one light-catching edge and one ambient shadow.
public struct FluoriteSurfaceStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

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
        content
            .background(fill, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(colorScheme == .dark ? 0.10 : 0.92),
                                border,
                                border.opacity(0.82),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(
                color: AnchorPalette.brandDeep.opacity(elevated ? 0.09 : 0.045),
                radius: elevated ? 16 : 9,
                y: elevated ? 8 : 5
            )
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
