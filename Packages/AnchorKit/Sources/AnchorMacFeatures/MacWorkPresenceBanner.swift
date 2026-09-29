#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacWorkPresenceBanner: View {
    let presence: PresenceStatus
    let summary: ReturnSummary?
    let onContinue: () -> Void

    var body: some View {
        HStack(spacing: AnchorSpacing.medium) {
            Image(systemName: symbol)
                .font(.title3.bold())
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.16), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: AnchorSpacing.medium)

            if presence == .away || presence == .returning {
                Button(L10n.continueWorking, action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .tint(AnchorPalette.interaction)
            }
        }
        .padding(AnchorSpacing.medium)
        .fluoriteSurface(
            fill: tint.opacity(0.10),
            border: tint.opacity(0.32),
            cornerRadius: 14
        )
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch presence {
        case .handingOff: L10n.handoff
        case .away: L10n.away
        case .returning: L10n.returning
        case .unknown, .atDesk: L10n.connectionUnknown
        }
    }

    private var detail: String {
        switch presence {
        case .handingOff: L10n.handoffDetail
        case .away: L10n.awayDetail
        case .returning: summary?.changes.first?.detail ?? L10n.returnDetail
        case .unknown, .atDesk: L10n.connectionUnknownDetail
        }
    }

    private var tint: Color {
        switch presence {
        case .returning: AnchorPalette.seafoam
        case .away, .handingOff: AnchorPalette.cyan
        case .unknown, .atDesk: AnchorPalette.sand
        }
    }

    private var symbol: String {
        switch presence {
        case .returning: "arrow.counterclockwise"
        case .away: "moon.stars.fill"
        case .handingOff: "arrow.triangle.branch"
        case .unknown, .atDesk: "questionmark.circle"
        }
    }
}
#endif
