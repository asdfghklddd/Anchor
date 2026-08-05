#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct PortraitDashboard: View {
    let projection: SessionProjection
    let auxiliaryToolbarLabel: String?
    let auxiliaryToolbarAction: (() -> Void)?
    let onRoute: (AnchorRoute) -> Void
    let onSheet: (AnchorSheet) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var anchorPulse = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            HarborBackground()

            if let session = projection.session {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ProjectionStatusBanners(projection: projection)

                        HarborFocusIntro(session: session)
                            .padding(.top, 10)
                            .padding(.bottom, 12)

                        HarborMissionCard(session: session) {
                            onSheet(.goal)
                        }

                        HarborWaveDivider()

                        processHeader

                        processGrid(session: session)
                    }
                    .padding(.horizontal, AnchorSpacing.medium)
                    .padding(.bottom, 138)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }

            if projection.session != nil {
                anchorFooter
            }
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
                    .font(.caption2.bold())
                    .foregroundStyle(AnchorPalette.link)
                    .accessibilityIdentifier("processes.kicker")
                Text(L10n.happeningNow)
                    .font(.headline.bold())
                    .foregroundStyle(AnchorPalette.ink)
                    .accessibilityIdentifier("processes.title")
            }
            Spacer()
            HStack(spacing: 7) {
                Label(L10n.live, systemImage: "circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption2.bold())
                    .foregroundStyle(AnchorPalette.mintInk)
                    .padding(.horizontal, 9)
                    .frame(minHeight: 32)
                    .background(AnchorPalette.seafoam.opacity(0.24), in: .capsule)
                    .accessibilityIdentifier("processes.live")

                Button {
                    onSheet(.layout)
                } label: {
                    Image(systemName: "square.grid.2x2")
                        .font(.subheadline.bold())
                        .foregroundStyle(AnchorPalette.link)
                        .frame(width: 44, height: 44)
                        .background(AnchorPalette.cyan.opacity(0.12), in: .rect(cornerRadius: 14, style: .continuous))
                }
                .accessibilityLabel(L10n.layout)
            }
        }
        .padding(.bottom, 4)
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
                }
                .buttonStyle(.plain)
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
        .animation(reduceMotion ? nil : .spring(duration: 0.48), value: session.processes)
    }

    private var anchorFooter: some View {
        HStack {
            Spacer()
            HarborAnchorControl(label: L10n.dropAnchor) {
                anchorPulse += 1
                onSheet(.note)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: anchorPulse)
            Spacer()
        }
        .padding(.top, 10)
        .padding(.bottom, 2)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(
                colors: [AnchorPalette.paper.opacity(0), AnchorPalette.paper.opacity(0.82)],
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
