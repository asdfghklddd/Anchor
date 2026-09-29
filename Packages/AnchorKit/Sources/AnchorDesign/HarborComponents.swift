import SwiftUI

/// Keeps the iPhone and Mac content canvas consistent while navigation remains platform-native.
public struct HarborBackground: View {
    public init() {}

    public var body: some View {
#if os(iOS)
        AnchorIOSStyle.background
            .ignoresSafeArea()
            .accessibilityHidden(true)
#else
        ZStack {
            AnchorPalette.canvas
            LinearGradient(
                colors: [AnchorPalette.softBlue.opacity(0.16), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .accessibilityHidden(true)
#endif
    }
}

public struct HarborHeroSurface<Content: View>: View {
    private let content: Content
    private let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 28, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
#if os(iOS)
        content
            .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: AnchorIOSStyle.heroRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AnchorIOSStyle.heroRadius)
                    .strokeBorder(AnchorIOSStyle.border.opacity(0.5), lineWidth: 1)
            }
            .shadow(color: AnchorIOSStyle.heading.opacity(0.06), radius: 12, y: 5)
#else
        content
            .background {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.30, blue: 0.40),
                            AnchorPalette.deepSea,
                            Color(red: 0.04, green: 0.17, blue: 0.25),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Circle()
                        .fill(.white.opacity(0.65))
                        .frame(width: 2, height: 2)
                        .offset(x: 112, y: -56)
                    Circle()
                        .fill(AnchorPalette.seafoam.opacity(0.65))
                        .frame(width: 3, height: 3)
                        .offset(x: 82, y: -28)
                    Circle()
                        .fill(AnchorPalette.sand.opacity(0.58))
                        .frame(width: 2, height: 2)
                        .offset(x: 126, y: 42)
                }
            }
            .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 2)
                    .mask(alignment: .top) {
                        Rectangle().frame(height: 18)
                    }
            }
            .shadow(color: AnchorPalette.deepSea.opacity(0.22), radius: 18, y: 12)
#endif
    }
}

public struct HarborBrandMark: View {
    private let size: CGFloat

    public init(size: CGFloat = 38) {
        self.size = size
    }

    public var body: some View {
#if os(iOS)
        HarborAnchorGlyph(color: AnchorIOSStyle.heading, lineWidth: max(2, size * 0.055))
            .frame(width: size * 0.52, height: size * 0.52)
            .frame(width: size, height: size)
            .background(AnchorIOSStyle.cyan.opacity(0.28), in: .circle)
            .accessibilityHidden(true)
#else
        HarborAnchorGlyph(lineWidth: max(2, size * 0.055))
            .frame(width: size * 0.52, height: size * 0.52)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.78, green: 0.97, blue: 0.91), AnchorPalette.seafoam, AnchorPalette.cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: size * 0.22, style: .continuous)
            )
            .overlay(alignment: .top) {
                Capsule()
                    .fill(.white.opacity(0.55))
                    .frame(width: size * 0.58, height: 3)
                    .padding(.top, 3)
            }
            .shadow(color: AnchorPalette.cyan.opacity(0.24), radius: 10, y: 6)
            .accessibilityHidden(true)
#endif
    }
}

public struct HarborClayAvatar: View {
    public init() {}

    public var body: some View {
#if os(iOS)
        Image(systemName: "person.fill")
            .font(.body)
            .foregroundStyle(AnchorIOSStyle.heading)
            .frame(width: 32, height: 32)
            .background(AnchorIOSStyle.cyan.opacity(0.22), in: .circle)
            .accessibilityHidden(true)
#else
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.61, green: 0.89, blue: 0.88), Color(red: 0.36, green: 0.77, blue: 0.78)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.00, green: 0.57, blue: 0.48), Color(red: 0.94, green: 0.40, blue: 0.31)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 18)
                .offset(y: 15)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.00, green: 0.84, blue: 0.74), Color(red: 0.95, green: 0.68, blue: 0.53)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 20, height: 22)
                .offset(y: 1)
                .overlay {
                    HStack(spacing: 6) {
                        Circle().fill(AnchorPalette.ink).frame(width: 2, height: 2)
                        Circle().fill(AnchorPalette.ink).frame(width: 2, height: 2)
                    }
                    .offset(y: -1)
                }

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.28, blue: 0.35), Color(red: 0.06, green: 0.18, blue: 0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 23, height: 10)
                .rotationEffect(.degrees(-5))
                .offset(y: -10)
        }
        .frame(width: 32, height: 32)
        .clipShape(.rect(cornerRadius: 15, style: .continuous))
        .overlay(alignment: .top) {
            Capsule().fill(.white.opacity(0.55)).frame(width: 24, height: 3).padding(.top, 3)
        }
        .shadow(color: AnchorPalette.coral.opacity(0.18), radius: 8, y: 5)
        .accessibilityHidden(true)
#endif
    }
}

public struct HarborAnchorControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let label: String
    private let action: () -> Void

    public init(label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some View {
#if os(iOS)
        VStack(spacing: 6) {
            Button(action: action) {
                HarborAnchorGlyph(color: AnchorIOSStyle.onAccent, lineWidth: 2.8)
                    .frame(width: 32, height: 32)
                    .frame(width: 68, height: 68)
                    .background(AnchorIOSStyle.cyan, in: .circle)
            }
            .buttonStyle(AnchorPressButtonStyle())
            .accessibilityIdentifier("anchor.note.button")
            .accessibilityLabel(label)
            .accessibilityInputLabels([Text(label)])
            Text(label)
                .font(.caption.bold())
                .foregroundStyle(AnchorIOSStyle.heading)
                .accessibilityHidden(true)
                .accessibilityIdentifier("anchor.note.label")
        }
#else
        VStack(spacing: 6) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(AnchorPalette.brandDeep.opacity(0.82))
                        .frame(width: 58, height: 58)
                        .offset(y: 4)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AnchorPalette.interaction, AnchorPalette.brandDeep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                        .overlay {
                            Circle().stroke(.white.opacity(0.22), lineWidth: 1)
                        }
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(.white.opacity(0.26))
                                .frame(width: 25, height: 3)
                                .padding(.top, 7)
                        }
                        .shadow(color: AnchorPalette.brandDeep.opacity(0.24), radius: 14, y: 9)

                    HarborAnchorGlyph(color: .white, lineWidth: 2.6)
                        .frame(width: 25, height: 25)
                }
                .frame(width: 64, height: 64)
            }
            .buttonStyle(HarborAnchorButtonStyle())
            .accessibilityIdentifier("anchor.note.button")
            .accessibilityLabel(label)
            .accessibilityInputLabels([Text(label)])

            Text(label)
                .font(.caption.bold())
                .foregroundStyle(AnchorPalette.brandDeep)
                .accessibilityHidden(true)
                .accessibilityIdentifier("anchor.note.label")
        }
#endif
    }
}

public struct HarborPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
#if os(iOS)
        AnchorIOSPrimaryButtonStyle().makeBody(configuration: configuration)
#else
        configuration.label
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, AnchorSpacing.medium)
            .background {
                if isEnabled {
                    LinearGradient(
                        colors: [AnchorPalette.interaction, AnchorPalette.brandDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    AnchorPalette.secondaryText.opacity(0.55)
                }
            }
            .clipShape(.rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(isEnabled ? 0.18 : 0.08), lineWidth: 1)
            }
            .shadow(
                color: AnchorPalette.brandDeep.opacity(configuration.isPressed ? 0.10 : 0.20),
                radius: configuration.isPressed ? 4 : 10,
                y: configuration.isPressed ? 2 : 6
            )
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(reduceMotion ? nil : AnchorMotion.press, value: configuration.isPressed)
#endif
    }
}

public struct HarborWaveDivider: View {
    public init() {}

    public var body: some View {
        HStack(spacing: -10) {
            ForEach(0 ..< 3, id: \.self) { _ in
                Image(systemName: "water.waves")
                    .font(.caption)
            }
        }
        .foregroundStyle(AnchorPalette.cyan.opacity(0.16))
        .frame(maxWidth: .infinity, minHeight: 12)
        .accessibilityHidden(true)
    }
}

public struct HarborInputSurface: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    public init() {}

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AnchorPalette.fluoriteSurface, in: .rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        contrast == .increased ? AnchorPalette.brandDeep.opacity(0.55) : AnchorPalette.fluoriteBorder,
                        lineWidth: contrast == .increased ? 2 : 1
                    )
            }
    }
}

private struct HarborAnchorButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
            .offset(y: reduceMotion || !configuration.isPressed ? 0 : 2)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : AnchorMotion.press, value: configuration.isPressed)
    }
}

public extension View {
    func harborInputSurface() -> some View {
        modifier(HarborInputSurface())
    }
}
