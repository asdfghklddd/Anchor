#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Read the same saved plan from current work and history, without inventing processes.
/// Where `onToggleStep` is given, the person checks off their own steps; history stays read-only.
struct AnchorSavedPlan: View {
    let goal: AnchorGoal
    var onToggleStep: ((Int, Bool) -> Void)? = nil
    @State private var images: [Data] = []
    @State private var checkedCount = 0

    var body: some View {
        if let plan = goal.userPlan {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(SetupCopy.steps).font(.headline).foregroundStyle(AnchorIOSStyle.heading)
                    Spacer(minLength: 8)
                    if !plan.steps.isEmpty {
                        Text("\(plan.doneCount)/\(plan.steps.count)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(AnchorIOSStyle.secondaryText)
                            .contentTransition(.numericText(value: Double(plan.doneCount)))
                            .accessibilityLabel(PlanCopy.stepsDone(plan.doneCount, of: plan.steps.count))
                    }
                }
                ForEach(Array(plan.steps.enumerated()), id: \.offset) { index, step in
                    stepRow(index: index, text: step, plan: plan)
                }
                if !images.isEmpty { AnchorSetupPhotos(images: images) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("task.saved.plan")
            .sensoryFeedback(.success, trigger: checkedCount)
            .animation(AnchorMotion.micro, value: plan.completedSteps)
            .task(id: goal.id) {
                let goalID = goal.id
                let names = plan.localImageNames
                let loaded = await Task.detached(priority: .userInitiated) {
                    AnchorPlanImages.load(goalID: goalID, names: names)
                }.value
                guard !Task.isCancelled else { return }
                images = loaded
            }
        }
    }

    @ViewBuilder
    private func stepRow(index: Int, text: String, plan: AnchorUserPlan) -> some View {
        let done = plan.isDone(index)
        let row = HStack(alignment: .top, spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.body)
                .foregroundStyle(done ? AnchorStateTone.done.ink : AnchorIOSStyle.secondaryText)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityHidden(true)
            Text(String(format: "%02d", index + 1)).font(.caption.monospacedDigit())
                .foregroundStyle(AnchorIOSStyle.action)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(.subheadline)
                    .foregroundStyle(done ? AnchorIOSStyle.secondaryText : AnchorIOSStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
                if onToggleStep != nil, plan.nextStepIndex == index {
                    Text(PlanCopy.nextTag).font(.caption2.weight(.semibold)).foregroundStyle(AnchorIOSStyle.action)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 44, alignment: .topLeading)
        .contentShape(.rect)

        if let onToggleStep {
            Button {
                if !done { checkedCount += 1 }
                onToggleStep(index, !done)
            } label: { row }
            .buttonStyle(.plain)
            .accessibilityLabel("\(index + 1). \(text)")
            .accessibilityValue(done ? PlanCopy.doneState : PlanCopy.openState)
            .accessibilityHint(PlanCopy.toggleHint)
            .accessibilityIdentifier("task.plan.step.\(index)")
        } else {
            row
                .accessibilityElement(children: .combine)
                .accessibilityValue(done ? PlanCopy.doneState : PlanCopy.openState)
        }
    }
}
#endif
