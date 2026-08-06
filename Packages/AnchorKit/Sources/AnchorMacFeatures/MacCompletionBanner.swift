#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacCompletionBanner: View {
    let session: AnchorSession
    let onResume: () -> Void

    private var completedProcessCount: Int {
        session.processes.filter { $0.status == .completed }.count
    }

    var body: some View {
        HStack(spacing: AnchorSpacing.medium) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.completed)
                        .font(.headline)
                    Text(L10n.sessionSummary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AnchorPalette.mintInk)
            }

            Spacer(minLength: AnchorSpacing.medium)

            VStack(alignment: .trailing, spacing: 2) {
                Text(completedProcessCount, format: .number)
                    .font(.title3.bold().monospacedDigit())
                Text(L10n.completedWork)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(L10n.resume, systemImage: "arrow.counterclockwise", action: onResume)
                .buttonStyle(.borderedProminent)
                .tint(AnchorPalette.deepSea)
                .accessibilityIdentifier("mac.completion.resume")
        }
        .padding(AnchorSpacing.medium)
        .background(AnchorPalette.seafoam.opacity(0.14), in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AnchorPalette.seafoam.opacity(0.40), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.completion.banner")
    }
}
#endif
