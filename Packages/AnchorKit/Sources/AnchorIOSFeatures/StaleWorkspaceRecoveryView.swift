#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Lets the user deliberately resume or preserve an old foreground workspace.
struct StaleWorkspaceRecoveryView: View {
    let session: AnchorSession
    let lastObservedAt: Date?
    let onContinue: () -> Void
    let onComplete: () -> Void
    let onNewWork: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingCompletionConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                HarborBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                        statusHeader
                        workspaceCard

                        Text(L10n.finishConfirmDetail)
                            .font(.body)
                            .foregroundStyle(AnchorPalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(AnchorSpacing.medium)
                    .padding(.bottom, AnchorSpacing.large)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionDock
            }
            .navigationTitle(L10n.currentWork)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                        .accessibilityIdentifier("recovery.close.button")
                }
            }
        }
        .accessibilityIdentifier("recovery.screen")
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(AnchorPalette.attention)
                .accessibilityHidden(true)

            Text(L10n.stale)
                .font(.title.bold())
                .foregroundStyle(AnchorPalette.brandDeep)
                .accessibilityAddTraits(.isHeader)

            Text(session.goal.title)
                .font(.title3.bold())
                .foregroundStyle(AnchorPalette.brandDeep)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var workspaceCard: some View {
        AnchorCard(tint: AnchorPalette.attention) {
            VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                Label(
                    L10n.startedAt(
                        session.startedAt.formatted(date: .abbreviated, time: .shortened)
                    ),
                    systemImage: "timer"
                )
                if let lastObservedAt {
                    Label(
                        "\(L10n.lastUpdated): \(lastObservedAt.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "clock.arrow.circlepath"
                    )
                }
                Label(L10n.processCount(session.processes.count), systemImage: "square.grid.2x2")
            }
            .font(.subheadline)
            .foregroundStyle(AnchorPalette.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    private var actionDock: some View {
        VStack(spacing: AnchorSpacing.small) {
            Button(action: onContinue) {
                Label(L10n.continueWorking, systemImage: "play.fill")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(AnchorPalette.interaction)
            .accessibilityIdentifier("recovery.continue.button")

            Button(action: onNewWork) {
                Label(L10n.setupNewWork, systemImage: "plus")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.bordered)
            .tint(AnchorPalette.interaction)
            .accessibilityIdentifier("recovery.new.button")

            Button {
                showingCompletionConfirmation = true
            } label: {
                Label(L10n.completeSession, systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(AnchorPalette.secondaryText)
            .accessibilityIdentifier("recovery.complete.button")
            .confirmationDialog(
                L10n.finishConfirmTitle,
                isPresented: $showingCompletionConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.completeSession, action: onComplete)
                Button(L10n.cancel, role: .cancel) { }
            } message: {
                Text(L10n.finishConfirmDetail)
            }
        }
        .padding(.horizontal, AnchorSpacing.medium)
        .padding(.vertical, AnchorSpacing.small)
        .background(AnchorPalette.paper.opacity(0.97))
    }
}
#endif
