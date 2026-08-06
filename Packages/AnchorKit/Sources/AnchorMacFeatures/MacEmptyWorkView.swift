#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacEmptyWorkView: View {
    let projection: SessionProjection
    let onOpenTimeline: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: AnchorSpacing.xLarge) {
                emptyState
                workspaceStatus
                privacyFooter
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, AnchorSpacing.xLarge)
            .padding(.vertical, 56)
            .frame(maxWidth: .infinity)
        }
        .background(AnchorPalette.paper)
        .navigationTitle(L10n.currentWork)
        .accessibilityIdentifier("mac.empty.screen")
    }

    private var emptyState: some View {
        VStack(spacing: AnchorSpacing.medium) {
            HarborBrandMark(size: 64)

            VStack(spacing: AnchorSpacing.small) {
                Text(L10n.focusSession)
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.deepSea)
                    .textCase(.uppercase)
                Text(L10n.emptyTitle)
                    .font(.largeTitle.bold())
                    .foregroundStyle(AnchorPalette.ink)
                    .multilineTextAlignment(.center)
                Text(L10n.emptyDetail)
                    .font(.title3)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: AnchorSpacing.small) {
                    pairButton
                    timelineButton
                }

                VStack(spacing: AnchorSpacing.small) {
                    pairButton
                    timelineButton
                }
            }
        }
    }

    private var workspaceStatus: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                connectionStatusItem
                Divider()
                    .padding(.vertical, AnchorSpacing.small)
                processStatusItem
                Divider()
                    .padding(.vertical, AnchorSpacing.small)
                decisionStatusItem
            }

            VStack(spacing: 0) {
                connectionStatusItem
                Divider()
                processStatusItem
                Divider()
                decisionStatusItem
            }
        }
        .padding(.vertical, AnchorSpacing.small)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(AnchorPalette.ink.opacity(0.08), lineWidth: 1)
        }
    }

    private var privacyFooter: some View {
        HStack(alignment: .top, spacing: AnchorSpacing.small) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(AnchorPalette.mintInk)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.localOnly)
                    .font(.callout.bold())
                    .foregroundStyle(AnchorPalette.ink)
                Text(L10n.localOnlyDetail)
                    .font(.callout)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
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
        case .disconnected, .permissionDenied, .failed: AnchorPalette.coral
        case .unavailable: AnchorPalette.secondaryInk
        }
    }

    private var pairButton: some View {
        Button(L10n.pairDevice, systemImage: "link", action: onOpenSettings)
            .buttonStyle(.borderedProminent)
            .tint(AnchorPalette.deepSea)
            .controlSize(.large)
            .keyboardShortcut(",")
            .accessibilityIdentifier("mac.empty.pair.button")
    }

    private var timelineButton: some View {
        Button(L10n.timeline, systemImage: "waveform.path.ecg", action: onOpenTimeline)
            .buttonStyle(.bordered)
            .controlSize(.large)
    }

    private var connectionStatusItem: some View {
        MacEmptyStatusItem(
            title: L10n.macConnection,
            value: connectionLabel,
            symbol: connectionSymbol,
            tint: connectionTint
        )
    }

    private var processStatusItem: some View {
        MacEmptyStatusItem(
            title: L10n.processes,
            value: "0",
            symbol: "square.grid.2x2",
            tint: AnchorPalette.cyan
        )
    }

    private var decisionStatusItem: some View {
        MacEmptyStatusItem(
            title: L10n.decisions,
            value: "0",
            symbol: "exclamationmark.bubble",
            tint: AnchorPalette.sand
        )
    }
}

private struct MacEmptyStatusItem: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        HStack(spacing: AnchorSpacing.small) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundStyle(AnchorPalette.ink)
                    .lineLimit(1)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, AnchorSpacing.medium)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
#endif
