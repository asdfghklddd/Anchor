#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The home glance: what needs you, what is running, and what just happened.
/// Each hosted task is one lane in its identity color. Lanes show reported
/// lifecycle state over time, because sources report moments, not percentages.
struct HomeTideCard: View {
    let tasks: [AnchorSession]
    let connection: ConnectionState
    var maxLanes = 5
    /// Landscape gives the lanes the remaining height instead of a fixed rhythm.
    var fillsHeight = false
    let onTask: (UUID) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AnchorReducedMotion private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var headlineNumberSize: CGFloat = 40
    @ScaledMetric(relativeTo: .caption) private var laneLabelWidth: CGFloat = 96

    /// Landscape shares its column with the clock, so the card drops its
    /// title row and the secondary counts and lets the lanes breathe less.
    private var compact: Bool { fillsHeight && !dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        // Lanes advance with the clock; a half-minute tick is enough for a glance.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
        .padding(compact ? 14 : 16)
        .frame(maxWidth: .infinity, maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: AnchorIOSStyle.heroRadius))
        .clipShape(.rect(cornerRadius: AnchorIOSStyle.heroRadius))
        .shadow(color: AnchorIOSStyle.heading.opacity(0.08), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.glance")
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let glance = WorkGlance(tasks: tasks)
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            if compact {
                HStack(alignment: .center) {
                    headline(glance)
                    Spacer(minLength: 8)
                    savedRecordsLabel
                }
            } else {
                header
                headline(glance)
            }
            if !tasks.isEmpty {
                lanes(now: now)
                if fillsHeight { Spacer(minLength: 0) }
                if let change = glance.latestChange {
                    Divider().overlay(AnchorIOSStyle.border)
                    latestChange(change, now: now)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(L10n.glanceTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            savedRecordsLabel
        }
    }

    @ViewBuilder
    private var savedRecordsLabel: some View {
        if !connection.isAuthenticatedAndHealthy && !tasks.isEmpty {
            // Disconnection is common and not urgent: name it quietly.
            Label(L10n.glanceSavedRecords, systemImage: "clock.arrow.circlepath")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .accessibilityIdentifier("home.glance.saved")
        }
    }

    // MARK: Headline

    @ViewBuilder
    private func headline(_ glance: WorkGlance) -> some View {
        switch glance.headline {
        case .empty:
            message(L10n.glanceEmpty, detail: L10n.glanceEmptyDetail, symbol: "water.waves")
        case .awaitingSources:
            message(L10n.glanceAwaiting, detail: L10n.glanceAwaitingDetail, symbol: "circle.dashed")
        case .failed(let count):
            counted(count, label: L10n.glanceFailed, tint: .red, symbol: "xmark.octagon.fill", glance: glance)
        case .attention(let count):
            counted(count, label: L10n.glanceAttention, tint: AnchorIOSStyle.attentionInk,
                    symbol: "exclamationmark.circle.fill", glance: glance)
        case .running(let count):
            counted(count, label: L10n.glanceRunning, tint: AnchorIOSStyle.heading, symbol: nil, glance: glance)
        case .allCompleted:
            settled(L10n.glanceAllDone, symbol: "checkmark.seal.fill", tint: AnchorIOSStyle.success)
        case .quiet:
            settled(L10n.glanceQuiet, symbol: "moon.zzz.fill", tint: AnchorIOSStyle.secondaryText)
        }
    }

    private func counted(_ count: Int, label: String, tint: Color, symbol: String?, glance: WorkGlance) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                        .accessibilityHidden(true)
                }
                Text("\(count)")
                    .font(.system(size: compact ? headlineNumberSize * 0.75 : headlineNumberSize,
                                  weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(count)))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AnchorIOSStyle.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .animation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity, value: count)
            if !compact { secondaryCounts(glance) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.glance.headline")
    }

    /// Everything the headline did not already say, in a quiet line.
    @ViewBuilder
    private func secondaryCounts(_ glance: WorkGlance) -> some View {
        let parts: [(Int, String)] = [
            (glance.failed, L10n.glanceFailed),
            (glance.attention, L10n.glanceAttention),
            (glance.running, L10n.glanceRunning),
            (glance.completed, L10n.glanceCompleted)
        ].filter { $0.0 > 0 }
        let rest = parts.dropFirst()
        if !rest.isEmpty {
            Text(rest.map { "\($0.0) \($0.1)" }.joined(separator: " · "))
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(AnchorIOSStyle.secondaryText)
        }
    }

    private func settled(_ title: String, symbol: String, tint: Color) -> some View {
        Label {
            Text(title).font(.title2.weight(.bold)).foregroundStyle(AnchorIOSStyle.text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
        .accessibilityIdentifier("home.glance.headline")
    }

    private func message(_ title: String, detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AnchorIOSStyle.action)
                .frame(width: 40, height: 40)
                .background(AnchorIOSStyle.cyan.opacity(0.16), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(AnchorIOSStyle.text)
                Text(detail).font(.subheadline).foregroundStyle(AnchorIOSStyle.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.glance.headline")
    }

    // MARK: Lanes

    private func window(now: Date) -> TimeInterval {
        let earliest = tasks.map(\.startedAt).min() ?? now
        let needed = now.timeIntervalSince(earliest)
        // Round up to a readable span so the axis label stays simple.
        return [1_800, 3_600, 5_400, 7_200, 10_800, 14_400, 21_600, 28_800].first { $0 >= needed } ?? 28_800
    }

    @ViewBuilder
    private func lanes(now: Date) -> some View {
        let span = window(now: now)
        let shown = Array(tasks.prefix(maxLanes))
        VStack(alignment: .leading, spacing: 6) {
            VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 14 : (compact ? 4 : 10)) {
                ForEach(shown) { task in
                    Button { onTask(task.id) } label: {
                        TideLaneView(task: task, now: now, span: span, labelWidth: laneLabelWidth,
                                 stacked: dynamicTypeSize.isAccessibilitySize, reduceMotion: reduceMotion)
                    }
                    .buttonStyle(AnchorPressButtonStyle())
                    .accessibilityIdentifier("home.glance.lane.\(task.id)")
                }
            }
            .frame(maxHeight: fillsHeight ? .infinity : nil, alignment: .top)
            .animation(reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.continuity, value: shown.map(\.id))
            HStack {
                Text(L10n.glanceWindowStart(span))
                Spacer()
                if tasks.count > shown.count {
                    Text(L10n.glanceMore(tasks.count - shown.count))
                    Spacer()
                }
                Text(L10n.glanceNow)
            }
            .font(.caption2.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(AnchorIOSStyle.secondaryText)
            .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 0 : laneLabelWidth + 8)
            .accessibilityHidden(true)
        }
    }

    // MARK: Latest change

    private func latestChange(_ change: WorkGlance.Change, now: Date) -> some View {
        let tint = tasks.first { $0.id == change.taskID }.map(HostedTaskAppearance.tint) ?? AnchorIOSStyle.cyan
        let symbol = TideStyle.symbol(for: change)
        return Button { onTask(change.taskID) } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: symbol.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(symbol.color)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.16), in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(change.processTitle) \(L10n.eventVerb(change.event.kind, interrupted: change.isInterruption))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AnchorIOSStyle.text)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    Text("\(change.sourceName) · \(change.taskTitle)")
                        .font(.caption)
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(change.event.occurredAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                    .fixedSize()
            }
            .contentShape(.rect)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.glanceLatest)
        .accessibilityIdentifier("home.glance.latest")
    }
}
#endif
