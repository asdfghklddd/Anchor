#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Read the same saved plan from current work and history, without inventing processes.
struct AnchorSavedPlan: View {
    let goal: AnchorGoal
    @State private var images: [Data] = []

    var body: some View {
        if let plan = goal.userPlan {
            VStack(alignment: .leading, spacing: 12) {
                Text(SetupCopy.steps).font(.headline).foregroundStyle(AnchorIOSStyle.heading)
                ForEach(Array(plan.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text(String(format: "%02d", index + 1)).font(.caption.monospacedDigit())
                            .foregroundStyle(AnchorIOSStyle.action)
                        Text(step).font(.subheadline)
                    }
                }
                if !images.isEmpty { AnchorSetupPhotos(images: images) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("task.saved.plan")
            .task(id: goal.id) {
                images = AnchorPlanImages.load(goalID: goal.id, names: plan.localImageNames)
            }
        }
    }
}
#endif
