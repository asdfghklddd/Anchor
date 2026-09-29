#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct HostedTasksView: View {
    let model: AnchorSessionModel
    let onCreate: () -> Void
    let onEdit: () -> Void
    let onNote: () -> Void
    let onFinish: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(L10n.setupNewWork, systemImage: "plus", action: onCreate)
                        .accessibilityIdentifier("hosted.tasks.create")
                }
                ForEach(model.projection.hostedSessions) { task in
                    Section(task.goal.title) {
                        Text(L10n.processCount(task.taskProcesses.count))
                        action(L10n.editGoal, task: task, action: onEdit)
                        action(L10n.anchorNote, task: task, action: onNote)
                        action(L10n.finish, task: task, action: onFinish)
                    }
                    .listRowBackground(AnchorIOSStyle.surface)
                }
            }
            .anchorIOSListSurface()
            .navigationTitle(AnchorStrings.value("home.tasks.manage", default: "Manage hosted tasks"))
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.done) { dismiss() } } }
        }
    }

    private func action(_ label: String, task: AnchorSession, action: @escaping () -> Void) -> some View {
        Button(label) {
            Task { if await model.selectHostedTask(task.id) { action() } }
        }
    }
}
#endif
