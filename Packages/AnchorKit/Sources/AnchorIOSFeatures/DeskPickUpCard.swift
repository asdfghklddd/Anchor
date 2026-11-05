// Role: what appears when the phone is lifted off the desk while work runs ("把手机横放，回到桌前").
// Note: the owner may call this 回归页面, but it is different from `ReturnView`. It only appears on a landscape-to-portrait turn.

#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI
import UserNotifications

/// Shown over the portrait home when the phone comes off the desk while an
/// agent works on the task you're on or a result waits for you (D05). This
/// is the interrupt the person asked for, built like the home it covers: the
/// step you were on stays at the top beside your pet, the phone in the water
/// turns back onto its side, and what to do instead of the phone rises under
/// it. It leaves when the phone turns sideways again, or when you choose to
/// use the phone anyway.
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
            HomeWater()
            // It fills the screen when it fits, with the water taking what is left; otherwise it scrolls.
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
                    .scrollIndicators(.hidden)
                    .scrollEdgeEffectHidden(true, for: .all)
            }
        }
        .safeAreaBar(edge: .bottom, spacing: 0) { footer }
        .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: risen) { _, now in now }
        .onAppear {
            stepFocused = true
            withAnimation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity.delay(0.06)) { risen = true }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("desk.pickup")
    }

    private var content: some View {
        VStack(spacing: 0) {
            top
            water
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }

    // MARK: What stays: the task and step you were on

    private var top: some View {
        Group {
            if let current { stays(current) }
        }
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .padding(.leading, 24)
        // The pet keeps its place from the home, so this page reads as the same one.
        .padding(.trailing, 96)
        .overlay(alignment: .topTrailing) {
            HomePet(tasks: tasks, lives: false)
                .padding(.trailing, 36)
        }
        .padding(.top, 20)
    }

    private func stays(_ task: AnchorSession) -> some View {
        let plan = task.goal.userPlan.flatMap { $0.steps.isEmpty ? nil : $0 }
        let step = plan.flatMap { plan in plan.nextStepIndex.map { (index: $0, text: plan.items[$0].text) } }
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Capsule()
                    .fill(HomeStyle.task(task))
                    .frame(width: 3, height: 16)
                    .accessibilityHidden(true)
                Text(task.goal.title)
                    .font(step == nil ? .system(size: stepSize, weight: .bold) : .callout.weight(.semibold))
                    .foregroundStyle(HomeStyle.ink)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize || step == nil ? nil : 1)
                if let plan {
                    Text(verbatim: "\(plan.doneCount)/\(plan.steps.count)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(HomeStyle.quiet)
                }
            }
            if let step {
                VStack(alignment: .leading, spacing: 2) {
                    Text(PlanText.step(step.index + 1))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(HomeStyle.quiet)
                    Text(step.text)
                        .font(.system(size: stepSize, weight: .bold))
                        .foregroundStyle(HomeStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 14)
                .accessibilityElement(children: .combine)
                .accessibilityFocused($stepFocused)
            }
            agentLine(task)
                .font(.subheadline.weight(.semibold))
                .padding(.top, 10)
        }
    }

    @ViewBuilder
    private func agentLine(_ task: AnchorSession) -> some View {
        switch hold {
        case let .waiting(_, _, action, _):
            if case let .wait(_, since) = action {
                TimelineView(.everyMinute) { context in
                    agentLabel("\(PlanText.line(for: action)) · \(PlanText.running(since: since, now: context.date))", action: action)
                }
                .accessibilityIdentifier("desk.pickup.agent")
            }
        case let .needsYou(id, _, action) where id == task.id:
            agentLabel(PlanText.line(for: action), action: action)
                .accessibilityIdentifier("desk.pickup.agent")
        case .needsYou:
            EmptyView()
        }
    }

    private func agentLabel(_ line: String, action: TaskNextAction) -> some View {
        let symbol = PlanCopy.symbol(for: action)
        return Label {
            Text(line).foregroundStyle(HomeStyle.quiet)
        } icon: {
            Image(systemName: symbol.name).foregroundStyle(symbol.color)
        }
    }

    // MARK: The water: turning back, and what rises

    private var water: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 30)
            VStack(spacing: 12) {
                if !dynamicTypeSize.isAccessibilitySize {
                    DeskTurnHint(tasks: tasks).accessibilityHidden(true)
                }
                Text(DeskText.turnSideways)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(HomeStyle.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer(minLength: 26)
            if let target {
                rising(target)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(alignment: .top) { HomeDome() }
        .padding(.top, 22)
    }

    /// What the card brings the person back to: a task, or getting ready for one.
    private enum Target {
        case task(id: UUID, header: String, title: String, line: String)
        case prepare(String)
    }

    private var target: Target? {
        switch hold {
        case let .waiting(_, _, _, .other(id, title, action)):
            .task(id: id, header: PlanText.meanwhile, title: title, line: PlanText.line(for: action, compact: true))
        case let .waiting(_, _, _, meanwhile):
            .prepare(PlanText.meanwhileLine(meanwhile))
        case let .needsYou(id, title, action) where id != current?.id:
            .task(id: id, header: DeskText.needsYou, title: title, line: PlanText.line(for: action, compact: true))
        case .needsYou:
            nil
        }
    }

    /// The home's library, holding the one thing to do instead of the phone.
    private func rising(_ target: Target) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(header(of: target))
                .font(.callout.weight(.bold))
                .foregroundStyle(HomeStyle.libraryTitle)
                .padding(.leading, 2)
                .accessibilityAddTraits(.isHeader)
            switch target {
            case let .task(id, _, title, line):
                Button { onSelect(id) } label: {
                    taskRow(tasks.first { $0.id == id }, title: title, line: line)
                }
                .buttonStyle(AnchorPressButtonStyle())
                .accessibilityHint(PlanText.makeCurrentHint)
            case let .prepare(line):
                Text(line)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(HomeStyle.cardText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: HomeTaskCard.radius))
                    .compositingGroup()
                    .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HomeStyle.library, in: .rect(cornerRadius: 18))
        .compositingGroup()
        .shadow(color: HomeStyle.cardShadow.opacity(0.13), radius: 10, y: 3)
        .accessibilityIdentifier("desk.pickup.meanwhile")
        .offset(y: risen || reduceMotion ? 0 : 56)
        .opacity(risen ? 1 : 0)
    }

    private func header(of target: Target) -> String {
        switch target {
        case let .task(_, header, _, _): header
        case .prepare: PlanText.meanwhile
        }
    }

    private func taskRow(_ task: AnchorSession?, title: String, line: String) -> some View {
        let waiting = task.flatMap { TaskNextAction(task: $0)?.asksForALook } == true
        return HStack(spacing: 14) {
            if let task {
                Capsule()
                    .fill(HomeStyle.task(task))
                    .frame(width: 3, height: 26)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(HomeStyle.cardText)
                Text(line)
                    .font(.footnote)
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
            }
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(task.map(HomeStyle.task) ?? HomeStyle.quiet)
                .accessibilityHidden(true)
        }
        .padding(.leading, 12)
        .padding(.trailing, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(task.flatMap { waiting ? HomeStyle.wash($0) : nil } ?? AnchorIOSStyle.surface,
                    in: .rect(cornerRadius: HomeTaskCard.radius))
        .compositingGroup()
        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
        .accessibilityElement(children: .combine)
    }

    // MARK: Reminder and the way out

    private var footer: some View {
        VStack(spacing: 2) {
            reminderRow
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
        .padding(.top, 6)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var reminderRow: some View {
        if reminderEnabled {
            switch reminderAuthorization {
            case .notDetermined:
                Button(action: onAllowReminder) {
                    Label(DeskText.remindMe, systemImage: "bell")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(HomeStyle.ink)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 36)
                        .background(AnchorIOSStyle.surface, in: Capsule())
                        .compositingGroup()
                        .shadow(color: .black.opacity(0.08), radius: 5, y: 2)
                }
                .buttonStyle(AnchorPressButtonStyle(.control))
                .accessibilityIdentifier("desk.pickup.remind")
            case .authorized, .provisional, .ephemeral:
                Label(DeskText.remindsAfter(reminderMinutes), systemImage: "bell")
                    .font(.footnote)
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
            default:
                EmptyView()
            }
        }
    }
}

/// A small phone in the water showing what turning it does: upright it shows
/// the person's tasks as the home's rows; on its side, the same tasks in their
/// folders, on the desk. With reduced motion it simply lies on its side.
private struct DeskTurnHint: View {
    let tasks: [AnchorSession]

    @AnchorReducedMotion private var reduceMotion

    /// Steps of the turning-phone animation.
    private enum Beat: CaseIterable {
        case upright, turned, desk

        var isTurned: Bool { self != .upright }
        var showsDesk: Bool { self == .desk }

        /// How the phone moves into this beat; each delay is how long the one before it rests.
        var arrival: Animation {
            switch self {
            case .upright: .easeInOut(duration: 0.5).delay(1.9)
            case .turned: .spring(response: 0.62, dampingFraction: 0.74).delay(0.8)
            case .desk: .easeOut(duration: 0.28)
            }
        }
    }

    var body: some View {
        Group {
            if reduceMotion {
                DeskTurnPhone(tasks: tasks, isTurned: true, showsDesk: true)
            } else {
                PhaseAnimator(Beat.allCases) { beat in
                    DeskTurnPhone(tasks: tasks, isTurned: beat.isTurned, showsDesk: beat.showsDesk)
                } animation: { $0.arrival }
            }
        }
        // Turning takes as much room as the phone is tall, so nothing around it moves.
        .frame(width: DeskTurnPhone.size.height + 8, height: DeskTurnPhone.size.height + 8)
    }
}

/// The small phone drawn inside the hint.
private struct DeskTurnPhone: View {
    let tasks: [AnchorSession]
    let isTurned: Bool
    let showsDesk: Bool

    static let size = CGSize(width: 74, height: 150)
    private static let edge: CGFloat = 5
    private static let restDrop: CGFloat = 26
    private static var screen: CGSize {
        CGSize(width: size.height - edge * 2, height: size.width - edge * 2)
    }

    /// The folders are as wide here as they are on the real desk, for as many tasks.
    private static let folderScale: CGFloat = 0.16

    private var shown: [AnchorSession] { Array(tasks.prefix(DeskTaskLibrary.Metrics.slots)) }
    private var widths: DeskLibraryWidths { DeskLibraryWidths(tasks: shown.count) }

    var body: some View {
        RoundedRectangle(cornerRadius: 17, style: .continuous)
            .fill(AnchorIOSStyle.surface)
            .overlay {
                // The desk is laid out on its side, wider than the phone stands.
                desk
                    .opacity(showsDesk ? 1 : 0)
                    .offset(y: showsDesk ? 0 : 5)
                    // Upright in the world once the phone lies on its side.
                    .rotationEffect(.degrees(90))
            }
            .overlay { rows.opacity(showsDesk ? 0 : 1) }
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(HomeStyle.ink, lineWidth: 2.5)
            }
            .overlay(alignment: .top) {
                Capsule()
                    .fill(HomeStyle.ink)
                    .frame(width: 20, height: 5)
                    .padding(.top, 8)
            }
            .frame(width: Self.size.width, height: Self.size.height)
            .rotationEffect(.degrees(isTurned ? -90 : 0))
            // It comes to rest low, close to the words under it.
            .offset(y: isTurned ? Self.restDrop : 0)
            .compositingGroup()
            .shadow(color: HomeStyle.cardShadow.opacity(0.18), radius: 12, y: 6)
    }

    /// The home: a row per task.
    private var rows: some View {
        VStack(spacing: 6) {
            ForEach(shown) { task in
                RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                    .fill(HomeStyle.task(task))
                    .frame(height: 12)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .padding(.bottom, 18)
    }

    /// The desk: the clock on the left and a folder per task, with room for the rest.
    private var desk: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .trailing, spacing: 4) {
                Capsule().fill(HomeStyle.ink).frame(width: 24, height: 9)
                Capsule().fill(HomeStyle.ink.opacity(0.35)).frame(width: 14, height: 3)
            }
            .padding(.top, 6)
            HStack(spacing: 3) {
                ForEach(shown) { task in
                    folder(DeskFolderPalette(task).folder)
                }
                ForEach(shown.count..<DeskTaskLibrary.Metrics.slots, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(HomeStyle.quiet.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        .frame(width: widths.empty * Self.folderScale)
                        .padding(.top, 5)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(width: Self.screen.width, height: Self.screen.height, alignment: .topTrailing)
    }

    private func folder(_ color: Color) -> some View {
        ZStack(alignment: .bottom) {
            DeskFolderShape(tabWidth: 12, tabHeight: 5, radius: 4, tabRadius: 2.5, fillet: 1.5)
                .fill(color)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(AnchorIOSStyle.surface)
                .padding(.horizontal, 2)
                .padding(.bottom, 2)
                .padding(.top, 7)
        }
        .frame(width: widths.folder * Self.folderScale)
    }
}
#endif
