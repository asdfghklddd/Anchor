import SwiftUI

public struct HarborBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                AnchorPalette.paper

                Circle()
                    .fill(AnchorPalette.cyan.opacity(colorScheme == .dark ? 0.10 : 0.08))
                    .frame(width: 130, height: 130)
                    .blur(radius: 34)
                    .position(x: 20, y: proxy.size.height * 0.18)

                Circle()
                    .fill(AnchorPalette.coral.opacity(colorScheme == .dark ? 0.09 : 0.06))
                    .frame(width: 150, height: 150)
                    .blur(radius: 42)
                    .position(x: proxy.size.width - 12, y: proxy.size.height * 0.42)

                Circle()
                    .stroke(AnchorPalette.cyan.opacity(0.08), lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .position(x: 22, y: proxy.size.height * 0.62)

                Image(systemName: "sailboat")
                    .font(.title2)
                    .foregroundStyle(AnchorPalette.ink.opacity(0.045))
                    .rotationEffect(.degrees(5))
                    .position(x: proxy.size.width - 32, y: proxy.size.height * 0.74)
            }
        }
        .accessibilityHidden(true)
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
    }
}

public struct HarborBrandMark: View {
    private let size: CGFloat

    public init(size: CGFloat = 38) {
        self.size = size
    }

    public var body: some View {
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
    }
}

public struct HarborClayAvatar: View {
    public init() {}

    public var body: some View {
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
    }
}

public struct HarborAnchorControl: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRippling = false

    private let label: String
    private let action: () -> Void

    public init(label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    public var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .stroke(AnchorPalette.cyan.opacity(0.25), lineWidth: 2)
                        .frame(width: 76, height: 76)
                        .scaleEffect(isRippling ? 1.18 : 0.82)
                        .opacity(isRippling ? 0 : 0.55)

                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.79, green: 0.97, blue: 0.91), AnchorPalette.seafoam, AnchorPalette.cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)
                        .overlay {
                            Circle().stroke(AnchorPalette.cyan.opacity(0.30), lineWidth: 4).padding(-7)
                        }
                        .overlay(alignment: .top) {
                            Capsule().fill(.white.opacity(0.45)).frame(width: 32, height: 9).padding(.top, 8)
                        }
                        .shadow(color: Color(red: 0.18, green: 0.51, blue: 0.57), radius: 0, y: 7)
                        .shadow(color: AnchorPalette.deepSea.opacity(0.24), radius: 14, y: 12)

                    HarborAnchorGlyph(lineWidth: 2.8)
                        .frame(width: 27, height: 27)
                }
                .frame(width: 78, height: 68)
            }
            .buttonStyle(HarborAnchorButtonStyle())
            .accessibilityIdentifier("anchor.note.button")
            .accessibilityLabel(label)
            .accessibilityInputLabels([Text(label)])

            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(AnchorPalette.ink)
                .accessibilityHidden(true)
                .accessibilityIdentifier("anchor.note.label")
        }
        .task {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 2.8).repeatForever(autoreverses: false)) {
                isRippling = true
            }
        }
    }
}

public struct HarborPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, AnchorSpacing.medium)
            .background(
                LinearGradient(
                    colors: isEnabled
                        ? [Color(red: 0.11, green: 0.32, blue: 0.42), AnchorPalette.deepSea]
                        : [
                            Color(red: 0.31, green: 0.37, blue: 0.39),
                            Color(red: 0.23, green: 0.30, blue: 0.33),
                        ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: .capsule
            )
            .overlay(alignment: .top) {
                Capsule().fill(.white.opacity(0.18)).frame(height: 2)
            }
            .shadow(color: AnchorPalette.deepSea.opacity(0.24), radius: 10, y: configuration.isPressed ? 3 : 7)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .offset(y: reduceMotion || !configuration.isPressed ? 0 : 2)
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
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
            .background(AnchorPalette.surface, in: .rect(cornerRadius: 18, style: .continuous))
            .overlay {
                if contrast == .increased {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AnchorPalette.ink.opacity(0.45), lineWidth: 2)
                }
            }
            .shadow(color: AnchorPalette.ink.opacity(0.07), radius: 3, y: 2)
            .shadow(color: AnchorPalette.ink.opacity(0.06), radius: 10, y: 7)
    }
}

private struct HarborAnchorButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
            .offset(y: reduceMotion || !configuration.isPressed ? 0 : 5)
            .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: configuration.isPressed)
    }
}

public extension View {
    func harborInputSurface() -> some View {
        modifier(HarborInputSurface())
    }
}
