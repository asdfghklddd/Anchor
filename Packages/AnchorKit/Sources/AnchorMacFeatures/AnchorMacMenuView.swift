#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

public struct AnchorMacMenuView: View {
    private let model: AnchorSessionModel
    private let onOpenDetails: () -> Void
    private let onQuit: () -> Void

    @State private var note = ""

    public init(
        model: AnchorSessionModel,
        onOpenDetails: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.model = model
        self.onOpenDetails = onOpenDetails
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            if let session = model.projection.session {
                header(session)
                Divider()
                statusSummary(session)
                if let decision = model.projection.openDecisions.first {
                    decisionNotice(decision)
                }
                Divider()
                noteCapture
            } else {
                ContentUnavailableView(L10n.emptyTitle, systemImage: "scope", description: Text(L10n.emptyDetail))
            }

            Button(action: onOpenDetails) {
                Label(L10n.openDetails, systemImage: "macwindow")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .keyboardShortcut("o")
            Divider()
            Button(L10n.quit, action: onQuit)
                .keyboardShortcut("q")
        }
        .padding(AnchorSpacing.medium)
        .frame(width: 340)
        .task { model.start() }
    }

    private func header(_ session: AnchorSession) -> some View {
        HStack(spacing: AnchorSpacing.small) {
            AnchorMark(size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.goal.title)
                    .font(.headline)
                    .lineLimit(2)
                Label(connectionLabel, systemImage: connectionSymbol)
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private func statusSummary(_ session: AnchorSession) -> some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            HStack {
                Label(L10n.processCount(session.processes.count), systemImage: "square.grid.2x2")
                Spacer()
                Label("\(model.projection.openDecisions.count)", systemImage: "exclamationmark.bubble")
                    .accessibilityLabel(L10n.decisionCount(model.projection.openDecisions.count))
            }
            .font(.subheadline.weight(.semibold))
            if let progress = model.projection.overallProgress {
                AnchorProgress(value: progress, tint: AnchorPalette.seafoam)
            }
        }
    }

    private func decisionNotice(_ decision: Decision) -> some View {
        Button(action: onOpenDetails) {
            HStack(alignment: .top, spacing: AnchorSpacing.small) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundStyle(AnchorPalette.deepSea)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.attentionNeeded).font(.caption.bold())
                    Text(decision.title).font(.subheadline.weight(.semibold))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .accessibilityHidden(true)
            }
            .foregroundStyle(AnchorPalette.ink)
            .padding(AnchorSpacing.small)
            .background(AnchorPalette.sand.opacity(0.28), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var noteCapture: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            TextField(L10n.anchorNotePrompt, text: $note)
                .textFieldStyle(.roundedBorder)
                .onSubmit { saveNote() }
            Button(action: saveNote) {
                Label(L10n.anchorNote, systemImage: "scope")
                    .frame(maxWidth: .infinity)
            }
            .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var connectionLabel: String {
        model.projection.connection == .connected ? L10n.connected : L10n.disconnected
    }
    private var connectionSymbol: String {
        model.projection.connection == .connected ? "checkmark.circle.fill" : "wifi.slash"
    }
    private func saveNote() {
        let captured = note
        note = ""
        Task { await model.addNote(captured) }
    }
}
#endif
