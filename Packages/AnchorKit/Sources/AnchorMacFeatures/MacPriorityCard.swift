#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacPriorityCard: View {
    let session: AnchorSession
    let onOpenProcess: (UUID) -> Void

    private var openDecision: Decision? {
        session.decisions.first(where: { $0.status == .open })
    }

    private var blockedProcess: AnchorProcess? {
        session.processes.first(where: { $0.status == .failed || $0.status == .blocked })
    }

    private var attentionProcess: AnchorProcess? {
        session.processes.first(where: { $0.status == .needsDecision })
    }

    private var tint: Color {
        if openDecision != nil || attentionProcess != nil { return AnchorPalette.sand }
        if blockedProcess != nil { return AnchorPalette.coral }
        return AnchorPalette.seafoam
    }

    private var iconTint: Color {
        if openDecision != nil || attentionProcess != nil { return AnchorPalette.sourceInk("sand") }
        if blockedProcess != nil { return AnchorPalette.sourceInk("coral") }
        return AnchorPalette.mintInk
    }

    private var symbol: String {
        if openDecision != nil || attentionProcess != nil { return "exclamationmark.bubble.fill" }
        if blockedProcess != nil { return "exclamationmark.triangle.fill" }
        return "checkmark.circle.fill"
    }

    var body: some View {
        HStack(alignment: .top, spacing: AnchorSpacing.medium) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(iconTint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.18), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                Text(kicker)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AnchorPalette.deepSea)
                    .textCase(.uppercase)
                Text(headline)
                    .font(.headline)
                    .foregroundStyle(AnchorPalette.ink)
                    .lineLimit(2)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AnchorSpacing.medium)

            if let processID {
                Button(L10n.openCurrentProcess, systemImage: "arrow.up.right") {
                    onOpenProcess(processID)
                }
                .buttonStyle(.borderedProminent)
                .tint(AnchorPalette.deepSea)
                .controlSize(.small)
                .accessibilityIdentifier("mac.priority.open")
            }
        }
        .padding(AnchorSpacing.medium)
        .background(tint.opacity(0.11), in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tint.opacity(0.32), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.priority.card")
    }

    private var processID: UUID? {
        openDecision?.processID ?? attentionProcess?.id ?? blockedProcess?.id
    }

    private var kicker: String {
        if openDecision != nil || attentionProcess != nil { return L10n.attentionNeeded }
        if let blockedProcess { return L10n.status(blockedProcess.status) }
        return L10n.noAttentionNeeded
    }

    private var headline: String {
        if let openDecision { return openDecision.title }
        if let attentionProcess { return attentionProcess.title }
        if let blockedProcess { return blockedProcess.title }
        if session.processes.allSatisfy({ $0.status == .completed }) {
            return L10n.completed
        }
        return L10n.focusSummary(
            running: session.processes.filter { $0.status == .running }.count,
            attention: 0
        )
    }

    private var detail: String {
        if let openDecision { return openDecision.prompt }
        if let attentionProcess { return attentionProcess.detail }
        if let blockedProcess { return blockedProcess.detail }
        return L10n.noAttentionNeeded
    }
}
#endif
