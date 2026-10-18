#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The day so far, at the bottom of the home (I10): what the person finished,
/// then what still waits on them or is running. Quiet until something happened.
struct TodayRecapCard: View {
    let recap: TodayRecap
    let onTask: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(TodayText.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                    .accessibilityAddTraits(.isHeader)
                Text(TodayText.summary(recap))
                    .font(.headline)
                    .foregroundStyle(AnchorIOSStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(recap.finishedSteps.prefix(4)) { step in
                Button { onTask(step.taskID) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AnchorStateTone.done.ink)
                            .accessibilityHidden(true)
                        Text("\(step.text) · \(step.taskTitle)")
                            .foregroundStyle(AnchorIOSStyle.text)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Text(step.at, style: .time)
                            .monospacedDigit()
                            .foregroundStyle(AnchorIOSStyle.secondaryText)
                    }
                    .font(.subheadline)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            }
            if recap.finishedSteps.count > 4 {
                Text(TodayText.moreSteps(recap.finishedSteps.count - 4))
                    .font(.caption)
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
            }
            if !recap.needsYou.isEmpty {
                Divider().overlay(AnchorIOSStyle.border)
                line(TodayText.waiting, symbol: "eye.fill", tint: AnchorStateTone.attention.ink,
                     text: recap.needsYou.map { "\($0.task.goal.title) · \(PlanText.line(for: $0.action, compact: true))" })
            }
            if !recap.running.isEmpty {
                line(TodayText.running, symbol: "play.circle.fill", tint: AnchorStateTone.running.ink,
                     text: recap.running.map(\.goal.title))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: AnchorIOSStyle.cardRadius))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.today")
    }

    private func line(_ label: String, symbol: String, tint: Color, text: [String]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(tint).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(AnchorIOSStyle.secondaryText)
                ForEach(text, id: \.self) { item in
                    Text(item).font(.subheadline).foregroundStyle(AnchorIOSStyle.text).lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
#endif
