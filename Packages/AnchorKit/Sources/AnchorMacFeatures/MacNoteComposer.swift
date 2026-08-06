#if os(macOS)
import AnchorDesign
import SwiftUI

struct MacNoteComposer: View {
    @Binding var note: String
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNoteFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.large) {
            HStack {
                VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                    Text(L10n.anchorCaptureHeadline)
                        .font(.title2.bold())
                    Text(L10n.currentSnapshot)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            Button(L10n.close, action: dismiss.callAsFunction)
                .buttonStyle(.borderless)
                .keyboardShortcut(.cancelAction)
            }

            Text(L10n.momentToRemember)
                .font(.headline)

            TextField(L10n.notePlaceholder, text: $note, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(4...8)
                .frame(minHeight: 110, alignment: .top)
                .focused($isNoteFocused)
                .accessibilityIdentifier("mac.note.input")

            HStack {
                Text(L10n.setupHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button(L10n.dropAnchor, action: onSave)
                    .buttonStyle(.borderedProminent)
                    .tint(AnchorPalette.deepSea)
                    .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("mac.note.save")
            }
        }
        .padding(AnchorSpacing.xLarge)
        .frame(minWidth: 420, idealWidth: 560, maxWidth: 680)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.note.composer")
        .task {
            isNoteFocused = true
        }
    }
}
#endif
