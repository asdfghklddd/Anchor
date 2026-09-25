#if os(macOS)
import AnchorDesign
import AppKit
import SwiftUI

struct MacPairingCodeView: View {
    let pairingCode: String
    @State private var pairingCodeCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
            HStack(alignment: .center, spacing: AnchorSpacing.small) {
                Label(L10n.pairingCode, systemImage: "number")
                    .font(.callout.weight(.semibold))
                Spacer(minLength: AnchorSpacing.small)
                Text(pairingCode)
                    .font(.title2.bold().monospacedDigit())
                    .textSelection(.enabled)
                    .accessibilityLabel(L10n.pairingCode)
                    .accessibilityValue(Text(pairingCode))
                Button(L10n.copyPairingCode, systemImage: "doc.on.doc", action: copyPairingCode)
                    .controlSize(.small)
                    .accessibilityIdentifier("mac.pairing.copy")
            }
            .accessibilityElement(children: .contain)
            Text(L10n.pairingHint)
                .font(.caption)
                .foregroundStyle(.secondary)
            if pairingCodeCopied {
                Label(L10n.pairingCodeCopied, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.mintInk)
                    .accessibilityIdentifier("mac.pairing.copied")
            }
        }
    }

    private func copyPairingCode() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pairingCode, forType: .string)
        pairingCodeCopied = true
    }
}
#endif
