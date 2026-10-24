#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The return page: after the Bluetooth link to the Mac was down for five
/// minutes and came back. One page per open task, swiped sideways; each shows
/// the task's newest conversations, recapped by the Mac. The cards only
/// inform; Back to Home on the last page ends the return.
struct ReturnView: View {
    let projection: SessionProjection
    let model: AnchorSessionModel

    @Environment(\.scenePhase) private var scenePhase
    @AnchorReducedMotion private var reduceMotion
    @State private var page: UUID?
    @State private var presented = false
    @State private var feedback = 0
    @State private var isLeaving = false
    @State private var homePressed = false
    /// Past this, a page still waiting shows the latest requests instead.
    @State private var waitedLong = false

    static let wait: Duration = .seconds(20)

    var body: some View {
        ZStack {
            ReturnBackground()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 26)
                    .padding(.top, 28)

                TabView(selection: $page) {
                    ForEach(tasks) { task in
                        ReturnTaskPage(task: task, recap: recap(of: task), waitedLong: waitedLong)
                            .tag(Optional(task.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .opacity(presented ? 1 : 0)
                .offset(y: presented || reduceMotion ? 0 : 18)

                if tasks.count > 1 {
                    ReturnPageDots(count: tasks.count, current: currentIndex)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                }

                backToHome
                    .frame(maxWidth: .infinity)
                    .frame(height: 76)
            }
        }
        .preferredColorScheme(.light)
        .sensoryFeedback(.success, trigger: feedback)
        .onAppear(perform: present)
        .onChange(of: scenePhase) { _, _ in present() }
        .task(id: returnedAt) {
            waitedLong = false
            try? await Task.sleep(for: Self.wait)
            waitedLong = true
        }
        .accessibilityIdentifier("return.screen")
    }

    // MARK: Content

    /// The open tasks, the current one first; at most three can be anchored.
    private var tasks: [AnchorSession] {
        let current = projection.session?.id
        return projection.hostedSessions.sorted { lhs, rhs in
            if (lhs.id == current) != (rhs.id == current) { return lhs.id == current }
            return (lhs.taskColorIndex ?? 0) < (rhs.taskColorIndex ?? 0)
        }
    }

    private var returnedAt: Date? { projection.session?.returnSummary?.generatedAt }

    private func recap(of task: AnchorSession) -> ReturnRecap? {
        returnedAt.flatMap(task.returnRecap(for:))
    }

    private var currentIndex: Int {
        tasks.firstIndex { $0.id == page } ?? 0
    }

    private var isLastPage: Bool { currentIndex == tasks.count - 1 }

    // MARK: Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.returnWhileAway)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(ReturnStyle.title)
                .accessibilityAddTraits(.isHeader)
            Text(ReturnCopy.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(ReturnStyle.subtitle)
        }
    }

    /// Back to Home answers across a ring around the words, not only on
    /// the glyphs, so a thumb near it is enough.
    private var backToHome: some View {
        Text(ReturnCopy.backToHome)
            .font(.system(size: 16))
            .foregroundStyle(ReturnStyle.subtitle)
        .opacity(homePressed ? 0.6 : 1)
        .frame(width: 240, height: 72)
        .contentShape(.rect)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: 30, perform: goHome) { homePressed = $0 }
        .animation(.easeOut(duration: 0.12), value: homePressed)
        .opacity(isLastPage ? 1 : 0)
        .allowsHitTesting(isLastPage)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { goHome() }
        .accessibilityHidden(!isLastPage)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isLastPage)
        .accessibilityIdentifier("return.back.button")
    }

    private func goHome() {
        guard !isLeaving else { return }
        isLeaving = true
        Task {
            if !(await model.continueWorking()) { isLeaving = false }
        }
    }

    private func present() {
        guard scenePhase == .active, !presented else { return }
        if page == nil { page = tasks.first?.id }
        if model.claimReturnFeedback() { feedback += 1 }
        withAnimation(reduceMotion ? .easeOut(duration: 0.16) : .spring(duration: 0.42, bounce: 0.2)) {
            presented = true
        }
    }
}

// MARK: - Page

/// One task: its name over its newest conversations. While the Mac writes the
/// recap, the person's desk pet keeps them company.
private struct ReturnTaskPage: View {
    let task: AnchorSession
    let recap: ReturnRecap?
    let waitedLong: Bool

    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                ReturnTaskTitle(title: task.goal.title, tint: HostedTaskAppearance.landscapeTabTint(task))
                    .padding(.top, 40)
                content
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: phase)
    }

    private enum Phase: Equatable { case waiting, cards, empty }

    private var phase: Phase {
        if !cards.isEmpty { return .cards }
        if recap != nil || conversations.isEmpty { return .empty }
        return .waiting
    }

    private var conversations: [AnchorProcess] {
        TaskConversationStack(task: task).cards.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// The Mac's recap, or after a long wait the latest requests as they are.
    private var cards: [ConversationRecap] {
        if let recap { return recap.conversations }
        guard waitedLong else { return [] }
        return conversations.map {
            ConversationRecap(id: $0.id, name: $0.title, text: $0.request.flatMap(SummaryLimit.recap) ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .cards:
            VStack(spacing: 22) {
                ForEach(cards) { ReturnConversationCard(recap: $0) }
            }
            .transition(.opacity.combined(with: .offset(y: 10)))
        case .waiting:
            ReturnPetLoader()
                .padding(.top, 70)
                .transition(.opacity)
        case .empty:
            Text(ReturnCopy.noConversations)
                .font(.system(size: 15))
                .foregroundStyle(ReturnStyle.body)
                .padding(.top, 80)
        }
    }
}

/// The task's name, underlined in its tab color.
private struct ReturnTaskTitle: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(ReturnStyle.ink)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.bottom, 6)
            .background(alignment: .bottom) {
                Capsule().fill(tint).frame(height: 4)
            }
            .frame(maxWidth: .infinity)
    }
}

/// A conversation's name and recap. It only informs: a press shows the blue
/// edge and does nothing else.
private struct ReturnConversationCard: View {
    let recap: ConversationRecap

    var body: some View {
        Button {} label: {
            VStack(spacing: 14) {
                Text(recap.name)
                    .font(.system(size: 15))
                    .foregroundStyle(ReturnStyle.cardTitle)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                Text(recap.text)
                    .font(.system(size: 14))
                    .foregroundStyle(ReturnStyle.body)
                    .lineSpacing(6)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .top)
        }
        .buttonStyle(ReturnCardStyle())
        .accessibilityRemoveTraits(.isButton)
        .accessibilityElement(children: .combine)
    }
}

private struct ReturnCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        configuration.label
            .background {
                shape.fill(LinearGradient(colors: [.white.opacity(0.94), ReturnStyle.cardBottom],
                                          startPoint: .top, endPoint: .bottom))
            }
            .overlay {
                shape.strokeBorder(configuration.isPressed ? ReturnStyle.pressed : .white.opacity(0.7),
                                   lineWidth: configuration.isPressed ? 2.5 : 1)
            }
            .shadow(color: ReturnStyle.glow.opacity(0.28), radius: 14, y: 8)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ReturnPageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 9) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? ReturnStyle.dot : ReturnStyle.dotIdle)
                    .frame(width: 8, height: 8)
            }
        }
        .animation(.easeOut(duration: 0.2), value: current)
        .accessibilityHidden(true)
    }
}

// MARK: - Loader

/// The desk pet the person chose, typing away while the Mac reads the
/// conversations: a loop of a few seconds that never ends abruptly.
private struct ReturnPetLoader: View {
    @AppStorage(DeskPetKind.defaultsKey, store: ProfilePreferences.store) private var petKind = DeskPetKind.crab
    @AnchorReducedMotion private var reduceMotion

    private static let pixel: CGFloat = 4
    private static let rows = 30

    private var kind: DeskPetKind { petKind == .off ? .crab : petKind }

    var body: some View {
        VStack(spacing: 18) {
            TimelineView(.periodic(from: .now, by: 0.125)) { context in
                let tick = reduceMotion ? 0 : Int(context.date.timeIntervalSinceReferenceDate * 8)
                Canvas { canvas, size in
                    let look = DeskPetLook.of(kind)
                    let columns = Int(size.width / Self.pixel)
                    // A small hop every few seconds keeps it alive between keystrokes.
                    let hop = [0, -1, -2, -1][max(0, tick % 40 - 36)]
                    DeskPetRenderer(look: look, kind: kind, context: canvas,
                                    left: max(0, (columns - look.width) / 2),
                                    ground: Self.rows - 1 + (tick % 40 >= 36 ? hop : 0), pixel: Self.pixel)
                        .draw(DeskPetFrame(act: .type, progress: tick % 16, length: 16, tick: tick,
                                           still: reduceMotion))
                }
            }
            .frame(width: 160, height: CGFloat(Self.rows) * Self.pixel)

            HStack(spacing: 2) {
                Text(ReturnCopy.loading)
                if !reduceMotion { ReturnLoadingDots() }
            }
            .font(.system(size: 14))
            .foregroundStyle(ReturnStyle.body)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ReturnCopy.loading)
    }
}

private struct ReturnLoadingDots: View {
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { context in
            let count = Int(context.date.timeIntervalSinceReferenceDate / 0.45) % 4
            Text(String(repeating: ".", count: count) + String(repeating: " ", count: 3 - count))
                .monospaced()
        }
    }
}

// MARK: - Look

private struct ReturnBackground: View {
    var body: some View {
        ZStack {
            ReturnStyle.canvas
            RadialGradient(colors: [ReturnStyle.haze.opacity(0.75), .clear], center: UnitPoint(x: 0.5, y: 0.2),
                           startRadius: 10, endRadius: 260)
            RadialGradient(colors: [ReturnStyle.haze.opacity(0.65), .clear], center: UnitPoint(x: 0.5, y: 0.62),
                           startRadius: 10, endRadius: 320)
            RadialGradient(colors: [ReturnStyle.haze.opacity(0.4), .clear], center: UnitPoint(x: 0.5, y: 0.95),
                           startRadius: 10, endRadius: 220)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

enum ReturnStyle {
    static let canvas = Color(red: 0.976, green: 0.988, blue: 0.996)
    static let haze = Color(red: 0.70, green: 0.93, blue: 0.98)
    static let glow = Color(red: 0.45, green: 0.85, blue: 0.96)
    static let title = Color(red: 0.13, green: 0.37, blue: 0.68)
    static let subtitle = Color(red: 0.45, green: 0.48, blue: 0.51)
    static let ink = Color(red: 0.07, green: 0.08, blue: 0.10)
    static let cardTitle = Color(red: 0.20, green: 0.22, blue: 0.24)
    static let body = Color(red: 0.47, green: 0.50, blue: 0.53)
    static let cardBottom = Color(red: 0.90, green: 0.97, blue: 0.99).opacity(0.94)
    static let pressed = Color(red: 0.10, green: 0.56, blue: 0.93)
    static let dot = Color(red: 0.08, green: 0.66, blue: 0.88)
    static let dotIdle = Color(red: 0.84, green: 0.85, blue: 0.86)
}

enum ReturnCopy {
    static let subtitle = AnchorStrings.value("return.page.subtitle", default: "Here’s what happened in Anchor")
    static let backToHome = AnchorStrings.value("return.page.home", default: "Back to Home")
    static let loading = AnchorStrings.value("return.page.loading", default: "Catching up on your conversations")
    static let noConversations = AnchorStrings.value("return.page.empty", default: "No AI conversations in this task yet")
}
#endif
