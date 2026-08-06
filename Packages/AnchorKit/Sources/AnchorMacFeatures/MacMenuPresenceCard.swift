#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacMenuPresenceCard: View {
    let session: AnchorSession

    private var changes: [ReturnChange] {
        session.returnSummary?.changes ?? []
    }

    private var awaySince: Date? {
        session.returnSummary?.awaySince ?? session.snapshots.first?.createdAt
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            HStack(alignment: .top, spacing: AnchorSpacing.small) {
                statusMark

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusKicker)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(statusTint)
                        .textCase(.uppercase)
                    Text(statusTitle)
                        .font(.headline.bold())
                        .foregroundStyle(AnchorPalette.ink)
                    Text(statusDetail)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AnchorSpacing.small)
            }

            if session.presence == .returning, !changes.isEmpty {
                returnChanges
            }

            if let awaySince, session.presence == .away || session.presence == .returning {
                HStack(spacing: AnchorSpacing.xSmall) {
                    Image(systemName: "clock")
                        .accessibilityHidden(true)
                    Text(awaySince, style: .relative)
                }
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(AnchorPalette.secondaryInk)
            }

        }
        .padding(AnchorSpacing.medium)
        .background(statusTint.opacity(0.09), in: .rect(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(statusTint.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.menu.presence")
    }

    private var statusMark: some View {
        Image(systemName: statusSymbol)
            .font(.body.weight(.bold))
            .foregroundStyle(statusTint)
            .frame(width: 34, height: 34)
            .background(statusTint.opacity(0.14), in: .circle)
            .accessibilityHidden(true)
    }

    private var returnChanges: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
            HStack(spacing: AnchorSpacing.xSmall) {
                Image(systemName: "arrow.up.right")
                    .accessibilityHidden(true)
                Text(L10n.returnChanges)
                    .font(.caption.weight(.bold))
                Spacer(minLength: AnchorSpacing.small)
                Text("\(changes.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
            }
            .foregroundStyle(AnchorPalette.deepSea)

            ForEach(changes.prefix(2)) { change in
                HStack(alignment: .top, spacing: AnchorSpacing.xSmall) {
                    Image(systemName: changeSymbol(change.kind))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(changeTint(change.kind))
                        .frame(width: 18)
                        .accessibilityHidden(true)
                    Text(change.title)
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .lineLimit(2)
                }
            }
        }
        .padding(AnchorSpacing.small)
        .background(AnchorPalette.paper.opacity(0.72), in: .rect(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mac.menu.return.changes")
    }

    private var statusKicker: String {
        switch session.presence {
        case .away: L10n.currentAnchor
        case .returning: L10n.memoryTrace
        case .handingOff: L10n.handoff
        case .unknown: L10n.connections
        case .atDesk: L10n.currentWork
        }
    }

    private var statusTitle: String {
        switch session.presence {
        case .away: L10n.away
        case .returning: L10n.returning
        case .handingOff: L10n.handoffSecured
        case .unknown: L10n.connectionUnknown
        case .atDesk: L10n.currentWork
        }
    }

    private var statusDetail: String {
        switch session.presence {
        case .away: L10n.awayDetail
        case .returning: L10n.returnDetail
        case .handingOff: L10n.handoffDetail
        case .unknown: L10n.connectionUnknownDetail
        case .atDesk: L10n.currentWork
        }
    }

    private var statusSymbol: String {
        switch session.presence {
        case .away: "moon.stars.fill"
        case .returning: "arrow.uturn.left.circle.fill"
        case .handingOff: "lock.circle.fill"
        case .unknown: "questionmark.circle.fill"
        case .atDesk: "checkmark.circle.fill"
        }
    }

    private var statusTint: Color {
        switch session.presence {
        case .away: AnchorPalette.cyan
        case .returning: AnchorPalette.mintInk
        case .handingOff: AnchorPalette.sourceInk("sand")
        case .unknown: AnchorPalette.coral
        case .atDesk: AnchorPalette.mintInk
        }
    }

    private func changeSymbol(_ kind: ProcessEventKind) -> String {
        switch kind {
        case .decisionRequired: "exclamationmark.bubble.fill"
        case .completed, .decisionResolved: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .outputReady: "sparkles"
        default: "arrow.up.right"
        }
    }

    private func changeTint(_ kind: ProcessEventKind) -> Color {
        switch kind {
        case .decisionRequired, .failed: AnchorPalette.coral
        case .completed, .decisionResolved: AnchorPalette.mintInk
        case .outputReady: AnchorPalette.periwinkle
        default: AnchorPalette.deepSea
        }
    }
}
#endif
