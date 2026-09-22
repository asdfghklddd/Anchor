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
        ZStack(alignment: .bottom) {
            HarborBackground()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ProjectionStatusBanners(projection: projection)

                    HarborFocusIntro(session: projection.session)
                        .padding(.top, 10)
                        .padding(.bottom, 12)

                    if projection.session == nil {
                        emptyConnectionCard
                            .padding(.bottom, AnchorSpacing.small)
                    }

                    HarborMissionCard(
                        session: projection.session,
                        onEdit: { onSheet(projection.session == nil ? .setup : .goal) },
                        onFinish: { onSheet(.finish) }
                    )

                    if isObservedWorkComplete {
                        observedCompletionPrompt
                            .padding(.top, AnchorSpacing.small)
                    }

                    Color.clear.frame(height: 20)

                    processHeader

                    if let session = projection.session, !session.processes.isEmpty {
                        processGrid(session: session)
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

    private var processHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.liveProcesses)
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.interaction)
                    .accessibilityIdentifier("processes.kicker")
                Text(L10n.happeningNow)
                    .font(.title3.bold())
                    .foregroundStyle(AnchorPalette.brandDeep)
                    .accessibilityIdentifier("processes.title")
            }
            Spacer()
            HStack(spacing: 7) {
                Label(
                    projection.session == nil ? L10n.preparing : L10n.live,
                    systemImage: projection.session == nil ? "circle.dotted" : "circle.fill"
                )
                    .labelStyle(.titleAndIcon)
                    .font(.caption2.bold())
                    .foregroundStyle(AnchorPalette.interaction)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 32)
                    .background(AnchorPalette.softBlue.opacity(0.52), in: .capsule)
                    .accessibilityIdentifier("processes.live")

                Button {
                    onSheet(projection.session == nil ? .setup : .layout)
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.subheadline.bold())
                        .foregroundStyle(AnchorPalette.interaction)
                        .frame(width: 44, height: 44)
                        .background(AnchorPalette.fluoriteSurface, in: .rect(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AnchorPalette.fluoriteBorder, lineWidth: 1)
                        }
                }
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
        let observed = session.processes.filter { $0.sourceID != nil }
        return !observed.isEmpty && observed.allSatisfy { $0.status == .completed }
    }

    private func processGrid(session: AnchorSession) -> some View {
        LazyVGrid(
            columns: dynamicTypeSize.isAccessibilitySize
                ? [GridItem(.flexible(), spacing: AnchorSpacing.small)]
                : [
                    GridItem(.flexible(), spacing: AnchorSpacing.small),
                    GridItem(.flexible(), spacing: AnchorSpacing.small),
                ],
            spacing: AnchorSpacing.small
        ) {
            ForEach(session.processes) { process in
                Button {
                    if let decision = session.decisions.first(where: {
                        $0.processID == process.id && $0.status == .open
                    }) {
                        onSheet(.decision(decision.id))
                    } else {
                        onRoute(.process(process.id))
                    }
                } label: {
                    ProcessCard(process: process, isRemote: session.presence == .away, decorative: true)
                        .matchedTransitionSource(id: process.id, in: transitionNamespace)
                }
                .buttonStyle(AnchorPressButtonStyle())
                .accessibilityLabel(
                    "\(process.sourceName), \(process.title), \(L10n.status(process.status)), \(process.metric) \(process.metricLabel)"
                )
                .accessibilityValue(
                    process.progress?.formatted(.percent.precision(.fractionLength(0)))
                        ?? L10n.status(process.status)
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
            value: session.processes.map(\.id)
        )
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
