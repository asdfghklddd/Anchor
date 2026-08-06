#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

enum MacSection: String, CaseIterable, Hashable, Identifiable {
    case current
    case timeline
    case history
    case sources
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .current: L10n.currentWork
        case .timeline: L10n.timeline
        case .history: L10n.history
        case .sources: L10n.sources
        case .settings: L10n.settings
        }
    }

    var symbol: String {
        switch self {
        case .current: "scope"
        case .timeline: "waveform.path.ecg"
        case .history: "clock.arrow.circlepath"
        case .sources: "point.3.filled.connected.trianglepath.dotted"
        case .settings: "gearshape"
        }
    }
}

struct MacSidebar: View {
    @Binding private var selection: MacSection
    private let projection: SessionProjection

    init(selection: Binding<MacSection>, projection: SessionProjection) {
        _selection = selection
        self.projection = projection
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Text(L10n.workspace)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))
                .textCase(.uppercase)
                .padding(.top, AnchorSpacing.xLarge)
                .padding(.bottom, AnchorSpacing.small)

            VStack(spacing: AnchorSpacing.xSmall) {
                ForEach(MacSection.allCases) { section in
                    MacSidebarRow(
                        section: section,
                        isSelected: selection == section,
                        badge: section == .current && projection.openDecisions.count > 0
                            ? "\(projection.openDecisions.count)"
                            : nil
                    ) {
                        selection = section
                    }
                }
            }

            Spacer(minLength: AnchorSpacing.large)
            footer
        }
        .padding(.horizontal, AnchorSpacing.medium)
        .padding(.vertical, AnchorSpacing.large)
        .frame(minWidth: 206, idealWidth: 232, maxWidth: 252, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [
                    AnchorPalette.deepSea,
                    Color(red: 0.035, green: 0.14, blue: 0.20),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var header: some View {
        HStack(spacing: AnchorSpacing.small) {
            AnchorMark(size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.appName)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                Text(L10n.focusSession)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.62))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        Label(connectionLabel, systemImage: connectionSymbol)
            .font(.callout.weight(.semibold))
            .foregroundStyle(connectionColor)
            .padding(.horizontal, AnchorSpacing.small)
            .padding(.vertical, AnchorSpacing.xSmall)
            .background(.white.opacity(0.08), in: .capsule)
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

    private var connectionColor: Color {
        switch projection.connection {
        case .connected: AnchorPalette.seafoam
        case .pairing: AnchorPalette.sand
        case .disconnected, .permissionDenied, .failed: AnchorPalette.coral
        case .unavailable: .white.opacity(0.68)
        }
    }
}

private struct MacSidebarRow: View {
    let section: MacSection
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AnchorSpacing.small) {
                Image(systemName: section.symbol)
                    .font(.body.weight(.semibold))
                    .frame(width: 22)
                Text(section.title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                Spacer(minLength: AnchorSpacing.small)
                if let badge {
                    Text(badge)
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(AnchorPalette.deepSea)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AnchorPalette.sand, in: .capsule)
                }
            }
            .foregroundStyle(isSelected ? .white : .white.opacity(0.72))
            .padding(.horizontal, AnchorSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                isSelected ? .white.opacity(0.15) : .clear,
                in: .rect(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("mac.section.\(section.rawValue)")
    }
}
#endif
