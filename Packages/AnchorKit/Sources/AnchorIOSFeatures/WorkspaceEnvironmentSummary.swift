#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Keeps ambient Mac application state visible without treating it as task work.
struct WorkspaceEnvironmentSummary: View {
    let processes: [AnchorProcess]
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            AnchorCard(tint: AnchorPalette.periwinkle) {
                HStack(spacing: AnchorSpacing.small) {
                    Image(systemName: "macwindow")
                        .font(.title2)
                        .foregroundStyle(AnchorPalette.interaction)
                        .frame(width: 44, height: 44)
                        .background(AnchorPalette.softBlue.opacity(0.6), in: .circle)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.sourceSetupMacApps)
                            .font(.headline.bold())
                            .foregroundStyle(AnchorPalette.brandDeep)
                        Text(L10n.sourceSetupMacAppsDetail)
                            .font(.caption)
                            .foregroundStyle(AnchorPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L10n.processCount(processes.count))
                            .font(.caption.bold().monospacedDigit())
                            .foregroundStyle(AnchorPalette.interaction)
                    }

                    Spacer(minLength: AnchorSpacing.small)
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundStyle(AnchorPalette.secondaryText)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("processes.environment.summary")
    }
}
#endif
