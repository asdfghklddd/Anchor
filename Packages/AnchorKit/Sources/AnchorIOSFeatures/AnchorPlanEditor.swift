#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Edits a live plan in place: rename, reorder, remove and add steps. Kept steps
/// keep their identity, so a checked step stays checked wherever it moves.
struct AnchorPlanEditor: View {
    @State private var items: [AnchorUserPlan.Step]
    @State private var newStep = ""
    @FocusState private var addingStep: Bool
    @Environment(\.dismiss) private var dismiss
    let onSave: ([AnchorUserPlan.Step]) -> Void

    init(plan: AnchorUserPlan, onSave: @escaping ([AnchorUserPlan.Step]) -> Void) {
        _items = State(initialValue: plan.items)
        self.onSave = onSave
    }

    private var keptCount: Int {
        items.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach($items) { $item in
                        HStack(spacing: 10) {
                            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(item.isDone ? AnchorStateTone.done.ink : AnchorIOSStyle.secondaryText)
                                .accessibilityHidden(true)
                            TextField(PlanText.stepPlaceholder, text: $item.text, axis: .vertical)
                                .accessibilityValue(item.isDone ? PlanText.doneState : PlanText.openState)
                        }
                    }
                    .onDelete { items.remove(atOffsets: $0) }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                } footer: {
                    Text(PlanText.editHint)
                }
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(AnchorIOSStyle.action)
                            .accessibilityHidden(true)
                        TextField(PlanText.addStepPlaceholder, text: $newStep, axis: .vertical)
                            .focused($addingStep)
                            .submitLabel(.done)
                            .onSubmit(addStep)
                            .accessibilityIdentifier("plan.editor.add")
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(PlanText.editTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        addStep()
                        onSave(items)
                        dismiss()
                    }
                    .disabled(keptCount == 0 && newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("plan.editor.save")
                }
            }
        }
        .accessibilityIdentifier("plan.editor")
    }

    private func addStep() {
        let text = newStep.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        items.append(AnchorUserPlan.Step(text: text))
        newStep = ""
        addingStep = true
    }
}
#endif
