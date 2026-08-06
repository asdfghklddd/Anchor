#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacSourceHealthSummary: View {
    let projection: SessionProjection

    private var sourceCount: Int {
        guard let processes = projection.session?.processes else { return 0 }
        return Set(processes.map(\.sourceName)).count
    }

    private var connectionLabel: String {
        switch projection.connection {
        case .connected: L10n.connected
        case .pairing: L10n.pairDevice
        case .disconnected: L10n.disconnected
        case .unavailable: L10n.unknown
        case .permissionDenied: L10n.permissionDenied
        case .failed: L10n.actionFailed
        }
    }

    private var connectionSymbol: String {
        switch projection.connection {
        case .connected: "checkmark.circle.fill"
        case .pairing: "arrow.triangle.2.circlepath"
        case .disconnected: "wifi.slash"
        case .unavailable: "questionmark.circle"
        case .permissionDenied: "lock.slash"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var connectionTint: Color {
        switch projection.connection {
        case .connected: AnchorPalette.mintInk
        case .pairing: AnchorPalette.sourceInk("sand")
        case .disconnected, .permissionDenied, .failed: AnchorPalette.sourceInk("coral")
        case .unavailable: AnchorPalette.secondaryInk
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                    sourceHeading
                    Spacer(minLength: AnchorSpacing.medium)
                    connectionStatus
                }

                VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                    sourceHeading
                    connectionStatus
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: AnchorSpacing.small) {
                    sourceCountMetric
                    attentionMetric
                    updatedMetric
                }

                VStack(spacing: AnchorSpacing.small) {
                    sourceCountMetric
                    attentionMetric
                    updatedMetric
                }
            }
        }
        .padding(AnchorSpacing.large)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AnchorPalette.ink.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mac.sources.summary")
    }

    private var sourceHeading: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
            Text(L10n.sourceHealth)
                .font(.caption.weight(.bold))
                .foregroundStyle(AnchorPalette.deepSea)
                .textCase(.uppercase)
            Text(L10n.connections)
                .font(.title2.bold())
                .foregroundStyle(AnchorPalette.ink)
        }
    }

    private var connectionStatus: some View {
        VStack(alignment: .trailing, spacing: AnchorSpacing.xSmall) {
            Label(connectionLabel, systemImage: connectionSymbol)
                .font(.callout.weight(.semibold))
                .foregroundStyle(connectionTint)
            if projection.isStale {
                Label(L10n.stale, systemImage: "clock.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.sourceInk("sand"))
            }
        }
    }

    private var sourceCountMetric: some View {
        MacSourceMetric(
            value: Text(sourceCount, format: .number),
            label: L10n.sources,
            tint: AnchorPalette.cyan
        )
    }

    private var attentionMetric: some View {
        MacSourceMetric(
            value: Text(projection.openDecisions.count, format: .number),
            label: L10n.attentionNeeded,
            tint: projection.openDecisions.isEmpty ? AnchorPalette.seafoam : AnchorPalette.sand
        )
    }

    private var updatedMetric: some View {
        MacSourceMetric(
            value: updatedValue,
            label: L10n.lastUpdated,
            tint: AnchorPalette.periwinkle
        )
    }

    private var updatedValue: Text {
        guard let dataObservedAt = projection.dataObservedAt else {
            return Text(L10n.unknown)
        }
        return Text(dataObservedAt, style: .relative)
    }
}

private struct MacSourceMetric: View {
    let value: Text
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            value
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AnchorSpacing.small)
        .padding(.vertical, AnchorSpacing.xSmall)
        .background(tint.opacity(0.10), in: .rect(cornerRadius: 12, style: .continuous))
    }
}
#endif
