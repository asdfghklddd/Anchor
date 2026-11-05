// Role: "Your agents" on the Me page: conversations grouped by agent, read from what the phone holds.

#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// One agent (Codex, Claude Code, a terminal) and its conversations across
/// every task on this phone, finished ones included, newest first.
struct SourceGroup: Identifiable {
    struct Conversation: Identifiable {
        let process: AnchorProcess
        let taskTitle: String
        var id: UUID { process.id }
    }

    let name: String
    let conversations: [Conversation]

    var id: String { name }
    var latest: AnchorProcess { conversations[0].process }
    var isRunning: Bool { conversations.contains { $0.process.status == .running } }
    /// The agent's working time so far, as far as the Mac has reported it.
    var workedSeconds: TimeInterval { conversations.reduce(0) { $0 + ($1.process.workedSeconds ?? 0) } }

    /// The hardest-working agent first; agents with no reported time by how recently they ran.
    static func all(in projection: SessionProjection) -> [SourceGroup] {
        let conversations = (projection.hostedSessions + projection.archivedSessions).flatMap { task in
            task.taskProcesses.map { Conversation(process: $0, taskTitle: task.goal.title) }
        }
        return Dictionary(grouping: conversations, by: \.process.sourceName)
            .map { name, items in
                SourceGroup(name: name, conversations: items.sorted { $0.process.updatedAt > $1.process.updatedAt })
            }
            .sorted {
                $0.workedSeconds == $1.workedSeconds
                    ? $0.latest.updatedAt > $1.latest.updatedAt
                    : $0.workedSeconds > $1.workedSeconds
            }
    }
}

/// One agent's conversations, opened from "Your agents" on the Me page.
struct SourceConversationsView: View {
    let group: SourceGroup

    var body: some View {
        List {
            ForEach(group.conversations) { conversation in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conversation.process.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AnchorPalette.ink)
                            .lineLimit(2)
                        Text(conversation.taskTitle + " · "
                             + conversation.process.updatedAt.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundStyle(AnchorIOSStyle.secondaryText)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(L10n.status(conversation.process.status))
                        .font(.caption)
                        .foregroundStyle(conversation.process.status == .running
                                         ? AnchorPalette.interaction : AnchorIOSStyle.secondaryText)
                }
                .accessibilityElement(children: .combine)
            }
            .listRowBackground(AnchorIOSStyle.surface)
        }
        .anchorIOSListSurface()
        .navigationTitle(group.name)
    }
}

/// One agent's tile on the Me page.
struct SourceTile: View {
    let process: AnchorProcess

    var body: some View {
        Text(process.sourceSymbol)
            .font(.headline.bold())
            .frame(width: 38, height: 38)
            .background(AnchorPalette.source(process.sourceTone).opacity(0.55), in: .rect(cornerRadius: 11))
            .accessibilityHidden(true)
    }
}
#endif
