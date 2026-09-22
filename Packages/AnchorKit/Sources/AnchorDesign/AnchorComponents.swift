import AnchorCore
import SwiftUI

public struct AnchorCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let content: Content
    private let tint: Color?

    public init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    public var body: some View {
#if os(iOS)
        content
            .padding(AnchorSpacing.medium)
            .fluoriteSurface(
                border: tint.map { $0.opacity(0.32) } ?? AnchorPalette.fluoriteBorder,
                cornerRadius: 14
            )
#else
        content
            .padding(AnchorSpacing.medium)
            .background {
                if reduceTransparency {
                    AnchorPalette.surface
                } else {
                    AnchorPalette.surface.opacity(0.94)
                }
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill((tint ?? .white).opacity(0.42))
                    .frame(height: 2)
                    .padding(.horizontal, AnchorSpacing.large)
            }
            .clipShape(.rect(cornerRadius: 26, style: .continuous))
            .shadow(color: (tint ?? AnchorPalette.ink).opacity(0.12), radius: 18, y: 9)
#endif
    }
}

public struct AnchorMark: View {
    private let size: CGFloat

    public init(size: CGFloat = 52) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.79, green: 0.97, blue: 0.91),
                            AnchorPalette.seafoam,
                            AnchorPalette.cyan,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle()
                .stroke(AnchorPalette.cyan.opacity(0.30), lineWidth: max(3, size * 0.07))
                .padding(size * 0.08)
            HarborAnchorGlyph(lineWidth: max(2, size * 0.045))
                .frame(width: size * 0.48, height: size * 0.48)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .top) {
            Capsule()
                .fill(.white.opacity(0.48))
                .frame(width: size * 0.52, height: max(3, size * 0.11))
                .padding(.top, size * 0.12)
        }
        .shadow(color: AnchorPalette.cyan.opacity(0.22), radius: size * 0.22, y: size * 0.12)
        .accessibilityHidden(true)
    }
}

/// A decorative source monogram rendered into a canvas so VoiceOver receives the
/// richer surrounding process label instead of a standalone single character.
public struct SourceMark: View {
    private let symbol: String
    private let tone: String
    private let baseSize: CGFloat
    @ScaledMetric(relativeTo: .title3) private var scale: CGFloat = 1

    public init(symbol: String, tone: String, size: CGFloat = 42) {
        self.symbol = symbol
        self.tone = tone
        baseSize = size
    }

    public var body: some View {
        let size = baseSize * scale
#if os(iOS)
        Text(symbol)
            .font(.subheadline.bold())
            .foregroundStyle(AnchorPalette.brandDeep)
            .frame(width: size, height: size)
            .background(AnchorPalette.softBlue.opacity(0.72), in: .rect(cornerRadius: size * 0.26))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.26)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.88), AnchorPalette.aiBlue.opacity(0.36)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: AnchorPalette.brandDeep.opacity(0.06), radius: 5, y: 3)
            .accessibilityHidden(true)
#else
        Text(symbol)
            .font(.subheadline.bold())
            .foregroundStyle(AnchorPalette.deepSea)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        .frame(width: size, height: size)
        .background(
            AnchorPalette.sourceMark(tone),
            in: .rect(cornerRadius: size * 0.29, style: .continuous)
        )
        .overlay(alignment: .top) {
            Capsule()
                .fill(.white.opacity(0.34))
                .frame(width: size * 0.55, height: max(2, size * 0.08))
                .padding(.top, size * 0.08)
        }
        .shadow(color: AnchorPalette.source(tone).opacity(0.24), radius: size * 0.18, y: size * 0.10)
        .accessibilityRepresentation {
            EmptyView()
        }
#endif
    }
}

public struct StatusBadge: View {
    private let status: ProcessStatus
    private let text: String
    private let decorative: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption) private var textSize: CGFloat = 12
    @ScaledMetric(relativeTo: .caption) private var badgeScale: CGFloat = 1

    public init(status: ProcessStatus, text: String, decorative: Bool = false) {
        self.status = status
        self.text = text
        self.decorative = decorative
    }

    @ViewBuilder
    public var body: some View {
        if decorative {
            Canvas { context, size in
                let capsule = Path(
                    roundedRect: CGRect(origin: .zero, size: size),
                    cornerRadius: size.height / 2
                )
                context.fill(capsule, with: .color(AnchorPalette.deepSea))
                context.stroke(capsule, with: .color(tint), lineWidth: 2 * badgeScale)

                var icon = context.resolve(Image(systemName: symbol))
                icon.shading = .color(.white)
                let iconSize = 15 * badgeScale
                context.draw(
                    icon,
                    in: CGRect(
                        x: size.height * 0.58 - iconSize / 2,
                        y: size.height / 2 - iconSize / 2,
                        width: iconSize,
                        height: iconSize
                    )
                )

                let label = context.resolve(
                    Text(text)
                        .font(.system(size: textSize, weight: .bold))
                        .foregroundStyle(.white)
                )
                context.draw(
                    label,
                    at: CGPoint(
                        x: size.height + (size.width - size.height) / 2,
                        y: size.height / 2
                    ),
                    anchor: .center
                )
            }
            .frame(width: badgeWidth, height: 32 * badgeScale)
            .accessibilityHidden(true)
        } else {
            Label(text, systemImage: symbol)
                .font(.system(size: textSize, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AnchorPalette.deepSea, in: .capsule)
                .overlay {
                    Capsule().stroke(tint, lineWidth: 2)
                }
                .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                .animation(
                    reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.micro,
                    value: status
                )
                .accessibilityRespondsToUserInteraction(false)
        }
    }

    private var badgeWidth: CGFloat {
        min(184, max(78, CGFloat(text.count) * 9 + 46)) * badgeScale
    }

    private var symbol: String {
        switch status {
        case .queued: "clock"
        case .running: "play.fill"
        case .needsDecision: "exclamationmark.bubble.fill"
        case .blocked: "pause.fill"
        case .completed: "checkmark"
        case .failed: "xmark"
        case .disconnected: "wifi.slash"
        }
    }

    private var tint: Color {
        switch status {
        case .needsDecision, .blocked: AnchorPalette.sand
        case .completed: AnchorPalette.seafoam
        case .failed, .disconnected: AnchorPalette.coral
        case .queued, .running: AnchorPalette.cyan
        }
    }
}

public struct AnchorProgress: View {
    private let value: Double
    private let tint: Color
    private let isRemote: Bool

    public init(value: Double, tint: Color, isRemote: Bool = false) {
        self.value = min(max(value, 0), 1)
        self.tint = tint
        self.isRemote = isRemote
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AnchorPalette.ink.opacity(0.10))
                Capsule()
                    .fill(isRemote ? tint.opacity(0.55) : tint)
                    .frame(width: proxy.size.width * value)
                    .overlay {
                        if isRemote {
                            StripePattern()
                                .clipShape(.capsule)
                        }
                    }
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityRespondsToUserInteraction(false)
        .accessibilityLabel(AnchorStrings.value("progress", default: "Progress"))
        .accessibilityValue(Text(value, format: .percent.precision(.fractionLength(0))))
    }
}

private struct StripePattern: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: -size.height, through: size.width, by: 8) {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
            }
            context.stroke(path, with: .color(.white.opacity(0.65)), lineWidth: 2)
        }
        .accessibilityHidden(true)
    }
}

public struct AnchorPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
#if os(iOS)
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, AnchorSpacing.medium)
            .background(
                LinearGradient(
                    colors: [AnchorPalette.interaction, AnchorPalette.brandDeep],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: .rect(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(
                color: AnchorPalette.brandDeep.opacity(configuration.isPressed ? 0.10 : 0.20),
                radius: configuration.isPressed ? 4 : 10,
                y: configuration.isPressed ? 2 : 6
            )
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.98)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(reduceMotion ? nil : AnchorMotion.press, value: configuration.isPressed)
#else
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, AnchorSpacing.medium)
            .background(AnchorPalette.deepSea, in: .capsule)
            .shadow(
                color: AnchorPalette.deepSea.opacity(0.25),
                radius: 0,
                y: reduceMotion ? 3 : (configuration.isPressed ? 2 : 5)
            )
            .offset(y: reduceMotion ? 0 : (configuration.isPressed ? 3 : 0))
            .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: configuration.isPressed)
#endif
    }
}
