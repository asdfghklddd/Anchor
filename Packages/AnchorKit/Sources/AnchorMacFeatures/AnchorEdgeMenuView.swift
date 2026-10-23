#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The boat's quick actions.
public enum AnchorEdgeAction: Sendable {
    case copyNextStep
    case switchTask
    case catchUp
    case more
    case selectTask(UUID)
}

/// Fixed geometry of what opens around the boat. The panel sits flush with the
/// boat's edge; the boat itself stays in its own panel on top.
public enum AnchorEdgeMenuLayout {
    /// The boat's center, from the screen edge.
    static let boatInset = AnchorEdgeEffectsMetrics.controlSide / 2
    static let fanRadius: CGFloat = 98
    static let buttonSide: CGFloat = 46
    /// The fan's angles, measured from straight toward the middle of the screen.
    static let angles: [Double] = [-69, -23, 23, 69]
    static let fanWidth: CGFloat = 206
    static let cardWidth: CGFloat = 292
    public static let size = CGSize(width: fanWidth + cardWidth, height: 380)
}

/// Four buttons fan out from the boat toward the screen, as the iPhone's
/// floating ball does, beside one small card: the task the person is on and
/// its next step, and, while the phone is away, every open task in short.
public struct AnchorEdgeMenuView: View {
    let menu: AnchorEdgeMenu
    let side: AnchorEdgeSide
    /// The boat's center, from the panel's top.
    let boatY: CGFloat
    let onAction: (AnchorEdgeAction) -> Void

    @AnchorReducedMotion private var reduceMotion
    @State private var isOpen = false
    @State private var copied = false

    public init(menu: AnchorEdgeMenu, side: AnchorEdgeSide, boatY: CGFloat,
                onAction: @escaping (AnchorEdgeAction) -> Void) {
        self.menu = menu
        self.side = side
        self.boatY = boatY
        self.onAction = onAction
    }

    public var body: some View {
        let size = AnchorEdgeMenuLayout.size
        let boatX = side == .leading ? AnchorEdgeMenuLayout.boatInset : size.width - AnchorEdgeMenuLayout.boatInset
        ZStack(alignment: .topLeading) {
            ForEach(Array(buttons.enumerated()), id: \.offset) { index, button in
                let angle = AnchorEdgeMenuLayout.angles[index] * .pi / 180
                let reach = isOpen ? AnchorEdgeMenuLayout.fanRadius : 0
                fanButton(button)
                    .position(x: boatX + side.inward * cos(angle) * reach,
                              y: boatY + sin(angle) * reach)
                    .scaleEffect(isOpen || reduceMotion ? 1 : 0.4)
                    .opacity(isOpen ? 1 : 0)
                    .animation(reduceMotion ? .easeOut(duration: 0.15)
                        : .spring(response: 0.34, dampingFraction: 0.78).delay(Double(index) * 0.025),
                               value: isOpen)
            }
            card
                .frame(width: AnchorEdgeMenuLayout.cardWidth)
                .fixedSize(horizontal: false, vertical: true)
                .position(x: side == .leading
                              ? AnchorEdgeMenuLayout.fanWidth + AnchorEdgeMenuLayout.cardWidth / 2
                              : AnchorEdgeMenuLayout.cardWidth / 2,
                          y: min(max(boatY, 90), size.height - 90))
                .opacity(isOpen ? 1 : 0)
                .offset(x: isOpen || reduceMotion ? 0 : -side.inward * 12)
                .animation(reduceMotion ? .easeOut(duration: 0.15) : AnchorMotion.continuity.delay(0.04),
                           value: isOpen)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .environment(\.colorScheme, .dark)
        .onAppear { isOpen = true }
    }

    // MARK: Fan

    private struct FanButton {
        let action: AnchorEdgeAction
        let symbol: String
        let title: String
        var isEnabled = true
        var help: String? = nil
    }

    private var buttons: [FanButton] {
        [
            FanButton(action: .copyNextStep, symbol: copied ? "checkmark" : "doc.on.doc",
                      title: copied ? EdgeMenuCopy.copied : EdgeMenuCopy.copyNextStep,
                      isEnabled: menu.prompt != nil,
                      help: menu.prompt == nil ? EdgeMenuCopy.copyUnavailable : nil),
            FanButton(action: .switchTask, symbol: "arrow.left.arrow.right", title: EdgeMenuCopy.switchTask,
                      isEnabled: menu.rows.count > 1),
            FanButton(action: .catchUp, symbol: "clock.arrow.circlepath", title: EdgeMenuCopy.catchUp,
                      isEnabled: !menu.rows.isEmpty),
            FanButton(action: .more, symbol: "ellipsis", title: EdgeMenuCopy.more),
        ]
    }

    private func fanButton(_ button: FanButton) -> some View {
        Button {
            if case .copyNextStep = button.action {
                withAnimation(AnchorMotion.micro) { copied = true }
            }
            onAction(button.action)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: button.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                    .foregroundStyle(.white)
                    .frame(width: AnchorEdgeMenuLayout.buttonSide, height: AnchorEdgeMenuLayout.buttonSide)
                    .background(Circle().fill(Color.black.opacity(0.72)))
                    .overlay { Circle().strokeBorder(.white.opacity(0.28), lineWidth: 1) }
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 2)
                Text(button.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .fixedSize()
            }
            .contentShape(.rect)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .disabled(!button.isEnabled)
        .opacity(button.isEnabled ? 1 : 0.45)
        .help(button.help ?? button.title)
        .accessibilityLabel(button.title)
    }

    // MARK: Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            currentTask
            Divider().overlay(.white.opacity(0.12))
            HStack(spacing: 6) {
                Circle()
                    .fill(menu.isPhoneConnected ? Color(AnchorColorTokens.doneInk) : Color.white.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text(menu.isPhoneConnected ? EdgeMenuCopy.phoneConnected : EdgeMenuCopy.phoneAway)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .accessibilityElement(children: .combine)
            // The phone is the dashboard; without it, the Mac keeps a short list.
            if !menu.isPhoneConnected, menu.rows.count > (menu.current == nil ? 0 : 1) {
                taskList
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.86))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.edge.card")
    }

    @ViewBuilder
    private var currentTask: some View {
        if let current = menu.current {
            VStack(alignment: .leading, spacing: 4) {
                Text(EdgeMenuCopy.current)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                HStack(spacing: 7) {
                    Circle().fill(AnchorTaskIdentity.color(for: current)).frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    Text(current.goal.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Text(menu.nextStep.map(EdgeMenuCopy.step)
                     ?? (current.goal.userPlan?.isFinished == true ? EdgeMenuCopy.allDone : EdgeMenuCopy.noPlan))
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        } else {
            Text(EdgeMenuCopy.noTask)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// One row per open task, as a glance: its newest conversation, what was
    /// asked, and where it stands. A click makes it the task the person is on.
    private var taskList: some View {
        let others = menu.rows.filter { $0.id != menu.current?.id }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(others.prefix(4)) { row in
                Button { onAction(.selectTask(row.id)) } label: { taskRow(row) }
                    .buttonStyle(AnchorPressButtonStyle())
            }
            if others.count > 4 {
                Text(EdgeMenuCopy.more(others.count - 4))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func taskRow(_ row: AnchorEdgeMenu.Row) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Capsule()
                .fill(AnchorTaskIdentity.color(for: row.task))
                .frame(width: 3)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.task.goal.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if let conversation = row.conversation {
                        Text(EdgeMenuCopy.age(since: conversation.updatedAt))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                if let conversation = row.conversation {
                    Text("\(conversation.title) · \(conversation.sourceName)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                    if let request = conversation.request {
                        Text("\(EdgeMenuCopy.you) \(request)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }
                    Text(L10n.runState(conversation))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint(for: conversation))
                } else {
                    Text(EdgeMenuCopy.noConversation)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.white.opacity(0.06)))
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private func tint(for conversation: AnchorProcess) -> Color {
        switch conversation.status {
        case .running, .queued: AnchorPalette.interaction
        case .completed: Color(AnchorColorTokens.doneInk)
        case .failed, .blocked, .disconnected: AnchorPalette.attention
        case .needsDecision: AnchorPalette.attention
        }
    }
}
#endif
