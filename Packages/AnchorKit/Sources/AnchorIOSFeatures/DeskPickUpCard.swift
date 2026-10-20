#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI
import UserNotifications

/// Shown over the portrait home when the phone comes off the desk while an
/// agent works on the task you're on or a result waits for you (D05). This
/// is the interrupt the person asked for: the step you were on stays where it
/// was, and what to do instead of the phone rises under it. It leaves when
/// the phone turns sideways again, or when you choose to use the phone anyway.
struct DeskPickUpCard: View {
    let hold: DeskHold
    let current: AnchorSession?
    let tasks: [AnchorSession]
    let reminderEnabled: Bool
    let reminderMinutes: Int
    let reminderAuthorization: UNAuthorizationStatus
    /// Makes another task the one the person is on.
    let onSelect: (UUID) -> Void
    let onAllowReminder: () -> Void
    let onUseAnyway: () -> Void

    @AnchorReducedMotion private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var stepSize: CGFloat = 32
    @State private var risen = false
    @AccessibilityFocusState private var stepFocused: Bool

    var body: some View {
        ZStack {
            HarborBackground().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let current { stays(current) }
                    if let target { rising(target) }
                    reminderRow
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 12)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom, spacing: 0) { footer }
        }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: risen) { _, now in now }
        .onAppear {
            stepFocused = true
            withAnimation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity.delay(0.06)) { risen = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("desk.pickup")
    }

    // MARK: What stays: the task and step you were on

    private func stays(_ task: AnchorSession) -> some View {
        let plan = task.goal.userPlan.flatMap { $0.steps.isEmpty ? nil : $0 }
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle().fill(HostedTaskAppearance.tint(task)).frame(width: 10, height: 10).accessibilityHidden(true)
                Text(task.goal.title)
                    .font(.headline)
                    .foregroundStyle(AnchorIOSStyle.text)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                if let plan {
                    Text("\(plan.doneCount)/\(plan.steps.count)")
                        .font(.subheadline.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                }
            }
            if let plan, let index = plan.nextStepIndex {
                VStack(alignment: .leading, spacing: 4) {
                    Text(PlanText.step(index + 1))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                    Text(plan.items[index].text)
                        .font(.system(size: stepSize, weight: .bold))
                        .foregroundStyle(AnchorIOSStyle.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityFocused($stepFocused)
            }
            agentLine(task)
        }
    }

    @ViewBuilder
    private func agentLine(_ task: AnchorSession) -> some View {
        switch hold {
        case let .waiting(_, _, action, _):
            if case let .wait(_, since) = action {
                TimelineView(.everyMinute) { context in
                    Label("\(PlanText.line(for: action)) · \(PlanText.running(since: since, now: context.date))",
                          systemImage: PlanCopy.symbol(for: action).name)
                }
                .font(.title3.weight(.semibold))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .accessibilityIdentifier("desk.pickup.agent")
            }
        case let .needsYou(id, _, action) where id == task.id:
            Label(PlanText.line(for: action), systemImage: PlanCopy.symbol(for: action).name)
                .font(.title3.weight(.semibold))
                .foregroundStyle(PlanCopy.symbol(for: action).color)
                .accessibilityIdentifier("desk.pickup.agent")
        case .needsYou:
            EmptyView()
        }
    }

    // MARK: What rises: what to do instead of the phone

    private enum Target {
        case task(id: UUID, header: String, line: String, color: Color)
        case prepare(String)
    }

    private var target: Target? {
        switch hold {
        case let .waiting(_, _, _, .other(id, title, action)):
            .task(id: id, header: PlanText.meanwhile, line: "\(title) · \(PlanText.line(for: action, compact: true))",
                  color: PlanCopy.symbol(for: action).color)
        case let .waiting(_, _, _, meanwhile):
            .prepare(PlanText.meanwhileLine(meanwhile))
        case let .needsYou(id, title, action) where id != current?.id:
            .task(id: id, header: DeskText.needsYou, line: "\(title) · \(PlanText.line(for: action, compact: true))",
                  color: PlanCopy.symbol(for: action).color)
        case .needsYou:
            nil
        }
    }

    @ViewBuilder
    private func rising(_ target: Target) -> some View {
        Group {
            switch target {
            case let .task(id, header, line, color):
                Button { onSelect(id) } label: {
                    card(header: header) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            if let task = tasks.first(where: { $0.id == id }) {
                                Circle().fill(HostedTaskAppearance.tint(task)).frame(width: 10, height: 10)
                                    .accessibilityHidden(true)
                            }
                            Text(line)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(AnchorIOSStyle.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                                .foregroundStyle(color)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(AnchorPressButtonStyle())
                .accessibilityHint(PlanText.makeCurrentHint)
            case let .prepare(line):
                card(header: PlanText.meanwhile) {
                    Text(line)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AnchorIOSStyle.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("desk.pickup.meanwhile")
        .offset(y: risen || reduceMotion ? 0 : 56)
        .opacity(risen ? 1 : 0)
    }

    private func card(header: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AnchorIOSStyle.action)
            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: AnchorIOSStyle.heroRadius))
        .shadow(color: AnchorIOSStyle.heading.opacity(0.10), radius: 12, y: 6)
        .accessibilityElement(children: .combine)
    }

    // MARK: Reminder and the way out

    @ViewBuilder
    private var reminderRow: some View {
        if reminderEnabled {
            switch reminderAuthorization {
            case .notDetermined:
                Button(DeskText.remindMe, systemImage: "bell", action: onAllowReminder)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("desk.pickup.remind")
            case .authorized, .provisional, .ephemeral:
                Label(DeskText.remindsAfter(reminderMinutes), systemImage: "bell")
                    .font(.subheadline)
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
            default:
                EmptyView()
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Label(DeskText.turnSideways, systemImage: "rectangle.landscape.rotate")
                .font(.headline)
                .foregroundStyle(AnchorIOSStyle.heading)
                .multilineTextAlignment(.center)
            // The whole 44 pt row answers the tap, not only the words (D03).
            Button(action: onUseAnyway) {
                Text(DeskText.useAnyway)
                    .font(.subheadline)
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(AnchorPressButtonStyle())
            .accessibilityIdentifier("desk.pickup.use-anyway")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity)
    }
}
#endif
