#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct HandoffView: View {
    let model: AnchorSessionModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var secured = false
    @State private var isGathering = false

    var body: some View {
        ZStack {
            AnchorPalette.brandDeep.ignoresSafeArea()

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
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("handoff.screen")
                    Text(L10n.handoffDetail)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.70))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                }

                Button(L10n.atDeskCorrection) {
                    Task { await model.correctPresence(to: .atDesk) }
                }
                .buttonStyle(.bordered)
                .tint(.white)
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
            ForEach(Array((model.projection.session?.processes ?? []).prefix(4).enumerated()), id: \.element.id) { index, process in
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
    private let onReturn: (() -> Void)?
    private let onProfile: () -> Void
    private let onNotifications: () -> Void
    private let onLayout: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedProcess: AnchorProcess?

    init(
        projection: SessionProjection,
        model: AnchorSessionModel,
        onReturn: (() -> Void)? = nil,
        onProfile: @escaping () -> Void = {},
        onNotifications: @escaping () -> Void = {},
        onLayout: @escaping () -> Void = {}
    ) {
        self.projection = projection
        self.model = model
        self.onReturn = onReturn
        self.onProfile = onProfile
        self.onNotifications = onNotifications
        self.onLayout = onLayout
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnchorPalette.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                        awayHeading
                        awaySummary
                        processHeading
                        processGrid

                        Button(L10n.atDeskCorrection) {
                            if let onReturn {
                                onReturn()
                            } else {
                                Task { await model.correctPresence(to: .atDesk) }
                            }
                        }
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, AnchorSpacing.large)
                        .frame(minHeight: 50)
                        .background(Color.black, in: .capsule)
                        .buttonStyle(.plain)
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
                    connection: .pairing,
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
            .presentationCornerRadius(30)
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
                    .foregroundStyle(AnchorPalette.oceanHighlight)
                Text(projection.session?.goal.title ?? "")
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("goal.title")
                Text(L10n.routesRunning(runningCount))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.86))

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 8
                ) {
                    ForEach(projection.session?.processes ?? []) { process in
                        HStack(spacing: 6) {
                            SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 20)

                            if let progress = process.progress {
                                GeometryReader { proxy in
                                    Capsule()
                                        .fill(.white.opacity(0.11))
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
                                    .foregroundStyle(.white.opacity(0.86))
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
                    processes: projection.session?.processes.count ?? 0,
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
            ForEach(projection.session?.processes ?? []) { process in
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
        projection.session?.processes.filter { $0.status == .running }.count ?? 0
    }

    private func awayMinutes(at date: Date) -> Int {
        guard let awaySince = projection.session?.snapshots.first?.createdAt else { return 1 }
        return max(1, Int(date.timeIntervalSince(awaySince) / 60))
    }
}

struct ReturnView: View {
    let projection: SessionProjection
    let model: AnchorSessionModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDecision: Decision?
    @State private var showChanges = false

    var body: some View {
        NavigationStack {
            ZStack {
                AnchorPalette.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                        returnHero
                        impactCard
                        changesDisclosure
                        if let recommendedProcess { nextStepCard(recommendedProcess) }
                    }
                    .padding(.horizontal, AnchorSpacing.medium)
                    .padding(.bottom, 104)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .top, spacing: 0) { returnNav }
            .safeAreaInset(edge: .bottom, spacing: 0) { returnFooter }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $selectedDecision) { decision in
            DecisionView(model: model, decision: decision)
        }
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
    }

    private var returnNav: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    HStack {
                        returnCloseButton
                        Spacer(minLength: 8)
                        returnConnection
                    }
                    Text(L10n.returnNavigationTitle)
                        .font(.headline.bold())
                        .foregroundStyle(AnchorPalette.brandDeep)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("return.nav")
                }
            } else {
                ZStack {
                    HStack {
                        returnCloseButton
                        Spacer()
                        returnConnection
                    }

                    Text(L10n.returnNavigationTitle)
                        .font(.headline.bold())
                        .foregroundStyle(AnchorPalette.brandDeep)
                        .accessibilityIdentifier("return.nav")
                }
            }
        }
        .padding(.horizontal, AnchorSpacing.medium)
        .frame(minHeight: 50)
        .background(AnchorPalette.canvas.opacity(0.97))
        .overlay(alignment: .bottom) {
            Rectangle().fill(AnchorPalette.fluoriteBorder).frame(height: 1)
        }
    }

    private var returnCloseButton: some View {
        Button {
            Task { await model.continueWorking() }
        } label: {
            ZStack {
                Color.clear
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
            }
            .frame(width: 44, height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(L10n.close)
        .accessibilityHint(L10n.continueWorking)
        .accessibilityIdentifier("return.nav.close")
    }

    private var returnConnection: some View {
        Label(L10n.connected, systemImage: "circle.fill")
            .font(.caption.bold())
            .foregroundStyle(AnchorPalette.interaction)
            .accessibilityIdentifier("return.nav.connection")
    }

    private var returnHero: some View {
        HarborHeroSurface(cornerRadius: 26) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 14) {
                    returnVisual
                    returnHeroCopy
                }

                VStack(alignment: .leading, spacing: 14) {
                    returnVisual
                    returnHeroCopy
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
    }

    private var returnVisual: some View {
        ZStack {
            Circle()
                .stroke(AnchorPalette.aiBlue.opacity(0.34), lineWidth: 1)
                .frame(width: 82, height: 82)

            Circle()
                .stroke(.white.opacity(0.16), lineWidth: 1)
                .frame(width: 58, height: 58)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AnchorPalette.softBlue, AnchorPalette.aiBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 42, height: 42)
                .overlay {
                    HarborAnchorGlyph(color: AnchorPalette.brandDeep, lineWidth: 2.1)
                        .frame(width: 24, height: 24)
                }
                .shadow(color: AnchorPalette.brandDeep.opacity(0.18), radius: 8, y: 5)

            Circle()
                .fill(AnchorPalette.attention)
                .frame(width: 6, height: 6)
                .offset(y: -35)
            Circle()
                .fill(AnchorPalette.aiBlue)
                .frame(width: 6, height: 6)
                .offset(x: 33, y: 17)
            Circle()
                .fill(AnchorPalette.interaction)
                .frame(width: 6, height: 6)
                .offset(x: -28, y: 25)
        }
        .frame(width: 86, height: 86)
        .accessibilityHidden(true)
    }

    private var returnHeroCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(L10n.returning) · \(L10n.awayDuration(awayMinutes))")
                .font(.caption2.bold())
                .foregroundStyle(AnchorPalette.softBlue)
                .accessibilityIdentifier("return.hero.eyebrow")

            Text("\(L10n.returning),")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .accessibilityIdentifier("return.screen")

            Text(L10n.returnHeadline)
                .font(.title2.bold())
                .foregroundStyle(.white)
                .accessibilityIdentifier("return.hero.headline")

            Text(projection.session?.goal.title ?? "")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("return.goal.title")
        }
    }

    private var impactCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.returnChanges)
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.interaction)
                Spacer()
                Text("\(changes.count)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(AnchorPalette.interaction, in: .capsule)
            }
            Text(L10n.returnChangesSummary(changes.count))
                .font(.headline.bold())
                .foregroundStyle(AnchorPalette.brandDeep)
            Text(recommendedProcess?.detail ?? L10n.returnDetail)
                .font(.body)
                .foregroundStyle(AnchorPalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        impactMetric("\(changes.count)", label: L10n.returnResultsUpdated)
                        impactMetric("\(runningCount)", label: L10n.returnStillRunning)
                        impactMetric("\(projection.openDecisions.count)", label: L10n.returnWaitingJudgment)
                    }
                } else {
                    HStack(spacing: 0) {
                        impactMetric("\(changes.count)", label: L10n.returnResultsUpdated)
                        Divider().padding(.vertical, 7)
                        impactMetric("\(runningCount)", label: L10n.returnStillRunning)
                        Divider().padding(.vertical, 7)
                        impactMetric("\(projection.openDecisions.count)", label: L10n.returnWaitingJudgment)
                    }
                }
            }
        }
        .padding(16)
        .fluoriteSurface(
            fill: AnchorPalette.softBlue.opacity(0.30),
            border: AnchorPalette.aiBlue.opacity(0.28),
            cornerRadius: 18
        )
    }

    private func impactMetric(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.brandDeep)
                .contentTransition(.numericText())
            Text(label).font(.caption2).foregroundStyle(AnchorPalette.secondaryText)
                .accessibilityIdentifier("return.impact.metric")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var changesDisclosure: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : AnchorMotion.continuity) { showChanges.toggle() }
            } label: {
                HStack {
                    Label(L10n.returnChangesSummary(changes.count), systemImage: "clock.arrow.circlepath")
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .rotationEffect(.degrees(showChanges ? 180 : 0))
                }
                .foregroundStyle(AnchorPalette.brandDeep)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 48)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if showChanges {
                Divider().padding(.horizontal, 14)
                VStack(spacing: 12) {
                    ForEach(changes) { change in
                        HStack(alignment: .top, spacing: 10) {
                            Text(change.occurredAt, style: .time)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(AnchorPalette.secondaryText)
                                .frame(width: 42, alignment: .leading)
                            Circle()
                                .fill(AnchorPalette.aiBlue)
                                .frame(width: 8, height: 8)
                                .padding(.top, 4)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(change.title).font(.subheadline.bold()).foregroundStyle(AnchorPalette.brandDeep)
                                Text(change.detail).font(.caption).foregroundStyle(AnchorPalette.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .fluoriteSurface(cornerRadius: 14)
    }

    private func nextStepCard(_ process: AnchorProcess) -> some View {
        Button {
            selectedDecision = projection.openDecisions.first { $0.processID == process.id }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark")
                    .font(.body.bold())
                    .foregroundStyle(AnchorPalette.brandDeep)
                    .frame(width: 36, height: 36)
                    .background(AnchorPalette.attention.opacity(0.24), in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.yourNextStep)
                        .font(.caption2.bold())
                        .foregroundStyle(AnchorPalette.brandDeep)
                        .accessibilityIdentifier("return.next.content")
                    Text(process.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AnchorPalette.brandDeep)
                        .accessibilityIdentifier("return.next.content")
                    Text(process.detail)
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.secondaryText)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("return.next.content")
                    Text(L10n.returnContinueHint)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AnchorPalette.interaction)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("return.next.content")
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(AnchorPalette.brandDeep)
            }
            .padding(15)
            .fluoriteSurface(
                fill: AnchorPalette.attention.opacity(0.20),
                border: AnchorPalette.attention.opacity(0.60),
                cornerRadius: 18,
                elevated: true
            )
        }
        .buttonStyle(AnchorPressButtonStyle())
        .disabled(projection.openDecisions.first { $0.processID == process.id } == nil)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("return.next.step")
    }

    private var returnFooter: some View {
        Button {
            if let decision = projection.openDecisions.first {
                selectedDecision = decision
            } else {
                Task { await model.continueWorking() }
            }
        } label: {
            Label(L10n.continueWorking, systemImage: "play.fill")
                .accessibilityIdentifier("return.continue.label")
        }
        .buttonStyle(HarborPrimaryButtonStyle())
        .accessibilityIdentifier("return.continue.button")
        .padding(.horizontal, AnchorSpacing.medium)
        .padding(.top, 10)
        .padding(.bottom, 5)
        .background(AnchorPalette.canvas.opacity(0.97))
    }

    private var changes: [ReturnChange] {
        projection.session?.returnSummary?.changes ?? []
    }

    private var runningCount: Int {
        projection.session?.processes.filter { $0.status == .running }.count ?? 0
    }

    private var awayMinutes: Int {
        guard let summary = projection.session?.returnSummary else { return 18 }
        return max(1, Int(summary.generatedAt.timeIntervalSince(summary.awaySince) / 60))
    }

    private var recommendedProcess: AnchorProcess? {
        guard let id = projection.session?.returnSummary?.recommendedProcessID else { return nil }
        return projection.session?.processes.first { $0.id == id }
    }
}
#endif
