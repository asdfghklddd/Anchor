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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AnchorSpacing.large) {
                if projection.errorMessage != nil {
                    errorBanner
                } else if projection.isStale {
                    staleBanner
                }

                if projection.session?.presence == .unknown {
                    unknownPresenceBanner
                }

                goalCard

                processHeader

                processGrid

                if let event = projection.session?.timeline.first {
                    latestEvent(event)
                }

                quickLinks
                    .padding(.bottom, 86)
            }
            .padding(.horizontal, AnchorSpacing.medium)
            .padding(.top, AnchorSpacing.small)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .background(AnchorPalette.paper)
        .accessibilityIdentifier("workspace.screen")
        .navigationTitle(L10n.workspace)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { onRoute(.profile) } label: {
                    Label(L10n.profile, systemImage: "person.crop.circle.fill")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                }
                .accessibilityLabel(L10n.profile)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if let auxiliaryToolbarLabel, let auxiliaryToolbarAction {
                    Button(action: auxiliaryToolbarAction) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel(auxiliaryToolbarLabel)
                }
                Button { onSheet(.notifications) } label: {
                    Image(systemName: projection.unreadNotificationsCount > 0 ? "bell.badge.fill" : "bell")
                }
                .accessibilityLabel(L10n.notifications)
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack {
                Spacer()
                Button {
                    anchorPulse += 1
                    onSheet(.note)
                } label: {
                    if dynamicTypeSize.isAccessibilitySize {
                        AnchorMark(size: 54)
                            .padding(8)
                    } else {
                        VStack(spacing: 4) {
                            AnchorMark(size: 62)
                            Text(L10n.anchorNote)
                                .font(.caption.bold())
                                .foregroundStyle(AnchorPalette.ink)
                        }
                        .padding(.horizontal, AnchorSpacing.medium)
                        .padding(.top, 8)
                    }
                }
                .background(.ultraThinMaterial, in: .capsule)
                .buttonStyle(.plain)
                .frame(minWidth: 88, minHeight: 76)
                .accessibilityLabel(L10n.anchorNote)
                .accessibilityIdentifier("anchor.note.button")
                .sensoryFeedback(.impact(weight: .medium), trigger: anchorPulse)
                .padding(.bottom, 4)
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer()
                }
            }
            .padding(.horizontal, AnchorSpacing.small)
        }
    }

    @ViewBuilder
    private var processHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                processTitle
                layoutButton
            }
        } else {
            HStack {
                processTitle
                Spacer()
                layoutButton
            }
        }
    }

    private var processTitle: some View {
        Text(L10n.processes)
            .font(.title2.bold())
            .foregroundStyle(AnchorPalette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("processes.title")
    }

    private var layoutButton: some View {
        Button { onSheet(.layout) } label: {
            Text(L10n.layout)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AnchorPalette.ink)
                .frame(minWidth: 64, minHeight: 48)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var goalCard: some View {
        AnchorCard(tint: AnchorPalette.seafoam) {
            VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L10n.currentGoal)
                        .font(.caption.bold())
                        .foregroundStyle(AnchorPalette.secondaryInk)
                    Spacer()
                    Button { onSheet(.goal) } label: {
                        Text(L10n.editGoal)
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                            .frame(minWidth: 64, minHeight: 48)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("goal.edit.button")
                }
                Text(projection.session?.goal.title ?? "")
                    .font(.title.bold())
                    .foregroundStyle(AnchorPalette.ink)
                    .accessibilityIdentifier("goal.title")
                Text(projection.session?.goal.completionCriteria ?? "")
                    .font(.body)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                if let progress = projection.overallProgress {
                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text(L10n.overallProgress)
                            Spacer()
                            Text(progress, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                        }
                        .font(.footnote.weight(.semibold))
                        AnchorProgress(
                            value: progress,
                            tint: AnchorPalette.seafoam,
                            isRemote: projection.session?.presence == .away
                        )
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var processGrid: some View {
        LazyVGrid(
            columns: dynamicTypeSize.isAccessibilitySize
                ? [GridItem(.flexible(), spacing: AnchorSpacing.medium)]
                : [
                    GridItem(.flexible(), spacing: AnchorSpacing.medium),
                    GridItem(.flexible(), spacing: AnchorSpacing.medium),
                ],
            spacing: AnchorSpacing.medium
        ) {
            ForEach(projection.session?.processes ?? []) { process in
                ZStack {
                    ProcessCard(process: process, isRemote: projection.session?.presence == .away)
                    Button {
                        if let decision = projection.session?.decisions.first(where: {
                            $0.processID == process.id && $0.status == .open
                        }) {
                            onSheet(.decision(decision.id))
                        } else {
                            onRoute(.process(process.id))
                        }
                    } label: {
                        Color.clear
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(.rect)
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
        }
        .animation(reduceMotion ? .linear(duration: 0.15) : .spring(duration: 0.48), value: projection.session?.processes)
    }

    private func latestEvent(_ event: ProcessEvent) -> some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            Text(L10n.recentEvent)
                .font(.headline)
            HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                Image(systemName: eventSymbol(event.kind))
                    .foregroundStyle(AnchorPalette.coral)
                    .frame(width: 32, height: 32)
                    .background(AnchorPalette.coral.opacity(0.16), in: .rect(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title).font(.subheadline.weight(.semibold))
                    if !event.detail.isEmpty {
                        Text(event.detail)
                            .font(.footnote)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    }
                    Text(event.occurredAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(AnchorSpacing.medium)
            .background(AnchorPalette.surface, in: .rect(cornerRadius: 20, style: .continuous))
        }
    }

    private var quickLinks: some View {
        HStack(spacing: AnchorSpacing.small) {
            quickLink(L10n.insights, symbol: "point.3.connected.trianglepath.dotted") {
                onRoute(.insights)
            }
            quickLink(L10n.history, symbol: "clock.arrow.circlepath") {
                onRoute(.history)
            }
            quickLink(L10n.finish, symbol: "checkmark.seal") {
                onSheet(.finish)
            }
        }
    }

    private func quickLink(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: symbol).font(.title3)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(AnchorPalette.ink)
            .frame(maxWidth: .infinity, minHeight: 72)
            .background(AnchorPalette.surface, in: .rect(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var unknownPresenceBanner: some View {
        Label {
            VStack(alignment: .leading) {
                Text(L10n.connectionUnknown).font(.subheadline.bold())
                Text(L10n.connectionUnknownDetail).font(.caption)
            }
        } icon: {
            Image(systemName: "location.slash.fill")
        }
        .foregroundStyle(AnchorPalette.ink)
        .padding(AnchorSpacing.medium)
        .background(AnchorPalette.sand.opacity(0.28), in: .rect(cornerRadius: 18))
    }

    private var staleBanner: some View {
        Label(L10n.stale, systemImage: "clock.badge.exclamationmark")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AnchorSpacing.medium)
            .background(AnchorPalette.sand.opacity(0.28), in: .rect(cornerRadius: 18))
    }

    private var errorBanner: some View {
        Label(projection.errorMessage ?? "", systemImage: "wifi.exclamationmark")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AnchorSpacing.medium)
            .background(AnchorPalette.coral.opacity(0.22), in: .rect(cornerRadius: 18))
    }
}

struct ProcessCard: View {
    let process: AnchorProcess
    let isRemote: Bool

    private var tint: Color { AnchorPalette.source(process.sourceTone) }

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            HStack(alignment: .top) {
                SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone)
                Spacer()
                StatusBadge(
                    status: process.status,
                    text: L10n.compactStatus(process.status),
                    decorative: true
                )
            }
            Text(process.sourceName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AnchorPalette.secondaryInk)
            Text(process.title)
                .font(.headline)
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(3)
            Spacer(minLength: 4)
            Text(process.metric)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.ink)
            Text(process.metricLabel)
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
            if let progress = process.progress {
                AnchorProgress(value: progress, tint: tint, isRemote: isRemote)
            }
        }
        .padding(AnchorSpacing.medium)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .background(tint.opacity(0.22), in: .rect(cornerRadius: 24, style: .continuous))
        .overlay(alignment: .top) {
            Capsule().fill(.white.opacity(0.45)).frame(height: 2).padding(.horizontal, 20)
        }
        .shadow(color: tint.opacity(0.18), radius: 12, y: 7)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
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
