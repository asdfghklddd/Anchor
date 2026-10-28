#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

public enum NotchIslandAction: Sendable {
    case copyNextStep
    case selectTask(UUID)
    case openSettings
    case fixLink(AnchorStatusMenu.Fix)
    case connectSources
    case openWindow
    case quit
}

/// Anchor on the Mac: a dark island around the camera housing. Closed, a dot
/// per task sits left of the housing and the phone link right of it. Open,
/// the island drops down with the task the person is on, its next step ready
/// to copy, and the other tasks with their newest conversation.
public struct NotchIslandView: View {
    let state: NotchIslandState
    let onAction: (NotchIslandAction) -> Void

    @AnchorReducedMotion private var reduceMotion
    @Namespace private var taskSpace

    public init(state: NotchIslandState, onAction: @escaping (NotchIslandAction) -> Void) {
        self.state = state
        self.onAction = onAction
    }

    private var isOpen: Bool { state.phase == .expanded }
    private var geometry: NotchIslandGeometry { state.geometry }
    private var content: NotchIslandContent { state.content }

    public var body: some View {
        let size = state.islandSize
        let flare = isOpen ? NotchIslandMetrics.expandedFlare : NotchIslandMetrics.compactFlare
        let radius = switch state.phase {
        case .compact: NotchIslandMetrics.compactRadius
        case .primed: NotchIslandMetrics.primedRadius
        case .peek: NotchIslandMetrics.peekRadius
        case .expanded: NotchIslandMetrics.expandedRadius
        }
        ZStack(alignment: .top) {
            NotchIslandSurface(flare: flare, radius: radius, isOpen: isOpen)
                .frame(width: size.width, height: size.height)
                // News arriving while a peek can't show: a small sideways give.
                .keyframeAnimator(initialValue: 1.0, trigger: state.nudges) { surface, stretch in
                    surface.scaleEffect(x: reduceMotion ? 1 : stretch, y: 1, anchor: .top)
                } keyframes: { _ in
                    SpringKeyframe(1.03, duration: 0.14, spring: .snappy)
                    SpringKeyframe(1, duration: 0.5, spring: .bouncy)
                }
                .shadow(color: .black.opacity(isOpen ? 0.38 : 0), radius: 22, y: 10)

            VStack(spacing: 0) {
                topStrip
                    .frame(height: geometry.notch.height)
                tasks(isShown: isOpen)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
            .clipShape(NotchIslandShape(flare: flare, radius: radius))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // The open island's height, measured from a hidden copy so the shape
        // knows where to grow before its contents arrive.
        .background(alignment: .top) {
            tasks(isShown: true)
                .frame(width: geometry.expandedWidth)
                .fixedSize(horizontal: false, vertical: true)
                .hidden()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                    state.contentHeight = height
                }
        }
        .animation(animation(for: state.phase), value: state.phase)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.86),
                   value: content.current?.id)
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: state.contentHeight)
        .environment(\.colorScheme, .dark)
        .contextMenu {
            Button(EdgeMenuCopy.settings) { onAction(.openSettings) }
            Button(NotchIslandCopy.openWindow) { onAction(.openWindow) }
            Divider()
            Button(EdgeMenuCopy.quit) { onAction(.quit) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.appName)
    }

    /// Opening is lively and settles with a little give; closing is quicker
    /// and lands without a bounce.
    private func animation(for phase: NotchIslandPhase) -> Animation {
        if reduceMotion { return .easeInOut(duration: 0.2) }
        return switch phase {
        case .expanded: .spring(response: 0.42, dampingFraction: 0.78)
        case .primed: .spring(response: 0.26, dampingFraction: 0.7)
        case .peek: .spring(response: 0.36, dampingFraction: 0.72)
        case .compact: .spring(response: 0.30, dampingFraction: 1)
        }
    }

    // MARK: Beside the housing

    /// The dots and the link, or, while a peek shows, its news. The news
    /// arrives once the shape has stretched.
    private var topStrip: some View {
        ZStack {
            if state.phase == .peek, let peek = state.peek {
                NotchPeekStrip(peek: peek, geometry: geometry)
                    .id(peek.id)
                    .transition(.opacity.animation(.easeOut(duration: 0.2).delay(reduceMotion ? 0 : 0.1)))
            } else {
                housingStrip
                    .transition(.opacity.animation(.easeOut(duration: 0.16)))
            }
        }
    }

    /// Each side keeps its place as the island grows around it; the open
    /// island adds the settings button at the far right.
    private var housingStrip: some View {
        let ear = geometry.earWidth(dots: state.dotCount)
        return HStack(spacing: 0) {
            // Nudged inward by half the flare, which the closed shape takes
            // from the ears' outer edges.
            NotchTaskDots(tasks: Array(content.tasks.prefix(3)), flashes: state.flashes)
                .frame(width: ear)
                .offset(x: NotchIslandMetrics.compactFlare / 2)
            Color.clear
                .frame(width: geometry.notch.width)
            linkButton
                .frame(width: ear)
                .offset(x: -NotchIslandMetrics.compactFlare / 2)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            if isOpen {
                Button { onAction(.openSettings) } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(NotchIslandInk.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(L10n.settings)
                .accessibilityLabel(L10n.settings)
                .padding(.trailing, NotchIslandMetrics.inset - 6)
                .transition(.opacity.animation(.easeOut(duration: 0.18).delay(reduceMotion ? 0 : 0.12)))
            }
        }
    }

    private var linkButton: some View {
        Button {
            if let fix = content.fix { onAction(.fixLink(fix)) } else { onAction(.openSettings) }
        } label: {
            Image(systemName: "iphone")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(linkTint)
                .frame(width: 28, height: 28)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(linkDescription)
        .accessibilityLabel(linkDescription)
    }

    private var linkTint: Color {
        if content.linkNeedsAttention { return AnchorPalette.attention }
        return content.isLinked ? Color(AnchorColorTokens.homeLinked) : NotchIslandInk.faint
    }

    private var linkDescription: String {
        let link = StatusMenuCopy.link(content.link)
        let parts = [link, content.peerDevice, content.fix.map(StatusMenuCopy.fix)]
            + (content.needsSources ? [StatusMenuCopy.agentSourcesConnect] : [])
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    // MARK: The open island

    @ViewBuilder
    private func tasks(isShown: Bool) -> some View {
        VStack(spacing: 6) {
            if let code = content.pairingCode, isShown {
                pairingCard(code)
                    .transition(reveal(order: 0))
            }
            if content.needsSources, isShown {
                connectSources
                    .transition(reveal(order: 0))
            }
            if isShown {
                hero
                    .transition(reveal(order: 0))
            }
            ForEach(Array(content.others.enumerated()), id: \.element.id) { index, task in
                if isShown {
                    row(task)
                        .transition(reveal(order: index + 1))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
        .padding(.bottom, 12)
    }

    /// Contents arrive once the shape has mostly grown: out of a soft blur,
    /// down into place, one row after another. They leave all at once, fast.
    private func reveal(order: Int) -> AnyTransition {
        if reduceMotion { return .opacity.animation(.easeInOut(duration: 0.2)) }
        return .asymmetric(
            insertion: .modifier(active: NotchReveal(progress: 0), identity: NotchReveal(progress: 1))
                .animation(.easeOut(duration: 0.26).delay(0.1 + Double(order) * 0.03)),
            removal: .opacity.animation(.easeIn(duration: 0.08))
        )
    }

    @ViewBuilder
    private var hero: some View {
        if let current = content.current {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 10) {
                    NotchTaskBar(colorIndex: current.colorIndex, height: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(current.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(NotchIslandInk.primary)
                            .lineLimit(1)
                        planLine
                    }
                    Spacer(minLength: 8)
                    if content.prompt != nil {
                        NotchCopyButton { onAction(.copyNextStep) }
                    }
                }
                if current.conversation != nil {
                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(height: 0.5)
                    conversationLine(current)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.07)))
            .overlay {
                if state.highlightedTaskID == current.id {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(NotchIslandInk.task(current.colorIndex).opacity(0.6), lineWidth: 1)
                }
            }
            .matchedGeometryEffect(id: current.id, in: taskSpace)
            .accessibilityElement(children: .contain)
        } else {
            HStack(spacing: 10) {
                Image(systemName: "iphone")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(NotchIslandInk.secondary)
                    .accessibilityHidden(true)
                Text(EdgeMenuCopy.noTask)
                    .font(.system(size: 13))
                    .foregroundStyle(NotchIslandInk.primary)
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.07)))
        }
    }

    @ViewBuilder
    private var planLine: some View {
        switch content.plan {
        case let .step(number, total, text):
            (Text("\(number)/\(total)  ").foregroundStyle(NotchIslandInk.secondary).monospacedDigit()
                + Text(text).foregroundStyle(NotchIslandInk.primary.opacity(0.9)))
                .font(.system(size: 13))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        case .finished:
            Text(EdgeMenuCopy.allDone)
                .font(.system(size: 13))
                .foregroundStyle(NotchIslandInk.secondary)
        case .none:
            Text(EdgeMenuCopy.noPlan)
                .font(.system(size: 13))
                .foregroundStyle(NotchIslandInk.secondary)
        }
    }

    /// The code the phone asks for, large enough to type from across the desk.
    private func pairingCard(_ code: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "iphone")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NotchIslandInk.secondary)
                .accessibilityHidden(true)
            Text(L10n.pairingCode)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchIslandInk.primary)
            NotchInfoTip(text: StatusMenuCopy.pairingCodeHint)
            Spacer(minLength: 8)
            Text(code)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .tracking(3)
                .foregroundStyle(NotchIslandInk.primary)
                .textSelection(.enabled)
                .accessibilityLabel(L10n.pairingCode)
                .accessibilityValue(Text(code))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.07)))
        .accessibilityElement(children: .contain)
    }

    /// Opens Anchor's folder picker for both agents at once; until then no
    /// conversation can reach the island or the phone.
    private var connectSources: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button { onAction(.connectSources) } label: {
                    Label(StatusMenuCopy.agentSourcesConnect, systemImage: "folder.badge.plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(AnchorPressButtonStyle())
                NotchInfoTip(text: NotchIslandCopy.sourcesPrivacy)
            }
            if let error = content.sourcesError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(AnchorTaskIdentity.attentionInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }
        }
    }

    private func row(_ task: NotchIslandContent.Task) -> some View {
        Button { onAction(.selectTask(task.id)) } label: {
            HStack(spacing: 10) {
                NotchTaskBar(colorIndex: task.colorIndex, height: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NotchIslandInk.primary)
                        .lineLimit(1)
                    requestText(task)
                }
                Spacer(minLength: 8)
                NotchStateLabel(task: task)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(NotchRowStyle(
            wash: task.signal == .waiting || state.highlightedTaskID == task.id
                ? NotchIslandInk.task(task.colorIndex) : nil))
        .matchedGeometryEffect(id: task.id, in: taskSpace)
        .accessibilityElement(children: .combine)
        .accessibilityHint(NotchIslandCopy.switchHint)
    }

    private func conversationLine(_ task: NotchIslandContent.Task) -> some View {
        HStack(spacing: 8) {
            requestText(task)
            Spacer(minLength: 8)
            NotchStateLabel(task: task)
        }
    }

    private func requestText(_ task: NotchIslandContent.Task) -> some View {
        Group {
            if let request = task.conversation?.request {
                Text("\(EdgeMenuCopy.you)\(request)")
            } else {
                Text(EdgeMenuCopy.noConversation)
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(NotchIslandInk.secondary)
        .lineLimit(1)
    }
}

/// More about something, shown when the pointer rests on the icon and read
/// in full by VoiceOver, instead of a line of text that is always there.
struct NotchInfoTip: View {
    let text: String

    var body: some View {
        Image(systemName: "info.circle")
            .font(.system(size: 12))
            .foregroundStyle(NotchIslandInk.faint)
            .help(text)
            .accessibilityLabel(text)
    }
}

/// Ink on the island, chosen for contrast on its darkest and lightest backdrop.
enum NotchIslandInk {
    static let primary = Color.white
    /// At least 4.5:1 even where a white desktop shows through the glass.
    static let secondary = Color(white: 0.7)
    static let faint = Color(white: 0.5)

    /// The iPhone's task tab colors, in the same order.
    static func task(_ index: Int) -> Color {
        Color(AnchorColorTokens.landscapeTaskTab(index: index))
    }
}

enum NotchIslandCopy {
    static let switchHint = AnchorStrings.value("mac.notch.switch.hint", default: "Make this the task you're on")
    static let sourcesPrivacy = AnchorStrings.value(
        "mac.notch.sources.privacy",
        default: "Anchor reads only the conversation logs in these two folders. Your iPhone gets titles, latest requests and status, never the whole log.")
    static let openWindow = AnchorStrings.value("mac.notch.open-window", default: "Open Full Window")
    static let shortcut = AnchorStrings.value("mac.notch.shortcut", default: "Open the notch")
    static let peeksToggle = AnchorStrings.value(
        "mac.notch.peeks", default: "Show in the notch when an agent finishes or needs you")

    static func taskState(_ title: String, _ state: String) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("mac.notch.task-state", default: "%1$@: %2$@"), title, state)
    }
}

private struct NotchReveal: ViewModifier {
    let progress: Double

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: (1 - progress) * 6)
            .offset(y: (1 - progress) * -8)
    }
}

/// A task's identity color as a short upright bar.
private struct NotchTaskBar: View {
    let colorIndex: Int
    let height: CGFloat

    var body: some View {
        Capsule()
            .fill(NotchIslandInk.task(colorIndex))
            .frame(width: 3, height: height)
            .accessibilityHidden(true)
    }
}

/// Where a task's newest conversation stands, and how long ago it moved. A
/// conversation waiting on the person takes the task's color.
private struct NotchStateLabel: View {
    let task: NotchIslandContent.Task

    var body: some View {
        if let conversation = task.conversation {
            HStack(spacing: 4) {
                switch task.signal {
                case .running:
                    NotchSpinner(color: NotchIslandInk.secondary, diameter: 10)
                case .done:
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                case .waiting, .idle:
                    EmptyView()
                }
                Text(conversation.state)
                    .fontWeight(task.signal == .waiting ? .semibold : .regular)
                Text("· \(EdgeMenuCopy.age(since: conversation.updatedAt))")
                    .monospacedDigit()
                    .foregroundStyle(NotchIslandInk.faint)
            }
            .font(.system(size: 12))
            .foregroundStyle(task.signal == .waiting ? NotchIslandInk.task(task.colorIndex) : NotchIslandInk.secondary)
            .lineLimit(1)
            .fixedSize()
        }
    }
}

/// The white pill: the one strong action on the island.
private struct NotchCopyButton: View {
    let action: () -> Void
    @State private var copied = false
    @State private var resetTask: Task<Void, Never>?
    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        Button {
            action()
            withAnimation(reduceMotion ? nil : AnchorMotion.micro) { copied = true }
            resetTask?.cancel()
            resetTask = Task {
                try? await Task.sleep(for: .milliseconds(1200))
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : AnchorMotion.micro) { copied = false }
            }
        } label: {
            Label(copied ? EdgeMenuCopy.copied : EdgeMenuCopy.copyNextStep,
                  systemImage: copied ? "checkmark" : "doc.on.doc")
                .contentTransition(.symbolEffect(.replace))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(.white))
                .fixedSize()
        }
        .buttonStyle(NotchPressStyle())
        .keyboardShortcut("c", modifiers: .command)
        .onDisappear { resetTask?.cancel() }
    }
}

/// Presses sink a little; a row lights up under the pointer.
private struct NotchPressStyle: ButtonStyle {
    @AnchorReducedMotion private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.96)
            .animation(reduceMotion ? nil : AnchorMotion.press, value: configuration.isPressed)
    }
}

private struct NotchRowStyle: ButtonStyle {
    /// A task waiting on the person keeps a wash of its color.
    let wash: Color?

    func makeBody(configuration: Configuration) -> some View {
        NotchRowBody(configuration: configuration, wash: wash)
    }
}

private struct NotchRowBody: View {
    let configuration: ButtonStyleConfiguration
    let wash: Color?
    @State private var isHovered = false
    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(fill)
            )
            .contentShape(.rect)
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.985)
            .onHover { isHovered = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .animation(reduceMotion ? nil : AnchorMotion.press, value: configuration.isPressed)
    }

    private var fill: Color {
        if let wash { return wash.opacity(isHovered ? 0.22 : 0.15) }
        return .white.opacity(isHovered ? 0.08 : 0.0)
    }
}
#endif
