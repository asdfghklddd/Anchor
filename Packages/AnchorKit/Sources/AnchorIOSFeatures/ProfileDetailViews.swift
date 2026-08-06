#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

enum ProfileInfoKind: Hashable {
    case account
    case icloud
}

struct ProfileInfoSheet: View {
    let kind: ProfileInfoKind

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                HarborBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                        HarborHeroSurface(cornerRadius: 26) {
                            VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                                Image(systemName: symbol)
                                    .font(.title2.bold())
                                    .foregroundStyle(AnchorPalette.deepSea)
                                    .frame(width: 52, height: 52)
                                    .background(AnchorPalette.oceanHighlight, in: .circle)

                                Text(headline)
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)

                                Text(copy)
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.78))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(AnchorSpacing.medium)
                        }

                        VStack(spacing: 0) {
                            ForEach(Array(facts.enumerated()), id: \.offset) { index, fact in
                                HStack(alignment: .firstTextBaseline, spacing: AnchorSpacing.small) {
                                    Text(fact.label)
                                        .font(.subheadline)
                                        .foregroundStyle(AnchorPalette.secondaryInk)
                                    Spacer(minLength: AnchorSpacing.small)
                                    Text(fact.value)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(AnchorPalette.ink)
                                        .multilineTextAlignment(.trailing)
                                }
                                .frame(minHeight: 52)
                                if index < facts.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(.horizontal, AnchorSpacing.medium)
                        .background(AnchorPalette.surface, in: .rect(cornerRadius: 22, style: .continuous))

                        Button(L10n.done) {
                            dismiss()
                        }
                        .buttonStyle(HarborPrimaryButtonStyle())
                    }
                    .padding(AnchorSpacing.medium)
                    .frame(maxWidth: 680)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("profile.info.\(String(describing: kind))")
    }

    private var title: String {
        switch kind {
        case .account:
            AnchorStrings.value("profile.account.title", default: "Account settings")
        case .icloud:
            AnchorStrings.value("profile.icloud.title", default: "iCloud sync")
        }
    }

    private var headline: String {
        switch kind {
        case .account:
            L10n.profile
        case .icloud:
            L10n.contextSyncStable
        }
    }

    private var copy: String {
        switch kind {
        case .account:
            AnchorStrings.value(
                "profile.account.copy",
                default: "Anchor uses this iPhone as your local identity. No sign-in is required."
            )
        case .icloud:
            AnchorStrings.value(
                "profile.icloud.copy",
                default: "Goals, process states, and return notes stay consistent across your Apple devices."
            )
        }
    }

    private var symbol: String {
        switch kind {
        case .account: "person.crop.circle"
        case .icloud: "icloud"
        }
    }

    private var facts: [(label: String, value: String)] {
        switch kind {
        case .account:
            [
                (AnchorStrings.value("profile.account.device", default: "Device"), AnchorStrings.value("profile.account.device.value", default: "This iPhone")),
                (AnchorStrings.value("profile.account.workspace", default: "Workspace"), AnchorStrings.value("profile.account.workspace.value", default: "Personal")),
                (AnchorStrings.value("profile.account.identity", default: "Sync identity"), AnchorStrings.value("profile.account.identity.value", default: "iCloud account on this device")),
            ]
        case .icloud:
            [
                (AnchorStrings.value("profile.icloud.status", default: "Current status"), L10n.connected),
                (AnchorStrings.value("profile.icloud.last.sync", default: "Last sync"), AnchorStrings.value("profile.icloud.just.now", default: "Just now")),
                (AnchorStrings.value("profile.icloud.scope", default: "Sync scope"), AnchorStrings.value("profile.icloud.scope.value", default: "Goals and process states")),
            ]
        }
    }
}

struct ProfileDetailSheet: View {
    let projection: SessionProjection
    let kind: ProfileDetailKind
    let onManage: () -> Void
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                HarborBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                        detailHero

                        if kind == .session {
                            sessionMetrics
                            processPulse
                        } else {
                            trendSection
                        }

                        recentSection

                        if kind == .session {
                            HStack(spacing: AnchorSpacing.small) {
                                Button(L10n.taskManagement, action: onManage)
                                    .buttonStyle(.borderedProminent)
                                    .tint(AnchorPalette.link)
                                Button(L10n.finish, action: onFinish)
                                    .buttonStyle(.bordered)
                                    .tint(AnchorPalette.link)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Button {
                                dismiss()
                            } label: {
                                Label(L10n.done, systemImage: "checkmark")
                            }
                            .buttonStyle(HarborPrimaryButtonStyle())
                        }
                    }
                    .padding(AnchorSpacing.medium)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("profile.detail.\(String(describing: kind))")
    }

    private var detailHero: some View {
        AnchorCard(tint: kind.tint) {
            VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                HStack(alignment: .top, spacing: AnchorSpacing.small) {
                    Image(systemName: kind.symbol)
                        .font(.title3.bold())
                        .foregroundStyle(kind.tint)
                        .frame(width: 42, height: 42)
                        .background(kind.tint.opacity(0.14), in: .circle)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(kind.kicker)
                            .font(.caption2.bold())
                            .foregroundStyle(AnchorPalette.link)
                        Text(kind.value(projection: projection))
                            .font(.title.bold().monospacedDigit())
                            .foregroundStyle(AnchorPalette.ink)
                    }
                    Spacer(minLength: 0)
                }

                Text(kind.headline)
                    .font(.title2.bold())
                    .foregroundStyle(AnchorPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(kind.subline(projection: projection))
                    .font(.body)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(AnchorStrings.value("profile.detail.trend", default: "TREND"))
                        .font(.caption2.bold())
                        .foregroundStyle(AnchorPalette.link)
                    Text(AnchorStrings.value("profile.detail.recent.records", default: "Recent records"))
                        .font(.title3.bold())
                        .foregroundStyle(AnchorPalette.ink)
                }
                Spacer()
                Text(AnchorStrings.value("profile.detail.steady", default: "Stable"))
                    .font(.caption.bold())
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }

            HStack(alignment: .bottom, spacing: 5) {
                ForEach(Array(kind.bars.enumerated()), id: \.offset) { _, height in
                    Capsule()
                        .fill(kind.tint.opacity(0.82))
                        .frame(maxWidth: .infinity)
                        .frame(height: 110 * height)
                }
            }
            .frame(height: 120, alignment: .bottom)
            .padding(.horizontal, AnchorSpacing.small)
            .padding(.top, AnchorSpacing.small)
            .background(kind.tint.opacity(0.10), in: .rect(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(AnchorStrings.value("profile.detail.chart", default: "Recent twelve records trend"))
        }
    }

    private var sessionMetrics: some View {
        HStack(spacing: 0) {
            profileMetric(L10n.minuteCount(focusMinutes), label: L10n.focusTime)
            Divider().padding(.vertical, 8)
            profileMetric(projection.overallProgress?.formatted(.percent.precision(.fractionLength(0))) ?? "—", label: L10n.overallProgress)
            Divider().padding(.vertical, 8)
            profileMetric("\(completedCount)/\(processCount)", label: L10n.completedWork)
        }
        .padding(.vertical, AnchorSpacing.small)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 20, style: .continuous))
    }

    private func profileMetric(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(AnchorPalette.ink)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var processPulse: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            sectionHeading(
                kicker: AnchorStrings.value("profile.detail.process.pulse", default: "PROCESS PULSE"),
                title: L10n.processFlow
            )
            VStack(spacing: 0) {
                ForEach(processes) { process in
                    HStack(spacing: AnchorSpacing.small) {
                        SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(process.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(AnchorPalette.ink)
                            Text("\(process.sourceName) · \(L10n.status(process.status))")
                                .font(.caption2)
                                .foregroundStyle(AnchorPalette.secondaryInk)
                        }
                        Spacer(minLength: 4)
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(process.progress ?? 0, format: .percent.precision(.fractionLength(0)))
                                .font(.caption.bold().monospacedDigit())
                                .foregroundStyle(AnchorPalette.ink)
                            AnchorProgress(value: process.progress ?? 0, tint: AnchorPalette.source(process.sourceTone))
                                .frame(width: 64)
                        }
                    }
                    .padding(.vertical, 10)
                    if process.id != processes.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .padding(.horizontal, AnchorSpacing.small)
            .background(AnchorPalette.surface, in: .rect(cornerRadius: 22, style: .continuous))
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            sectionHeading(
                kicker: AnchorStrings.value("profile.detail.memory.trace", default: "MEMORY TRACE"),
                title: AnchorStrings.value("profile.detail.key.memory", default: "Key memories")
            )
            VStack(spacing: 0) {
                if timeline.isEmpty {
                    Text(L10n.noEvents)
                        .font(.subheadline)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AnchorSpacing.medium)
                } else {
                    ForEach(Array(timeline.enumerated()), id: \.element.id) { index, event in
                        HStack(alignment: .top, spacing: AnchorSpacing.small) {
                            Text(event.occurredAt, style: .time)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(AnchorPalette.secondaryInk)
                                .frame(width: 44, alignment: .leading)
                            Circle()
                                .fill(index == 0 ? kind.tint : AnchorPalette.secondaryInk.opacity(0.35))
                                .frame(width: 8, height: 8)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(event.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(AnchorPalette.ink)
                                if !event.detail.isEmpty {
                                    Text(event.detail)
                                        .font(.caption)
                                        .foregroundStyle(AnchorPalette.secondaryInk)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 11)
                        if index < timeline.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
            }
            .padding(.horizontal, AnchorSpacing.small)
            .background(AnchorPalette.surface, in: .rect(cornerRadius: 22, style: .continuous))
        }
    }

    private func sectionHeading(kicker: String, title: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(kicker)
                .font(.caption2.bold())
                .foregroundStyle(AnchorPalette.link)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(AnchorPalette.ink)
        }
    }

    private var processes: [AnchorProcess] {
        projection.session?.processes ?? []
    }

    private var timeline: [ProcessEvent] {
        Array((projection.session?.timeline ?? []).prefix(3))
    }

    private var processCount: Int { processes.count }
    private var completedCount: Int { processes.filter { $0.status == .completed }.count }
    private var focusMinutes: Int {
        guard let startedAt = projection.session?.startedAt else { return 0 }
        return max(0, Int(Date.now.timeIntervalSince(startedAt) / 60))
    }
}

private extension ProfileDetailKind {
    var title: String {
        switch self {
        case .focus: L10n.history
        case .contexts: L10n.savedContexts
        case .anchors: L10n.completedAnchors
        case .session: L10n.sessionSummary
        case .returnMemory: L10n.returning
        case .decisionTrace: L10n.decisions
        case .contextSnapshot: L10n.contextNote
        }
    }

    var symbol: String {
        switch self {
        case .focus: "timer"
        case .contexts: "square.stack.3d.up"
        case .anchors: "scope"
        case .session: "waveform.path.ecg"
        case .returnMemory: "arrow.uturn.left.circle"
        case .decisionTrace: "checkmark.bubble"
        case .contextSnapshot: "square.stack.3d.up"
        }
    }

    var tint: Color {
        switch self {
        case .focus, .decisionTrace: AnchorPalette.coral
        case .contexts, .contextSnapshot: AnchorPalette.periwinkle
        case .anchors, .session, .returnMemory: AnchorPalette.seafoam
        }
    }

    var kicker: String {
        switch self {
        case .focus: AnchorStrings.value("profile.detail.focus.kicker", default: "FOCUS ARCHIVE")
        case .contexts: AnchorStrings.value("profile.detail.contexts.kicker", default: "CONTEXT VAULT")
        case .anchors: AnchorStrings.value("profile.detail.anchors.kicker", default: "ANCHOR LOG")
        case .session: AnchorStrings.value("profile.detail.session.kicker", default: "CURRENT ANCHOR")
        case .returnMemory: AnchorStrings.value("profile.detail.return.kicker", default: "RETURN MEMORY")
        case .decisionTrace: AnchorStrings.value("profile.detail.decision.kicker", default: "DECISION TRACE")
        case .contextSnapshot: AnchorStrings.value("profile.detail.snapshot.kicker", default: "CONTEXT SNAPSHOT")
        }
    }

    var headline: String {
        switch self {
        case .focus: AnchorStrings.value("profile.detail.focus.headline", default: "Focus is not just time. It is continuity.")
        case .contexts: AnchorStrings.value("profile.detail.contexts.headline", default: "Every departure keeps a world to return to.")
        case .anchors: AnchorStrings.value("profile.detail.anchors.headline", default: "Completion preserves the thread of the work.")
        case .session: AnchorStrings.value("profile.detail.session.headline", default: "The full shape of this work, held in one place.")
        case .returnMemory: AnchorStrings.value("profile.detail.return.headline", default: "The work stayed in the right place while you were away.")
        case .decisionTrace: AnchorStrings.value("profile.detail.decision.headline", default: "A clear judgment keeps the next steps moving.")
        case .contextSnapshot: AnchorStrings.value("profile.detail.snapshot.headline", default: "Goal, processes, decisions, and position in one memory.")
        }
    }

    func value(projection: SessionProjection) -> String {
        switch self {
        case .focus: L10n.minuteCount(max(0, Int(Date.now.timeIntervalSince(projection.session?.startedAt ?? .now) / 60)))
        case .contexts: "\((projection.session?.notes.count ?? 0) + (projection.session?.snapshots.count ?? 0))"
        case .anchors: "\(projection.session?.processes.filter { $0.status == .completed }.count ?? 0)"
        case .session, .returnMemory: projection.overallProgress?.formatted(.percent.precision(.fractionLength(0))) ?? "—"
        case .decisionTrace: projection.openDecisions.isEmpty ? "✓" : "1"
        case .contextSnapshot: "\(projection.session?.processes.count ?? 0)/\(projection.session?.processes.count ?? 0)"
        }
    }

    func subline(projection: SessionProjection) -> String {
        switch self {
        case .focus: AnchorStrings.value("profile.detail.focus.subline", default: "Recent focus sessions and the judgments they protected.")
        case .contexts: AnchorStrings.value("profile.detail.contexts.subline", default: "Saved goals, process states, and notes remain available.")
        case .anchors: AnchorStrings.value("profile.detail.anchors.subline", default: "Completed work is preserved as a recoverable context.")
        case .session: L10n.runningAndWaiting(running: projection.session?.processes.filter { $0.status == .running }.count ?? 0, attention: projection.openDecisions.count)
        case .returnMemory: L10n.returnDetail
        case .decisionTrace:
            projection.openDecisions.isEmpty
                ? AnchorStrings.value("profile.detail.decision.resolved", default: "The current decision has been resolved.")
                : AnchorStrings.value("profile.detail.decision.waiting", default: "A decision is waiting for your judgment.")
        case .contextSnapshot: L10n.contextNote
        }
    }

    var bars: [CGFloat] {
        switch self {
        case .focus: [0.34, 0.48, 0.38, 0.72, 0.61, 0.84, 0.68, 0.92, 0.76, 0.88, 0.64, 0.96]
        case .contexts: [0.74, 0.88, 0.82, 0.96, 0.91, 1, 0.86, 0.94, 0.97, 0.93, 1, 0.96]
        case .anchors: [0.22, 0.42, 0.38, 0.58, 0.52, 0.70, 0.66, 0.78, 0.72, 0.84, 0.88, 0.86]
        case .session: []
        case .returnMemory: [0.92, 0.94, 0.88, 0.96, 0.95, 1, 0.91, 0.96, 0.98, 0.94, 0.97, 0.96]
        case .decisionTrace: [0.18, 0.22, 0.30, 0.34, 0.48, 0.55, 0.63, 0.72, 0.78, 0.84, 0.92, 1]
        case .contextSnapshot: [1, 1, 0.96, 1, 0.92, 1, 1, 0.96, 1, 1, 0.96, 1]
        }
    }
}
#endif
