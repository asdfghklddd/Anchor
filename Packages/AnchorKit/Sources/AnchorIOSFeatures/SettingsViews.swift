#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Settings › Sources: every agent the Mac has heard from, across all the
/// tasks on this phone, newest first.
struct SourceSettingsView: View {
    let projection: SessionProjection

    var body: some View {
        let groups = SourceGroup.all(in: projection)
        List {
            if groups.isEmpty {
                ContentUnavailableView(SourceCopy.empty, systemImage: "point.3.connected.trianglepath.dotted")
                    .listRowBackground(Color.clear)
            }
            ForEach(groups) { group in
                NavigationLink {
                    SourceConversationsView(group: group)
                } label: {
                    SourceGroupRow(group: group)
                }
            }
            .listRowBackground(AnchorIOSStyle.surface)
        }
        .anchorIOSListSurface()
        .navigationTitle(L10n.sources)
        .accessibilityIdentifier("sources.screen")
    }
}

/// One agent (Codex, Claude Code, a terminal) and its conversations, newest first.
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
    var runningCount: Int { conversations.filter { $0.process.status == .running }.count }

    static func all(in projection: SessionProjection) -> [SourceGroup] {
        let conversations = projection.hostedSessions.flatMap { task in
            task.taskProcesses.map { Conversation(process: $0, taskTitle: task.goal.title) }
        }
        return Dictionary(grouping: conversations, by: \.process.sourceName)
            .map { name, items in
                SourceGroup(name: name, conversations: items.sorted { $0.process.updatedAt > $1.process.updatedAt })
            }
            .sorted { $0.latest.updatedAt > $1.latest.updatedAt }
    }
}

private struct SourceGroupRow: View {
    let group: SourceGroup

    var body: some View {
        HStack(spacing: 12) {
            SourceTile(process: group.latest)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name).font(.headline).foregroundStyle(AnchorPalette.ink)
                Text(DeskText.conversationCount(group.conversations.count)
                     + " · " + group.latest.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
            }
            Spacer(minLength: 8)
            if group.runningCount > 0 {
                Text(L10n.status(.running))
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.interaction)
            }
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }
}

private struct SourceConversationsView: View {
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

private struct SourceTile: View {
    let process: AnchorProcess

    var body: some View {
        Text(process.sourceSymbol)
            .font(.headline.bold())
            .frame(width: 38, height: 38)
            .background(AnchorPalette.source(process.sourceTone).opacity(0.55), in: .rect(cornerRadius: 11))
            .accessibilityHidden(true)
    }
}

enum SourceCopy {
    static let empty = AnchorStrings.value("settings.sources.empty", default: "No sources yet")
}

#endif
