// Role: the tour step between first drop and turn. It shows that work starts from an agent opened on the Mac,
// because dropping an anchor alone brings no conversations. Opens by itself within 5 s; a unit test guards the timing.

#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Between the first drop and the turn: an anchor brings no work by itself.
/// A small Mac stands in the frost over the new card, with Claude Code and
/// Codex on its screen. Picked, or by itself after a moment, the agent's
/// window opens and the request is typed; the Mac's island gains the task's
/// pill, and a light runs down a thread into the real card, which now shows
/// who is working on it.
struct TourAgentStart: View {
    let tour: AnchorTour
    let size: CGSize
    /// The new card, which the frost leaves clear.
    let card: CGRect?
    /// Skip in the home's top bar, which still answers while this step waits.
    let skip: CGRect?
    let onMiss: () -> Void

    @AnchorReducedMotion private var reduceMotion
    @State private var opened = false
    @State private var typed = 0
    /// How many of the agent's lines have come up under the request.
    @State private var worked = 0
    @State private var islandLit = false
    @State private var threaded = false
    @State private var pulse: CGFloat = 0
    @State private var breathing = false

    private static let screen = CGSize(width: 268, height: 168)
    private static let threadLength: CGFloat = 46
    private static let agents: [TourMac.Agent] = [.claude, .codex]
    /// What a terminal shows of the work; the same words in any language.
    private static let toolCalls = ["Read crash.log", "Search AuthSession.swift"]

    private var picked: TourMac.Agent? { tour.pickedAgent }
    private var filed: Bool { tour.agentFiled }
    private var request: String { TourCopy.crashRequest }
    private var ownTask: AnchorSession? {
        tour.model.projection.hostedSessions.first { $0.id == tour.ownTask }
    }
    private var ownTint: Color { ownTask.map(HomeStyle.task) ?? AnchorIOSStyle.action }

    private var cardTop: CGFloat { card?.minY ?? size.height * 0.62 }
    /// The Mac's foot stands a thread's length above the card; the line above the Mac.
    private var macMiddle: CGFloat {
        max(cardTop - Self.threadLength - 12 - Self.screen.height / 2, Self.screen.height / 2 + 150)
    }
    private var threadTop: CGFloat { macMiddle + Self.screen.height / 2 + 12 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TourBlocker(hole: nil, opening: skip, onMiss: onMiss)
            if let skip {
                TourSkip(tour: tour, overFrost: true)
                    .frame(width: skip.width, height: skip.height)
                    .offset(x: skip.minX, y: skip.minY)
            }
            line
            thread
            mac
                .position(x: size.width / 2, y: macMiddle + 6)
            if let card, filed, let picked {
                chip(picked)
                    .frame(width: card.width, height: card.height, alignment: .trailing)
                    .offset(x: card.minX, y: card.minY)
                    .transition(.scale(scale: 0.7, anchor: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.25), value: filed)
        .sensoryFeedback(.success, trigger: filed)
        .onChange(of: filed) { _, nowFiled in
            if nowFiled { AnchorSound.shared.play(.ding) }
        }
        .task(id: picked) {
            if picked != nil { await play() }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { breathing = true }
        }
    }

    private func play() async {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(duration: 0.5, bounce: 0.08)) { opened = true }
        guard !reduceMotion else {
            typed = request.count
            worked = Self.toolCalls.count + 1
            islandLit = true
            return
        }
        guard (try? await Task.sleep(for: .seconds(0.3))) != nil else { return }
        // The same time for any language, in steady ticks.
        let ticks = 18
        for tick in 1...ticks {
            typed = request.count * tick / ticks
            guard (try? await Task.sleep(for: .seconds(0.03))) != nil else { return }
        }
        guard (try? await Task.sleep(for: .seconds(0.05))) != nil else { return }
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
            islandLit = true
            worked = 1
        }
        guard (try? await Task.sleep(for: .seconds(0.3))) != nil else { return }
        threaded = true
        withAnimation(.easeOut(duration: 0.2)) { worked = 2 }
        withAnimation(.easeIn(duration: AnchorTour.agentFiles - 1.2)) { pulse = 1 }
        guard (try? await Task.sleep(for: .seconds(0.25))) != nil else { return }
        withAnimation(.easeOut(duration: 0.2)) { worked = 3 }
    }

    // MARK: The line

    private var line: some View {
        TourCaption(text: filed ? TourCopy.agentFiled : TourCopy.agentOpen, centered: true)
            .frame(maxWidth: 340)
            .padding(.horizontal, 24)
            .frame(width: size.width)
            .position(x: size.width / 2, y: macMiddle - Self.screen.height / 2 - 62)
    }

    // MARK: The thread

    /// The light that carries the conversation from the Mac down into the card.
    @ViewBuilder private var thread: some View {
        let x = size.width / 2
        if threaded, !filed {
            Path { path in
                path.move(to: CGPoint(x: x, y: threadTop))
                path.addLine(to: CGPoint(x: x, y: cardTop))
            }
            .stroke(ownTint.opacity(0.65), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 7]))
            .allowsHitTesting(false)
            .transition(.opacity)
            Circle()
                .fill(ownTint)
                .frame(width: 10, height: 10)
                .shadow(color: ownTint.opacity(0.6), radius: 6)
                .position(x: x, y: threadTop + (cardTop - threadTop) * pulse)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    // MARK: The Mac

    private var mac: some View {
        VStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AnchorIOSStyle.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AnchorIOSStyle.action, lineWidth: 2.5)
                }
                .overlay { screen.padding(.horizontal, 10).padding(.top, 25).padding(.bottom, 10) }
                .overlay(alignment: .top) { island.padding(.top, 2.5) }
                .frame(width: Self.screen.width, height: Self.screen.height)
            Capsule()
                .fill(AnchorIOSStyle.action.opacity(0.85))
                .frame(width: Self.screen.width + 34, height: 9)
                .accessibilityHidden(true)
        }
        .shadow(color: AnchorIOSStyle.action.opacity(0.2), radius: 16, y: 7)
    }

    private var screen: some View {
        ZStack {
            HStack(spacing: 10) {
                ForEach(Self.agents, id: \.self) { tile($0) }
            }
            .opacity(opened ? 0 : 1)
            .allowsHitTesting(!opened)
            if let picked { window(picked) }
        }
    }

    private func tile(_ agent: TourMac.Agent) -> some View {
        Button {
            guard picked == nil else { return }
            AnchorSound.shared.play(.cardTap)
            tour.pickAgent(agent)
        } label: {
            VStack(spacing: 8) {
                Text(verbatim: ">_")
                    .font(.system(size: 21, weight: .bold, design: .monospaced))
                    .foregroundStyle(TourInk.guide)
                Text(verbatim: agent.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AnchorIOSStyle.heading)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AnchorIOSStyle.canvasTop, in: .rect(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(TourInk.guide.opacity(reduceMotion ? 0.7 : (breathing ? 0.85 : 0.25)), lineWidth: 2)
            }
            .contentShape(.rect(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(agent == .claude ? "tour.agent.claude" : "tour.agent.codex")
    }

    /// The agent's window, grown out of the tile that was picked: its title
    /// bar, the request as it is typed, what the agent does with it, and the
    /// box for the next message.
    private func window(_ agent: TourMac.Agent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBar(agent)
            Rectangle()
                .fill(AnchorIOSStyle.secondaryText.opacity(0.18))
                .frame(height: 0.5)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "> " + request.prefix(typed) + (typed < request.count ? "▍" : ""))
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(AnchorIOSStyle.heading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 1)
                ForEach(Array(Self.toolCalls.enumerated()), id: \.offset) { index, call in
                    toolRow(call)
                        .opacity(worked > index ? 1 : 0)
                        .offset(y: worked > index || reduceMotion ? 0 : 3)
                }
                working
                    .opacity(worked > Self.toolCalls.count ? 1 : 0)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)
            messageBox
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AnchorIOSStyle.canvasTop, in: .rect(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(AnchorIOSStyle.secondaryText.opacity(0.2), lineWidth: 0.5)
        }
        .scaleEffect(opened || reduceMotion ? 1 : 0.5, anchor: agent == .claude ? .leading : .trailing)
        .opacity(opened ? 1 : 0)
        .accessibilityHidden(true)
    }

    private func titleBar(_ agent: TourMac.Agent) -> some View {
        ZStack {
            HStack(spacing: 3.5) {
                ForEach([Color(anchorHex: 0xFF5F57), Color(anchorHex: 0xFEBC2E), Color(anchorHex: 0x28C840)], id: \.self) { light in
                    Circle().fill(light).frame(width: 5.5, height: 5.5)
                }
                Spacer(minLength: 0)
            }
            Text(verbatim: "\(agent.name) — login-app")
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .frame(height: 17)
    }

    /// One thing the agent did, as an agent's terminal lists it.
    private func toolRow(_ call: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(ownTint).frame(width: 4, height: 4)
            Text(verbatim: call)
                .font(.system(size: 8.5, design: .monospaced))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .lineLimit(1)
        }
    }

    private var working: some View {
        HStack(spacing: 4) {
            Image(systemName: "asterisk")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(TourInk.guide)
                .rotationEffect(.degrees(breathing ? 180 : 0))
            Text(verbatim: "Working…")
                .font(.system(size: 8.5, weight: .medium, design: .monospaced))
                .foregroundStyle(TourInk.guide)
        }
    }

    private var messageBox: some View {
        HStack(spacing: 3) {
            Text(verbatim: ">")
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
            Rectangle()
                .fill(AnchorIOSStyle.secondaryText.opacity(breathing ? 0.7 : 0.2))
                .frame(width: 1, height: 9)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .frame(height: 16)
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(AnchorIOSStyle.secondaryText.opacity(0.25), lineWidth: 0.5)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
    }

    /// The notch island, closed: a pill per task on the left, the plan's ring
    /// on the right. The task's own pill arrives once the Mac has matched it.
    private var island: some View {
        let others = tour.model.projection.hostedSessions.filter { $0.id != tour.ownTask }
        return HStack {
            VStack(spacing: 1.5) {
                ForEach(others.prefix(2)) { task in
                    Capsule().fill(HomeStyle.task(task)).frame(width: 13, height: 2.5)
                }
                Capsule().fill(ownTint)
                    .frame(width: 13, height: 2.5)
                    .scaleEffect(x: islandLit ? 1 : 0, anchor: .leading)
            }
            Spacer(minLength: 0)
            Circle()
                .stroke(.white.opacity(0.55), lineWidth: 1.5)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 8)
        .frame(width: 72, height: 18)
        .background(.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 7, bottomTrailingRadius: 7, style: .continuous))
        .background {
            // Once, as it catches the task.
            Capsule()
                .stroke(ownTint.opacity(islandLit ? 0 : 0.8), lineWidth: 2)
                .scaleEffect(islandLit && !reduceMotion ? 1.7 : 1)
                .opacity(islandLit ? 1 : 0)
                .animation(.easeOut(duration: 0.8), value: islandLit)
        }
        .accessibilityHidden(true)
    }

    // MARK: The card

    /// Who now works under the task, on the card's free end.
    private func chip(_ agent: TourMac.Agent) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(ownTint)
                .frame(width: 6, height: 6)
                .opacity(reduceMotion || breathing ? 1 : 0.4)
            Text(verbatim: agent.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(HomeStyle.cardText)
        }
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(ownTint.opacity(0.14), in: .capsule)
        .padding(.trailing, 12)
        .accessibilityHidden(true)
    }
}
#endif
