#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The landscape work desk, read from about 60 cm (D05). Type follows three
/// reading distances: one glance answer (96 pt count, 28 pt label), a scan of
/// each task (26 pt name, 22 pt state) and details for leaning in (17 pt).
/// Nothing here moves on its own except real state changes and the one-time
/// arrival, when the anchor drops and sets in the harbor water.
struct LandscapeAmbientDashboard: View {
    let projection: SessionProjection
    /// Play the anchor drop and its haptic: true only when work just turned
    /// from portrait to landscape.
    var playsArrival = false
    let onTask: (UUID) -> Void
    let onManage: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AnchorReducedMotion private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var countScaled: CGFloat = 96
    @ScaledMetric(relativeTo: .title) private var labelScaled: CGFloat = 28
    @ScaledMetric(relativeTo: .title) private var nameScaled: CGFloat = 26
    @ScaledMetric(relativeTo: .title2) private var stateScaled: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var detailScaled: CGFloat = 17
    @ScaledMetric(relativeTo: .title) private var clockScaled: CGFloat = 34

    @State private var drop: CGFloat = 1
    @State private var contacts = 0
    @State private var ripple: CGFloat = 1
    @State private var rowsShown = true

    // Glance sizes may grow with Dynamic Type but never shrink below the desk floor.
    private var countSize: CGFloat { max(96, countScaled) }
    private var labelSize: CGFloat { max(28, labelScaled) }
    private var nameSize: CGFloat { max(26, nameScaled) }
    private var stateSize: CGFloat { max(22, stateScaled) }
    private var detailSize: CGFloat { max(17, detailScaled) }
    private var clockSize: CGFloat { max(34, clockScaled) }

    private var tasks: [AnchorSession] { projection.hostedSessions }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            summary
                            taskList(maxRows: tasks.count)
                        }
                        .padding(16)
                    }
                } else {
                    HStack(alignment: .top, spacing: 24) {
                        summary.frame(width: max(0, geometry.size.width * 0.38))
                        taskList(maxRows: 4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        // The harbor water runs edge to edge, under the home indicator.
        .background {
            GeometryReader { screen in
                harborWater(width: screen.size.width, height: screen.size.height)
            }
            .ignoresSafeArea()
        }
        .background { HarborBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: contacts)
        .onAppear { if playsArrival, !tasks.isEmpty { playArrival() } }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ambient.screen")
    }

    // MARK: Glance and details (left)

    private var summary: some View {
        TimelineView(.everyMinute) { context in
            let glance = WorkGlance(tasks: tasks)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(context.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                        .font(.system(size: clockSize, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                        .contentTransition(reduceMotion ? .opacity : .numericText())
                        .accessibilityIdentifier("ambient.time")
                    Text("\(L10n.ambientElapsed) \(L10n.minutesShort(elapsedMinutes(at: context.date)))")
                        .font(.system(size: detailSize, weight: .medium))
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                        .lineLimit(1).minimumScaleFactor(0.8)
                        .accessibilityHint(L10n.ambientElapsedHint)
                        .accessibilityIdentifier("ambient.focus")
                    Spacer(minLength: 4)
                    manageButton
                }
                Spacer(minLength: 8)
                headline(glance)
                Spacer(minLength: 8)
                if let change = glance.latestChange { latestChange(change, now: context.date) }
            }
            .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : .infinity, alignment: .topLeading)
        }
    }

    private var manageButton: some View {
        Button(action: onManage) {
            HStack(spacing: 5) {
                Text("\(tasks.count)").monospacedDigit()
                HarborAnchorGlyph(color: AnchorIOSStyle.secondaryText, lineWidth: 1.6)
                    .frame(width: 16, height: 16)
            }
            .font(.system(size: detailSize, weight: .semibold))
            .foregroundStyle(AnchorIOSStyle.secondaryText)
            .frame(minWidth: 44, minHeight: 44)
        }
        .accessibilityLabel(AnchorStrings.value("home.tasks.manage", default: "Manage hosted tasks"))
        .accessibilityIdentifier("ambient.tasks.manage")
    }

    @ViewBuilder
    private func headline(_ glance: WorkGlance) -> some View {
        switch glance.headline {
        case .empty:
            message(L10n.glanceEmpty, detail: L10n.glanceEmptyDetail)
        case .awaitingSources:
            message(L10n.glanceAwaiting, detail: L10n.glanceAwaitingDetail)
        case .failed(let count):
            counted(count, label: L10n.glanceFailed, tone: .failed, symbol: "xmark.octagon.fill", glance: glance)
        case .attention(let count):
            counted(count, label: L10n.glanceAttention, tone: .attention, symbol: "exclamationmark.circle.fill", glance: glance)
        case .running(let count):
            counted(count, label: L10n.glanceRunning, tone: nil, symbol: nil, glance: glance)
        case .allCompleted:
            settled(L10n.glanceAllDone, symbol: "checkmark.seal.fill", color: AnchorStateTone.done.ink)
        case .quiet:
            settled(L10n.glanceQuiet, symbol: "moon.zzz.fill", color: AnchorIOSStyle.secondaryText)
        }
    }

    private func counted(_ count: Int, label: String, tone: AnchorStateTone?, symbol: String?, glance: WorkGlance) -> some View {
        let color = tone?.ink ?? AnchorIOSStyle.heading
        let rest = [(glance.failed, L10n.glanceFailed), (glance.attention, L10n.glanceAttention),
                    (glance.running, L10n.glanceRunning), (glance.completed, L10n.glanceCompleted)]
            .filter { $0.0 > 0 }.dropFirst()
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: labelSize, weight: .semibold))
                        .foregroundStyle(color)
                        .accessibilityHidden(true)
                }
                Text("\(count)")
                    .font(.system(size: countSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(color)
                    .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(count)))
                Text(label)
                    .font(.system(size: labelSize, weight: .semibold))
                    .foregroundStyle(AnchorIOSStyle.text)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .animation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity, value: count)
            if !rest.isEmpty {
                Text(rest.map { "\($0.0) \($0.1)" }.joined(separator: " · "))
                    .font(.system(size: 20, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ambient.glance")
    }

    private func settled(_ title: String, symbol: String, color: Color) -> some View {
        Label {
            Text(title).font(.system(size: max(34, labelSize), weight: .bold)).foregroundStyle(AnchorIOSStyle.text)
        } icon: {
            Image(systemName: symbol).font(.system(size: labelSize, weight: .semibold)).foregroundStyle(color)
        }
        .accessibilityIdentifier("ambient.glance")
    }

    private func message(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: labelSize, weight: .semibold)).foregroundStyle(AnchorIOSStyle.text)
            Text(detail).font(.system(size: detailSize)).foregroundStyle(AnchorIOSStyle.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ambient.glance")
    }

    private func latestChange(_ change: WorkGlance.Change, now: Date) -> some View {
        let symbol = TideStyle.symbol(for: change)
        return Button { onTask(change.taskID) } label: {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: symbol.name).foregroundStyle(symbol.color).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(change.processTitle) \(L10n.eventVerb(change.event.kind, interrupted: change.isInterruption))")
                        .foregroundStyle(AnchorIOSStyle.text)
                    Text("\(change.sourceName) · \(change.event.occurredAt.formatted(.relative(presentation: .named)))")
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                }
                .lineLimit(1)
            }
            .font(.system(size: detailSize, weight: .medium))
            .contentShape(.rect)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.glanceLatest)
        .accessibilityIdentifier("ambient.latest")
    }

    // MARK: Tasks (right)

    @ViewBuilder
    private func taskList(maxRows: Int) -> some View {
        let overflow = tasks.count > maxRows
        let shown = overflow ? Array(tasks.prefix(maxRows - 1)) : tasks
        VStack(spacing: 0) {
            if tasks.isEmpty {
                Text(AnchorStrings.value("home.empty.tasks", default: "Drop an anchor to host your first task"))
                    .font(.system(size: stateSize, weight: .medium))
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(20)
            } else {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    let span = TaskTide.windowSpan(for: tasks, now: context.date)
                    VStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { index, task in
                            if index > 0 { Divider().overlay(AnchorIOSStyle.border) }
                            row(task, now: context.date, span: span)
                                .opacity(rowsShown ? 1 : 0.4)
                                .offset(y: rowsShown ? 0 : 8)
                                .animation(reduceMotion ? .easeOut(duration: 0.16)
                                    : AnchorMotion.continuity.delay(Double(index) * 0.04), value: rowsShown)
                        }
                        if overflow {
                            Divider().overlay(AnchorIOSStyle.border)
                            Button(action: onManage) {
                                Text(L10n.glanceMore(tasks.count - shown.count))
                                    .font(.system(size: detailSize, weight: .semibold))
                                    .foregroundStyle(AnchorIOSStyle.action)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                            .accessibilityIdentifier("ambient.more")
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : .infinity)
        .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: AnchorIOSStyle.heroRadius))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ambient.task.library")
    }

    private func row(_ task: AnchorSession, now: Date, span: TimeInterval) -> some View {
        let status = HostedTaskStatus(task: task)
        let tint = HostedTaskAppearance.tint(task)
        let remainder = status.remainder
        return Button { onTask(task.id) } label: {
            HStack(alignment: .center, spacing: 14) {
                Capsule().fill(tint).frame(width: 5, height: 44).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.goal.title)
                        .font(.system(size: nameSize, weight: .semibold))
                        .foregroundStyle(AnchorIOSStyle.text)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                        .minimumScaleFactor(0.8)
                    TideLaneView(task: task, now: now, span: span, labelWidth: 0, stacked: false,
                                 reduceMotion: reduceMotion, showsLabel: false)
                        .accessibilityHidden(true)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Label(status.word, systemImage: status.symbol.name)
                        .font(.system(size: stateSize, weight: .semibold))
                        .foregroundStyle(status.symbol.color)
                        .lineLimit(1)
                        .contentTransition(.symbolEffect(.replace))
                    if !remainder.isEmpty {
                        Text(remainder)
                            .font(.system(size: detailSize, weight: .medium))
                            .foregroundStyle(AnchorIOSStyle.secondaryText)
                            .lineLimit(1)
                    }
                }
                .animation(AnchorMotion.micro, value: status.word)
            }
            .frame(maxHeight: .infinity)
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(task.goal.title)
        .accessibilityValue(accessibleValue(task, status: status))
        .accessibilityIdentifier("hosted.task.\(task.id)")
    }

    private func accessibleValue(_ task: AnchorSession, status: HostedTaskStatus) -> String {
        guard let progress = task.conversationsInJoiningOrder.first?.progress, progress.isFinite else {
            return status.hasSources ? "\(status.summary), \(L10n.cardProgressUnreported)" : status.summary
        }
        let value = min(1, max(0, progress)).formatted(.percent.precision(.fractionLength(0)))
        return "\(status.summary), \(L10n.taskProgress) \(value)"
    }

    // MARK: Harbor water and the set anchor

    private func harborWater(width: CGFloat, height: CGFloat) -> some View {
        let anchorX = width * 0.30
        return ZStack(alignment: .bottomLeading) {
            VStack(spacing: 0) {
                Rectangle().fill(.white.opacity(0.7)).frame(height: 1.5)
                Rectangle().fill(AnchorIOSStyle.oceanSurface.opacity(0.32))
            }
            .frame(height: 48)
            if !tasks.isEmpty {
                // The rope only shows while the anchor falls.
                Rectangle()
                    .fill(AnchorIOSStyle.secondaryText.opacity(0.6))
                    .frame(width: 1.4, height: max(0, (height - 60) * drop))
                    .opacity(drop < 1 ? 1 : 0)
                    .offset(x: anchorX + 10, y: -44)
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 1.5)
                    .frame(width: 30, height: 10)
                    .scaleEffect(x: 1 + ripple * 1.6, y: 1 + ripple * 0.6)
                    .opacity(ripple < 1 ? 1 - ripple : 0)
                    .offset(x: anchorX - 4, y: -42)
                HarborAnchorGlyph(color: AnchorIOSStyle.heading.opacity(0.75), lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .offset(x: anchorX, y: -22 - (1 - drop) * (height - 60))
                    .accessibilityHidden(true)
            }
        }
        .frame(width: width, height: height, alignment: .bottomLeading)
    }

    /// The anchor falls from the top, sets in the water with one haptic, and
    /// the rows settle in. Content is readable from the first frame (D10).
    private func playArrival() {
        guard !reduceMotion else {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(160))
                contacts += 1
            }
            return
        }
        drop = 0
        rowsShown = false
        withAnimation(.timingCurve(0.45, 0, 0.9, 0.6, duration: 0.42)) { drop = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(420))
            contacts += 1
            ripple = 0
            withAnimation(.easeOut(duration: 0.7)) { ripple = 1 }
            rowsShown = true
        }
    }

    private func elapsedMinutes(at date: Date) -> Int {
        guard let startedAt = projection.session?.startedAt else { return 0 }
        return max(0, Int(date.timeIntervalSince(startedAt) / 60))
    }
}
#endif
