import SwiftUI

/// The small, expressive Anchor companion used by the ambient clear state.
/// It mirrors the prototype's `AnchorCompanion` while keeping the glyph
/// native and decorative to assistive technologies.
public struct HarborCompanion: View {
    public enum Mood: Sendable, Equatable {
        case calm
        case happy
    }

    private let mood: Mood
    private let size: CGFloat

    public init(mood: Mood = .happy, size: CGFloat = 46) {
        self.mood = mood
        self.size = size
    }

    public var body: some View {
        ZStack {
            HarborAnchorGlyph(lineWidth: max(1.8, size * 0.05))
                .frame(width: size * 0.48, height: size * 0.48)

            HStack(spacing: size * 0.14) {
                Circle()
                    .fill(AnchorPalette.deepSea)
                    .frame(width: size * 0.055, height: size * 0.055)
                Circle()
                    .fill(AnchorPalette.deepSea)
                    .frame(width: size * 0.055, height: size * 0.055)
            }
            .offset(y: -size * 0.19)

            Capsule()
                .stroke(AnchorPalette.deepSea, lineWidth: max(1, size * 0.032))
                .frame(width: size * (mood == .calm ? 0.14 : 0.18), height: size * 0.08)
                .offset(y: -size * 0.06)
        }
        .frame(width: size, height: size)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.79, green: 0.97, blue: 0.91),
                    AnchorPalette.seafoam,
                    AnchorPalette.cyan,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: size * 0.32, style: .continuous)
        )
        .overlay(alignment: .top) {
            Capsule()
                .fill(.white.opacity(0.55))
                .frame(width: size * 0.58, height: max(2, size * 0.065))
                .padding(.top, size * 0.08)
        }
        .shadow(color: AnchorPalette.cyan.opacity(0.24), radius: size * 0.22, y: size * 0.13)
        .accessibilityHidden(true)
    }
}
