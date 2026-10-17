#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The Mac's version of the iPhone glance: the same headline rule, the same
/// identity colors and the same lanes. Each lane also selects its task, so
/// the window needs no separate task grid.
struct MacGlanceCard: View {
    let tasks: [AnchorSession]
    let connection: ConnectionState
    let selectedTaskID: UUID?
    let onSelectTask: (UUID) -> Void

    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        MacCard(L10n.glanceTitle, symbol: "water.waves") {
            if !connection.isAuthenticatedAndHealthy && !tasks.isEmpty {
                Label(L10n.glanceSavedRecords, systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .accessibilityIdentifier("mac.glance.saved")
            }
        } content: {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                content(now: context.date)
            }
        }
        .accessibilityIdentifier("mac.glance")
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let glance = WorkGlance(tasks: tasks)
        VStack(alignment: .leading, spacing: 14) {
            headline(glance)
            if !tasks.isEmpty {
                lanes(now: now)
                if let change = glance.latestChange {
                    Divider()
                    latestChange(change)
                }
            }
        }
    }

    // MARK: Headline

    @ViewBuilder
    private func headline(_ glance: WorkGlance) -> some View {
        switch glance.headline {
        case .empty:
            message(L10n.glanceEmpty, detail: L10n.glanceEmptyDetail)
        case .awaitingSources:
            message(L10n.glanceAwaiting, detail: L10n.glanceAwaitingDetail)
        case .failed(let count):
            counted(count, label: L10n.glanceFailed, tint: AnchorStateTone.failed.ink, symbol: "xmark.octagon.fill", glance: glance)
        case .attention(let count):
            counted(count, label: L10n.glanceAttention, tint: AnchorStateTone.attention.ink,
                    symbol: "exclamationmark.circle.fill", glance: glance)
        case .needsYou(let count):
            counted(count, label: PlanText.glanceNeedsYou, tint: AnchorStateTone.attention.ink,
                    symbol: "eye.fill", glance: glance)
        case .running(let count):
            counted(count, label: L10n.glanceRunning, tint: AnchorPalette.brandDeep, symbol: nil, glance: glance)
        case .allCompleted:
            Label(L10n.glanceAllDone, systemImage: "checkmark.seal.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(AnchorStateTone.done.ink)
        case .quiet:
            Label(L10n.glanceQuiet, systemImage: "moon.zzz.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(AnchorPalette.secondaryInk)
        }
    }

    private func counted(_ count: Int, label: String, tint: Color, symbol: String?, glance: WorkGlance) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                    .accessibilityHidden(true)
            }
            Text("\(count)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(count)))
                .foregroundStyle(tint)
            Text(label)
                .font(.title3.weight(.semibold))
                .foregroundStyle(AnchorPalette.ink)
            Spacer(minLength: 12)
            let rest = [
                (glance.failed, L10n.glanceFailed),
                (glance.attention, L10n.glanceAttention),
                (glance.running, L10n.glanceRunning),
                (glance.needsYou, PlanText.glanceNeedsYou)
            ].filter { $0.0 > 0 }.dropFirst()
            if !rest.isEmpty {
                Text(rest.map { "\($0.0) \($0.1)" }.joined(separator: " · "))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }
        }
        .animation(reduceMotion ? nil : AnchorMotion.continuity, value: count)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mac.glance.headline")
    }

    private func message(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline).foregroundStyle(AnchorPalette.ink)
            Text(detail).font(.callout).foregroundStyle(AnchorPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mac.glance.headline")
    }

    // MARK: Lanes

    private func window(now: Date) -> TimeInterval {
        TaskTide.windowSpan(for: tasks, now: now)
    }

    private func lanes(now: Date) -> some View {
        let span = window(now: now)
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(tasks) { task in
                let selected = task.id == selectedTaskID && tasks.count > 1
                Button { onSelectTask(task.id) } label: {
                    TideLaneView(task: task, now: now, span: span, labelWidth: 180,
                                 stacked: false, reduceMotion: reduceMotion)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            selected ? AnchorPalette.softBlue.opacity(0.42) : .clear,
                            in: .rect(cornerRadius: 8, style: .continuous)
                        )
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help(task.goal.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("mac.glance.lane.\(task.id)")
            }
            HStack {
                Text(L10n.glanceWindowStart(span))
                Spacer()
                Text(L10n.glanceNow)
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(AnchorPalette.secondaryInk)
            .padding(.leading, 8 + 180 + 8)
            .padding(.trailing, 8)
            .accessibilityHidden(true)
        }
        .animation(reduceMotion ? nil : AnchorMotion.continuity, value: tasks.map(\.id))
    }

    private func latestChange(_ change: WorkGlance.Change) -> some View {
        let symbol = TideStyle.symbol(for: change)
        return Button { onSelectTask(change.taskID) } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol.name)
                    .foregroundStyle(symbol.color)
                    .accessibilityHidden(true)
                Text("\(change.processTitle) \(L10n.eventVerb(change.event.kind, interrupted: change.isInterruption))")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(AnchorPalette.ink)
                Text("\(change.sourceName) · \(change.taskTitle)")
                    .font(.callout)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(change.event.occurredAt, format: .relative(presentation: .named, unitsStyle: .abbreviated))
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.glanceLatest)
        .accessibilityIdentifier("mac.glance.latest")
    }
}
#endif
