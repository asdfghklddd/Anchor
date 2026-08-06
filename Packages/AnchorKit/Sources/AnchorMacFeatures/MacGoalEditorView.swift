#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacGoalEditorView: View {
    let model: AnchorSessionModel
    let goal: AnchorGoal

    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var title: String
    @State private var criteria: String
    @State private var note: String
    @State private var saveError: String?
    @State private var isSaving = false

    private enum Field: Hashable {
        case title
        case criteria
        case note
    }

    init(model: AnchorSessionModel, goal: AnchorGoal) {
        self.model = model
        self.goal = goal
        _title = State(initialValue: goal.title)
        _criteria = State(initialValue: goal.completionCriteria)
        _note = State(initialValue: goal.note)
    }

    var body: some View {
        Form {
            Section(L10n.currentGoal) {
                TextField(L10n.goalTitle, text: $title, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($focusedField, equals: .title)
                    .accessibilityIdentifier("mac.goal.editor.title")
                TextField(L10n.completionCriteria, text: $criteria, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($focusedField, equals: .criteria)
                    .accessibilityIdentifier("mac.goal.editor.criteria")
                TextField(L10n.contextNote, text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focusedField, equals: .note)
                    .accessibilityIdentifier("mac.goal.editor.note")
            }

            Section {
                Label(L10n.setupHint, systemImage: "mic.fill")
                    .font(.callout)
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }

            if let saveError {
                Section {
                    Label(saveError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(AnchorPalette.coral)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.editGoal)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.cancel, action: dismiss.callAsFunction)
                    .keyboardShortcut(.cancelAction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.save, action: save)
                    .disabled(!canSave || isSaving)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("mac.goal.editor.save")
            }
        }
        .frame(minWidth: 540, idealWidth: 620, minHeight: 360)
        .accessibilityIdentifier("mac.goal.editor")
        .task {
            focusedField = .title
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        guard canSave else { return }
        isSaving = true
        saveError = nil

        Task {
            let succeeded = await model.send(
                .updateGoal(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    completionCriteria: criteria.trimmingCharacters(in: .whitespacesAndNewlines),
                    note: note.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
            if succeeded {
                dismiss()
            } else {
                saveError = model.lastError ?? L10n.actionFailed
                isSaving = false
            }
        }
    }
}
#endif
