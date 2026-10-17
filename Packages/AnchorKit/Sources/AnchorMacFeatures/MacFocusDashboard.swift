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
    var onOpenTask: (UUID) -> Void = { _ in }

    var body: some View {
        let tasks = model.projection.hostedSessions.filter { $0.status == .active || $0.status == .draft }
        if !tasks.isEmpty {
            MacTasksPage(
                model: model,
                sourceSetupModel: sourceSetupModel,
                tasks: tasks,
                actions: actions,
                onOpenSettings: onOpenSettings
            )
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

    private var actions: MacTaskActions {
        let model = model, sourceSetupModel = sourceSetupModel
        return MacTaskActions(
            setStep: { task, step, done in
                Task { _ = await model.send(.forSession(task, .setPlanStep(id: step, done: done))) }
            },
            markReviewed: { task in Task { _ = await model.send(.forSession(task, .markPlanReviewed)) } },
            open: onOpenTask,
            assign: { conversation, task in Task { await sourceSetupModel?.assign(conversation, to: task) } },
            ignore: { conversation in Task { await sourceSetupModel?.ignore(conversation) } }
        )
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
