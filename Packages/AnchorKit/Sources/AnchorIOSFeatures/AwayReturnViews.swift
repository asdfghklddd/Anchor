#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct HandoffView: View {
    let model: AnchorSessionModel

    @AppStorage(AnchorMotion.reduceMotionDefaultsKey) private var reduceMotion = false
    @State private var secured = false
    @State private var isGathering = false

    var body: some View {
        ZStack {
            HarborBackground()

            Circle()
                .fill(AnchorPalette.aiBlue.opacity(0.17))
                .frame(width: 360, height: 360)
                .blur(radius: 34)
                .offset(y: -90)
                .accessibilityHidden(true)

            VStack(spacing: 38) {
                handoffStage

                VStack(spacing: 10) {
                    Text(secured ? L10n.handoffSecured : L10n.handoff)
                        .font(.title.bold())
                        .foregroundStyle(AnchorIOSStyle.heading)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("handoff.screen")
                    Text(L10n.handoffDetail)
                        .font(.body)
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }

                Button(L10n.atDeskCorrection) {
                    Task { await model.correctPresence(to: .atDesk) }
                }
                .buttonStyle(.bordered)
                .tint(AnchorIOSStyle.action)
                .controlSize(.large)
            }
            .padding(AnchorSpacing.large)
        }
        .accessibilityElement(children: .contain)
        .task {
            guard !reduceMotion else {
                isGathering = true
                secured = true
                return
            }

            withAnimation(AnchorMotion.continuity) {
                isGathering = true
            }
            do {
                try await Task.sleep(for: .milliseconds(540))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            withAnimation(AnchorMotion.micro) { secured = true }
        }
    }

    private var handoffStage: some View {
        ZStack {
            ForEach(Array((model.projection.session?.taskProcesses ?? []).prefix(4).enumerated()), id: \.element.id) { index, process in
                handoffCard(process)
                    .offset(isGathering ? .zero : cardOffset(index))
                    .scaleEffect(isGathering ? 0.36 : 1)
                    .opacity(isGathering ? 0 : 0.92)
            }

            ForEach([138.0, 188.0], id: \.self) { diameter in
                Circle()
                    .stroke(AnchorPalette.aiBlue.opacity(secured ? 0.12 : 0.38), lineWidth: 2)
                    .frame(width: diameter, height: diameter)
                    .scaleEffect(isGathering ? 1 : 0.68)
            }

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AnchorPalette.softBlue, AnchorPalette.aiBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 92, height: 92)
                .overlay {
                    if secured {
                        Image(systemName: "checkmark")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AnchorPalette.brandDeep)
                    } else {
                        HarborAnchorGlyph(lineWidth: 3.2)
                            .frame(width: 38, height: 38)
                    }
                }
                    .shadow(color: AnchorPalette.aiBlue.opacity(0.30), radius: 20)
        }
        .frame(width: 300, height: 270)
        .animation(reduceMotion ? nil : AnchorMotion.continuity, value: isGathering)
        .animation(reduceMotion ? nil : AnchorMotion.micro, value: secured)
        .accessibilityHidden(true)
    }

    private func handoffCard(_ process: AnchorProcess) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 28)
            Capsule().fill(AnchorPalette.ink.opacity(0.17)).frame(width: 62, height: 5)
            Capsule().fill(AnchorPalette.source(process.sourceTone)).frame(width: 44, height: 5)
        }
        .padding(10)
        .frame(width: 98, height: 78, alignment: .leading)
        .background(AnchorPalette.harborWhite, in: .rect(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 8)
    }

    private func cardOffset(_ index: Int) -> CGSize {
        switch index {
        case 0: CGSize(width: -96, height: -72)
        case 1: CGSize(width: 98, height: -64)
        case 2: CGSize(width: -94, height: 78)
        default: CGSize(width: 96, height: 82)
        }
    }
}

struct AwayView: View {
    let projection: SessionProjection
    let model: AnchorSessionModel
    private let onProfile: () -> Void
    private let onNotifications: () -> Void
    private let onLayout: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedProcess: AnchorProcess?

    init(
        projection: SessionProjection,
        model: AnchorSessionModel,
        onProfile: @escaping () -> Void = {},
        onNotifications: @escaping () -> Void = {},
        onLayout: @escaping () -> Void = {}
    ) {
        self.projection = projection
        self.model = model
        self.onProfile = onProfile
        self.onNotifications = onNotifications
        self.onLayout = onLayout
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HarborBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                        awayHeading
                        awaySummary
                        processHeading
                        processGrid

                        Button(L10n.backAtDesk) {
                            Task { await model.beginReturn() }
                        }
                        .buttonStyle(HarborPrimaryButtonStyle())
                        .accessibilityIdentifier("away.return.button")
                        .frame(maxWidth: .infinity)
                        .padding(.top, AnchorSpacing.large)
                    }
                    .padding(.horizontal, AnchorSpacing.medium)
                    .padding(.vertical, AnchorSpacing.medium)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                HarborTopBar(
                    connection: projection.connection,
                    unreadCount: projection.unreadNotificationsCount,
                    auxiliaryLabel: nil,
                    onProfile: onProfile,
                    onNotifications: onNotifications,
                    onAuxiliary: nil
                )
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $selectedProcess) { process in
            NavigationStack {
                ProcessDetailView(
                    process: process,
                    decision: projection.openDecisions.first { $0.processID == process.id },
                    onDecision: { _ in }
                )
            }
            .presentationCornerRadius(24)
        }
    }

    private var awayHeading: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.awayDuration(awayMinutes(at: context.date)), systemImage: "circle.fill")
                    .font(.caption2.bold())
                .foregroundStyle(AnchorPalette.interaction)
                    .padding(.horizontal, 10)
                    .frame(minHeight: 30)
                .background(AnchorPalette.softBlue.opacity(0.55), in: .capsule)
                    .accessibilityIdentifier("away.duration")

                Text(L10n.away)
                    .font(.title.bold())
                    .foregroundStyle(AnchorPalette.brandDeep)
                    .accessibilityIdentifier("away.screen")
                Text(L10n.awayDetail)
                    .font(.footnote)
                    .foregroundStyle(AnchorPalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("away.detail")
            }
        }
    }

    private var awaySummary: some View {
        HarborHeroSurface(cornerRadius: 26) {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.currentAnchor)
                    .font(.caption2.bold())
                    .foregroundStyle(AnchorIOSStyle.action)
                Text(projection.session?.goal.title ?? "")
                    .font(.headline.bold())
                    .foregroundStyle(AnchorIOSStyle.heading)
                    .accessibilityIdentifier("goal.title")
                Text(L10n.routesRunning(runningCount))
                    .font(.footnote)
                    .foregroundStyle(AnchorIOSStyle.secondaryText)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 8
                ) {
                    ForEach(projection.session?.taskProcesses ?? []) { process in
                        HStack(spacing: 6) {
                            SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 20)

                            if let progress = process.progress {
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(AnchorIOSStyle.border)
                                        .overlay(alignment: .leading) {
                                            Capsule()
                                                .fill(AnchorPalette.cyan)
                                                .frame(width: proxy.size.width * progress)
                                        }
                                }
                                .frame(height: 4)
                            } else {
                                Text(L10n.compactStatus(process.status))
                                    .font(.caption2.bold())
                                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 20, alignment: .leading)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(process.sourceName), \(L10n.taskProgress)")
                        .accessibilityValue(
                            process.progress?.formatted(.percent.precision(.fractionLength(0)))
                                ?? L10n.status(process.status)
                        )
                        .accessibilityIdentifier("away.summary.progress")
                    }
                }
            }
            .padding(14)
        }
        .accessibilityIdentifier("away.summary")
    }

    private var processHeading: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.remoteProcesses)
                    .font(.caption2.bold())
                    .foregroundStyle(AnchorPalette.interaction)
                    .accessibilityIdentifier("processes.kicker")
                Text(L10n.synchronizedWork)
                    .font(.headline.bold())
                    .foregroundStyle(AnchorPalette.brandDeep)
            }
            Spacer()
            HStack(spacing: 6) {
                Text(L10n.processAttentionSummary(
                    processes: projection.session?.taskProcesses.count ?? 0,
                    attention: projection.openDecisions.count
                ))
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(AnchorPalette.brandDeep)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 30)
                    .background(AnchorPalette.fluoriteSurface, in: .capsule)
                    .accessibilityIdentifier("away.process.summary")

                Button(action: onLayout) {
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
                .buttonStyle(AnchorPressButtonStyle())
                .accessibilityLabel(L10n.layout)
            }
        }
    }

    private var processGrid: some View {
        LazyVGrid(
            columns: dynamicTypeSize.isAccessibilitySize
                ? [GridItem(.flexible())]
                : [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
            spacing: 10
        ) {
            ForEach(projection.session?.taskProcesses ?? []) { process in
                Button { selectedProcess = process } label: {
                    ProcessCard(process: process, isRemote: true, decorative: true)
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(process.sourceName), \(process.title), \(L10n.status(process.status))")
                .accessibilityValue(
                    process.progress?.formatted(.percent.precision(.fractionLength(0)))
                        ?? L10n.status(process.status)
                )
            }
        }
    }

    private var runningCount: Int {
        projection.session?.taskProcesses.filter { $0.status == .running }.count ?? 0
    }

    private func awayMinutes(at date: Date) -> Int {
        guard let awaySince = projection.session?.snapshots.first?.createdAt else { return 1 }
        return max(1, Int(date.timeIntervalSince(awaySince) / 60))
    }
}
#endif
