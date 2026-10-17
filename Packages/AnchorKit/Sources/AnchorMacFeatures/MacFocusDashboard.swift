#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacFocusDashboard: View {
    let model: AnchorSessionModel
    var sourceSetupModel: MacSourceSetupModel?
    let showsCompletedSessionInCurrentWork: Bool
    let onOpenProcess: (UUID) -> Void
    let onOpenTimeline: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        if let session = model.projection.session,
           MacCurrentTaskPresentation.showsInForeground(
               session.status,
               includingCompleted: showsCompletedSessionInCurrentWork
           ) {
            MacWorkOverviewView(
                model: model,
                session: session,
                conversations: conversations,
                onOpenProcess: onOpenProcess,
                onOpenTimeline: onOpenTimeline,
                onOpenSettings: onOpenSettings
            )
        } else if !model.projection.hostedSessions.isEmpty {
            page {
                MacGlanceCard(
                    tasks: model.projection.hostedSessions,
                    connection: model.projection.connection,
                    selectedTaskID: nil,
                    onSelectTask: { id in Task { await model.selectHostedTask(id) } }
                )
                if let conversations {
                    MacCodexConversationsCard(conversations: conversations)
                }
            }
        } else if let conversations {
            // Conversations need no anchor; an anchor adds a goal when one is wanted.
            page {
                MacCodexConversationsCard(conversations: conversations)
                Label(MacCodexCopy.anchorHint, systemImage: "iphone")
                    .font(.callout)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .padding(.horizontal, MacMetrics.cardPadding)
            }
        } else {
            MacEmptyWorkView(
                projection: model.projection,
                onOpenTimeline: onOpenTimeline,
                onOpenSettings: onOpenSettings
            )
        }
    }

    /// `nil` until Codex is connected, so an empty page still explains how to start.
    private var conversations: [CodexConversationSummary]? {
        guard let sourceSetupModel, sourceSetupModel.codexSessionsFolderName != nil else { return nil }
        return sourceSetupModel.codexConversations
    }

    private func page<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MacMetrics.pageSpacing) {
                MacWorkHeaderView(projection: model.projection, onOpenSettings: onOpenSettings)
                content()
            }
            .frame(maxWidth: MacMetrics.contentWidth, alignment: .leading)
            .padding(.horizontal, MacMetrics.pageInset)
            .padding(.bottom, MacMetrics.pageInset)
        }
        .accessibilityIdentifier("mac.current.screen")
    }
}

enum MacCurrentTaskPresentation {
    static func showsInForeground(
        _ status: SessionStatus?,
        includingCompleted: Bool
    ) -> Bool {
        switch status {
        case .draft, .active:
            true
        case .completed:
            includingCompleted
        case .archived, nil:
            false
        }
    }
}
#endif
