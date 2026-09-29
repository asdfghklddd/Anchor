#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacSidebar: View {
    let selection: MacSection
    let projection: SessionProjection
    let onSelect: (MacSection) -> Void
    let onCollapse: () -> Void

    @FocusState private var focusedSection: MacSection?

    var body: some View {
        GlassEffectContainer(spacing: AnchorSpacing.small) {
            VStack(spacing: AnchorSpacing.small) {
                ForEach(MacSection.allCases) { section in
                    MacSidebarRow(
                        section: section,
                        isSelected: selection == section,
                        badge: section == .current && !projection.openDecisions.isEmpty
                            ? "\(projection.openDecisions.count)" : nil,
                        action: { onSelect(section) }
                    )
                    .focused($focusedSection, equals: section)
                }
            }
        }
        .frame(width: 192)
        .onExitCommand(perform: onCollapse)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.sidebar.drawer")
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
                    .font(.body.bold())
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(section.title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                Spacer(minLength: AnchorSpacing.small)
                if let badge {
                    Text(badge)
                        .font(.caption.bold().monospacedDigit())
                        // The badge keeps a fixed yellow fill in both appearances.
                        .foregroundStyle(AnchorPalette.deepSea)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(AnchorPalette.sand, in: .capsule)
                }
            }
            .foregroundStyle(isSelected ? AnchorPalette.brandDeep : AnchorPalette.secondaryInk)
            .padding(.horizontal, AnchorSpacing.small)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .macLiquidGlass(
                tint: isSelected ? AnchorPalette.softBlue.opacity(0.34) : nil,
                in: .rect(cornerRadius: 16)
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(AnchorPalette.interaction)
                        .frame(width: 3, height: 24)
                        .padding(.leading, 2)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("mac.section.\(section.rawValue)")
    }
}
#endif
