#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct PortraitDashboard: View {
    let projection: SessionProjection
    let auxiliaryToolbarLabel: String?
    let auxiliaryToolbarAction: (() -> Void)?
    let transitionNamespace: Namespace.ID
    let onRoute: (AnchorRoute) -> Void
    let onSheet: (AnchorSheet) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var anchorPulse = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let availability = projection.availability(at: context.date)

            ZStack(alignment: .bottom) {
                HarborBackground()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ProjectionStatusBanners(
                            projection: projection,
                            availability: availability,
                            now: context.date
                        )

                        HarborFocusIntro(
                            session: projection.session,
                            availability: availability,
                            now: context.date
                        )
                        .padding(.top, 10)
                        .padding(.bottom, 12)

                        if projection.session == nil {
                            emptyConnectionCard
                                .padding(.bottom, AnchorSpacing.small)
                        }

                        HarborMissionCard(
                            session: projection.session,
                            availability: availability,
                            onEdit: { onSheet(projection.session == nil ? .setup : .goal) },
                            onFinish: { onSheet(.finish) }
                        )

                        Group {
                            if isObservedWorkComplete {
                                observedCompletionPrompt
                                    .padding(.top, AnchorSpacing.small)
                                    .transition(
                                        reduceMotion
                                            ? .opacity
                                            : .scale(scale: 0.98, anchor: .top).combined(with: .opacity)
                                    )
                            }
                        }
                        .animation(
                            reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.panel,
                            value: isObservedWorkComplete
                        )

                        Color.clear.frame(height: 20)

                        processHeader(availability: availability)

                        if let session = projection.session {
                            processSections(session: session, availability: availability)
                        } else {
                            WorkspaceEmptyProcessesView()
                        }
                    }
                    .padding(.horizontal, AnchorSpacing.medium)
                    .padding(.bottom, 138)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)

                anchorFooter
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                HarborTopBar(
                    connection: projection.connection,
                    unreadCount: projection.unreadNotificationsCount,
                    auxiliaryLabel: auxiliaryToolbarLabel,
                    onProfile: { onRoute(.profile) },
                    onNotifications: { onSheet(.notifications) },
                    onAuxiliary: auxiliaryToolbarAction
                )
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarHidden(true)
        }
    }

    private func processHeader(availability: ProjectionAvailability) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(availability.isLive ? L10n.liveProcesses : L10n.currentSnapshot)
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.interaction)
                    .accessibilityIdentifier("processes.kicker")
                Text(processHeading(availability: availability))
                    .font(.title3.bold())
                    .foregroundStyle(AnchorPalette.brandDeep)
                    .accessibilityIdentifier("processes.title")
            }
            Spacer()
            HStack(spacing: 7) {
                Label(
                    processBadgeText(availability: availability),
                    systemImage: processBadgeSymbol(availability: availability)
                )
                    .labelStyle(.titleAndIcon)
                    .font(.caption2.bold())
                    .foregroundStyle(AnchorPalette.interaction)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 32)
                    .background(AnchorPalette.softBlue.opacity(0.52), in: .capsule)
                    .contentTransition(reduceMotion ? .opacity : .symbolEffect(.replace))
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.16) : AnchorMotion.micro,
                        value: availability
                    )
                    .accessibilityIdentifier("processes.live")

                Button {
                    onSheet(projection.session == nil ? .setup : .layout)
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.subheadline.bold())
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .tint(AnchorPalette.interaction)
                .frame(width: 44, height: 44)
                .accessibilityLabel(L10n.layout)
            }
        }
        .padding(.bottom, 4)
    }

    private var emptyConnectionCard: some View {
        AnchorCard(tint: projection.connection == .connected ? AnchorPalette.aiBlue : AnchorPalette.attention) {
            VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                Label(
                    connectionTitle,
                    systemImage: projection.connection == .connected
                        ? "macbook.and.iphone"
                        : "wifi.slash"
                )
                .font(.headline)
                .foregroundStyle(AnchorPalette.brandDeep)
                .accessibilityIdentifier("workspace.connection.status")

                Text(connectionDetail)
                    .font(.subheadline)
                    .foregroundStyle(AnchorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    onRoute(.connections)
                } label: {
                    Label(L10n.connections, systemImage: "chevron.right")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(AnchorPalette.interaction)
                .accessibilityIdentifier("workspace.connection.action")
            }
        }
    }

    private var connectionTitle: String {
        switch projection.connection {
        case .connected: L10n.macConnected
        case .pairing: L10n.remoteSyncing
        case .permissionDenied: L10n.permissionDenied
        case .failed: L10n.actionFailed
        case .disconnected, .unavailable: L10n.disconnected
        }
    }

    private var connectionDetail: String {
        switch projection.connection {
        case .connected: L10n.contextSyncStable
        case .permissionDenied: L10n.permissionDeniedDetail
        case .failed: L10n.connectionFailedDetail
        case .pairing: L10n.remoteSyncing
        case .disconnected, .unavailable: L10n.disconnectedCreateDetail
        }
    }

    private var observedCompletionPrompt: some View {
        AnchorCard(tint: AnchorPalette.aiBlue) {
            HStack(alignment: .center, spacing: AnchorSpacing.small) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(AnchorPalette.interaction)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.finishConfirmTitle)
                        .font(.headline)
                        .foregroundStyle(AnchorPalette.brandDeep)
                    Text(L10n.finishConfirmDetail)
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: AnchorSpacing.xSmall)
                Button(L10n.finish) { onSheet(.finish) }
                    .buttonStyle(.borderedProminent)
                    .tint(AnchorPalette.interaction)
                    .accessibilityIdentifier("session.review-finish.button")
            }
        }
        .accessibilityIdentifier("session.observed-complete.banner")
    }

    /// Only source-backed work can suggest model-side completion. Manually
    /// named placeholders and app presence never become completion evidence.
    private var isObservedWorkComplete: Bool {
        guard let session = projection.session else { return false }
        let observed = session.observedTaskProcesses
        return !observed.isEmpty && observed.allSatisfy { $0.status == .completed }
    }

    @ViewBuilder
    private func processSections(
        session: AnchorSession,
        availability: ProjectionAvailability
    ) -> some View {
        let planned = session.plannedProcesses
        let observed = session.observedTaskProcesses
        let environment = session.environmentProcesses

        if planned.isEmpty && observed.isEmpty {
            WorkspaceEmptyProcessesView()
        }

        if !planned.isEmpty {
            WorkspaceProcessSectionHeader(
                title: L10n.readyProcesses,
                detail: nil,
                count: planned.count,
                identifier: "processes.planned.section"
            )
            processGrid(
                processes: planned,
                session: session,
                availability: availability
            )
        }

        if !observed.isEmpty {
            WorkspaceProcessSectionHeader(
                title: L10n.sourceSetupTaskObservation,
                detail: L10n.sourceSetupTaskObservationDetail,
                count: observed.count,
                identifier: "processes.observed.section"
            )
            processGrid(
                processes: observed,
                session: session,
                availability: availability
            )
        }

        if !environment.isEmpty {
            WorkspaceEnvironmentSummary(
                processes: environment,
                onOpen: { onRoute(.sources) }
            )
            .padding(.top, AnchorSpacing.medium)
        }
    }

    private func processGrid(
        processes: [AnchorProcess],
        session: AnchorSession,
        availability: ProjectionAvailability
    ) -> some View {
        LazyVGrid(
            columns: dynamicTypeSize.isAccessibilitySize
                ? [GridItem(.flexible(), spacing: AnchorSpacing.small)]
                : [
                    GridItem(.flexible(), spacing: AnchorSpacing.small),
                    GridItem(.flexible(), spacing: AnchorSpacing.small),
                ],
            spacing: AnchorSpacing.small
        ) {
            ForEach(processes) { process in
                Button {
                    if let decision = session.decisions.first(where: {
                        $0.processID == process.id && $0.status == .open
                    }) {
                        onSheet(.decision(decision.id))
                    } else {
                        onRoute(.process(process.id))
                    }
                } label: {
                    ProcessCard(
                        process: process,
                        isRemote: session.presence == .away,
                        decorative: true,
                        statusContext: processStatusContext(availability: availability)
                    )
                        .matchedTransitionSource(id: process.id, in: transitionNamespace)
                }
                .buttonStyle(AnchorPressButtonStyle())
                .accessibilityLabel(
                    "\(process.sourceName), \(process.title), \(processStatusText(process, availability: availability)), \(process.metric) \(process.metricLabel)"
                )
                .accessibilityValue(
                    process.progress?.formatted(.percent.precision(.fractionLength(0)))
                        ?? processStatusText(process, availability: availability)
                )
                .accessibilityIdentifier(
                    process.status == .needsDecision
                        ? "process.needs-decision"
                        : "process.\(process.id.uuidString)"
                )
                .accessibilityHint(process.status == .needsDecision ? L10n.chooseDirection : L10n.activity)
            }
        }
        .animation(
            reduceMotion ? nil : AnchorMotion.continuity,
            value: processes.map(\.id)
        )
    }

    private func processHeading(availability: ProjectionAvailability) -> String {
        switch availability {
        case .empty, .live:
            L10n.happeningNow
        case .syncing:
            L10n.remoteSyncing
        case .lastKnown:
            L10n.stale
        }
    }

    private func processBadgeText(availability: ProjectionAvailability) -> String {
        switch availability {
        case .empty:
            L10n.preparing
        case .syncing:
            L10n.remoteSyncing
        case .live:
            L10n.live
        case .lastKnown:
            L10n.stale
        }
    }

    private func processBadgeSymbol(availability: ProjectionAvailability) -> String {
        switch availability {
        case .empty:
            "circle.dotted"
        case .syncing:
            "arrow.triangle.2.circlepath"
        case .live:
            "circle.fill"
        case .lastKnown:
            "clock.badge.exclamationmark"
        }
    }

    private func processStatusText(
        _ process: AnchorProcess,
        availability: ProjectionAvailability
    ) -> String {
        let status = L10n.status(process.status)
        guard isNonterminal(process.status),
              let context = processStatusContext(availability: availability) else {
            return status
        }
        return "\(context), \(status)"
    }

    private func processStatusContext(
        availability: ProjectionAvailability
    ) -> String? {
        switch availability {
        case .empty, .live:
            nil
        case .syncing:
            L10n.remoteSyncing
        case .lastKnown:
            L10n.currentSnapshot
        }
    }

    private func isNonterminal(_ status: ProcessStatus) -> Bool {
        switch status {
        case .queued, .running, .needsDecision, .blocked:
            true
        case .completed, .failed, .disconnected:
            false
        }
    }

    private var anchorFooter: some View {
        HStack {
            Spacer()
            HarborAnchorControl(label: L10n.dropAnchor) {
                anchorPulse += 1
                onSheet(projection.session == nil ? .setup : .note)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: anchorPulse)
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [AnchorPalette.canvas.opacity(0), AnchorPalette.canvas.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            .accessibilityHidden(true)
        }
    }
}

func eventSymbol(_ kind: ProcessEventKind) -> String {
    switch kind {
    case .created: "plus"
    case .progress: "arrow.up.right"
    case .outputReady: "sparkles"
    case .decisionRequired: "exclamationmark.bubble.fill"
    case .decisionResolved: "checkmark.bubble.fill"
    case .completed: "checkmark.circle.fill"
    case .failed: "xmark.octagon.fill"
    case .note: "bookmark.fill"
    case .presence: "person.wave.2.fill"
    case .connection: "network"
    }
}
#endif
