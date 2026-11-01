#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

public extension EnvironmentValues {
    /// Asks the Mac to open a conversation (by `AnchorProcess.conversationKey`);
    /// false when the Mac could not be reached.
    @Entry var openConversationOnMac: @Sendable (UUID) async -> Bool = { _ in false }
}

/// A conversation opened from the desk, over the whole library: the
/// conversation on the left, read from its log on the Mac (what waits on the
/// person, how far it got, its last few steps), and the person's own anchor on
/// the right (the goal, the next step of their plan, a decision they made).
/// Steps the person has not seen here before are marked.
struct DeskRecallCard: View {
    let process: AnchorProcess
    let task: AnchorSession
    let palette: DeskFolderPalette
    let worked: String
    /// What the card shows while there is no digest: the latest reply, or how long the turn has run.
    let fallbackReply: String
    /// Steps of the path already seen on this card; the others are new.
    let seenPath: Set<String>
    let onTask: () -> Void

    private var digest: ConversationDigest? { process.digest }
    private var isRunning: Bool { process.status == .running || process.status == .queued }

    var body: some View {
        VStack(spacing: 0) {
            grabber
            HStack(alignment: .top, spacing: 12) {
                conversation
                anchor
                    .frame(width: 168)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(DeskStyle.card, in: .rect(cornerRadius: 24, style: .continuous))
        .shadow(color: palette.glow.opacity(0.28), radius: 24, y: 4)
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    /// Up is the Mac, beside the phone on the desk: the handle points there.
    private var grabber: some View {
        VStack(spacing: 3) {
            Image(systemName: "chevron.compact.up")
                .font(.system(size: 18, weight: .semibold))
            Image(systemName: "desktopcomputer")
                .font(.system(size: 11))
        }
        .foregroundStyle(DeskStyle.quietInk.opacity(0.7))
        .padding(.top, 6)
        .padding(.bottom, 2)
        .accessibilityHidden(true)
    }

    // MARK: The conversation

    private var conversation: some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text(process.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DeskStyle.text)
                    .lineLimit(1)
                if let words = digest?.keywords, !words.isEmpty {
                    Text(words.joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundStyle(DeskStyle.quietInk)
                        .lineLimit(1)
                }
            }
            waiting
            if let facts = digest?.facts, !facts.isEmpty {
                DeskChipRow(chips: facts.map(DeskText.recallFact))
            }
            path
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// The strongest cue for picking the work back up: what it waits on the person for.
    private var waiting: some View {
        let label: String
        let text: String?
        if isRunning {
            label = DeskText.recallRunning
            text = digest?.latestRequest ?? process.request
        } else if let waiting = digest?.waiting {
            label = waiting.kind == .answer ? DeskText.recallWaitingAnswer : DeskText.recallWaitingAct
            text = waiting.text
        } else if digest == nil {
            label = DeskText.recallIdle
            text = fallbackReply
        } else {
            label = DeskText.recallIdle
            text = nil
        }
        let highlighted = !isRunning && digest?.waiting != nil
        return VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(highlighted ? palette.ink : DeskStyle.quietInk)
            if let text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 14))
                    .foregroundStyle(DeskStyle.text)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlighted ? palette.front : DeskStyle.quietInk.opacity(0.1),
                    in: .rect(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// The last few replies' openings, oldest first, along a thin line.
    private var path: some View {
        let steps = digest?.path ?? []
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                let isNow = index == steps.count - 1
                let isNew = !seenPath.contains(step)
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Circle()
                        .fill(isNew ? palette.ink : DeskStyle.quietInk.opacity(0.45))
                        .frame(width: 6, height: 6)
                    Text(step)
                        .font(.system(size: 12.5, weight: isNow ? .medium : .regular))
                        .foregroundStyle(isNow ? DeskStyle.text : DeskStyle.quietInk)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(isNew ? "\(DeskText.recallNew): \(step)" : step)
            }
        }
    }

    // MARK: The person's anchor

    private var anchor: some View {
        Button(action: onTask) {
            VStack(alignment: .leading, spacing: 8) {
                Text(task.goal.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette.ink)
                    .lineLimit(2)
                if let plan = task.goal.userPlan, !plan.items.isEmpty {
                    Text(plan.nextStepIndex.map { DeskText.recallNextStep(plan.steps[$0]) } ?? DeskText.recallPlanDone)
                        .font(.system(size: 13))
                        .foregroundStyle(DeskStyle.text)
                        .lineLimit(3)
                }
                if let decision = digest?.decision {
                    Text(DeskText.recallDecided(decision))
                        .font(.system(size: 12))
                        .foregroundStyle(DeskStyle.text)
                        .lineLimit(2)
                }
                if let cues = digest?.cues, !cues.isEmpty {
                    Text(cues.joined(separator: "\n"))
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(DeskStyle.quietInk)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                Text([worked, process.sourceName].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(DeskStyle.quietInk)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(palette.front.opacity(0.55), in: .rect(cornerRadius: 16, style: .continuous))
            .contentShape(.rect)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityHint(DeskText.openTask)
    }
}

/// Short facts as chips, wrapping onto a second row when they must.
struct DeskChipRow: View {
    let chips: [String]

    var body: some View {
        DeskWrap(spacing: 5) {
            ForEach(chips, id: \.self) { chip in
                Text(chip)
                    .font(.system(size: 11.5))
                    .foregroundStyle(DeskStyle.text.opacity(0.75))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2.5)
                    .overlay(Capsule().strokeBorder(DeskStyle.quietInk.opacity(0.35), lineWidth: 0.75))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Lays children out in rows, left to right, starting a new row when one is full.
struct DeskWrap: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var items: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].items.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width += (row.items.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.items.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

/// The path steps the person has seen on each conversation's card, kept on
/// the phone so the next opening can mark what is new.
enum DeskRecallMemory {
    private static let key = "desk.recall.seen"
    private static let kept = 60

    static func seen(_ conversation: UUID, in defaults: UserDefaults = .standard) -> Set<String> {
        Set(all(defaults)[conversation.uuidString] ?? [])
    }

    static func remember(_ path: [String], for conversation: UUID, in defaults: UserDefaults = .standard) {
        guard !path.isEmpty else { return }
        var map = all(defaults)
        map[conversation.uuidString] = path
        if map.count > kept { map = Dictionary(uniqueKeysWithValues: map.suffix(kept).map { ($0.key, $0.value) }) }
        defaults.set(map, forKey: key)
    }

    private static func all(_ defaults: UserDefaults) -> [String: [String]] {
        defaults.dictionary(forKey: key) as? [String: [String]] ?? [:]
    }
}
#endif
