#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct HandoffView: View {
    let model: AnchorSessionModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AnchorSpacing.large) {
            if reduceMotion {
                AnchorMark(size: 88)
            } else {
                AnchorMark(size: 88)
                    .symbolEffect(.breathe, options: .repeating)
            }
            Text(L10n.handoff)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Button(L10n.atDeskCorrection) {
                Task { await model.correctPresence(to: .atDesk) }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .foregroundStyle(AnchorPalette.ink)
        .padding(AnchorSpacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AnchorPalette.paper)
    }
}

struct AwayView: View {
    let projection: SessionProjection
    let model: AnchorSessionModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                    VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                        Label(L10n.away, systemImage: "figure.walk.motion")
                            .font(.largeTitle.bold())
                        Text(L10n.awayDetail)
                            .font(.title3)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    }
                    AnchorCard(tint: AnchorPalette.seafoam) {
                        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                            Text(L10n.currentGoal).font(.caption.bold())
                            Text(projection.session?.goal.title ?? "")
                                .font(.title2.bold())
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(projection.session?.goal.title ?? "")
                                .accessibilityIdentifier("goal.title")
                            Text(projection.session?.goal.completionCriteria ?? "")
                                .foregroundStyle(AnchorPalette.secondaryInk)
                        }
                    }
                    ForEach(projection.session?.processes ?? []) { process in
                        HStack(spacing: AnchorSpacing.medium) {
                            Text(process.sourceSymbol)
                                .font(.headline.bold())
                                .frame(width: 42, height: 42)
                                .background(
                                    AnchorPalette.source(process.sourceTone).opacity(0.55),
                                    in: .rect(cornerRadius: 13)
                                )
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(process.title).font(.headline)
                                StatusBadge(status: process.status, text: L10n.status(process.status))
                                if let progress = process.progress {
                                    AnchorProgress(
                                        value: progress,
                                        tint: AnchorPalette.source(process.sourceTone),
                                        isRemote: true
                                    )
                                }
                            }
                        }
                        .padding(AnchorSpacing.medium)
                        .background(AnchorPalette.surface, in: .rect(cornerRadius: 20))
                        .accessibilityElement(children: .contain)
                    }
                    Button(L10n.atDeskCorrection) {
                        Task { await model.correctPresence(to: .atDesk) }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                }
                .padding(AnchorSpacing.large)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(AnchorPalette.paper)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct ReturnView: View {
    let projection: SessionProjection
    let model: AnchorSessionModel
    let onNote: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                    VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                        AnchorMark(size: 66)
                        Text(L10n.returning)
                            .font(.largeTitle.bold())
                        Text(L10n.returnDetail)
                            .font(.title3)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    }
                    AnchorCard(tint: AnchorPalette.seafoam) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(L10n.currentGoal).font(.caption.bold())
                            Text(projection.session?.goal.title ?? "")
                                .font(.title2.bold())
                            if let summary = projection.session?.returnSummary {
                                Text(summary.awaySince, style: .relative)
                                    .font(.subheadline)
                                    .foregroundStyle(AnchorPalette.secondaryInk)
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    if let recommended = recommendedProcess {
                        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                            Text(L10n.recommendedNext).font(.headline)
                            Label(recommended.title, systemImage: "arrow.right.circle.fill")
                                .font(.title3.bold())
                                .padding(AnchorSpacing.medium)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AnchorPalette.sand.opacity(0.30), in: .rect(cornerRadius: 20))
                        }
                    }
                    VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                        ForEach(projection.session?.returnSummary?.changes ?? []) { change in
                            HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                                Image(systemName: eventSymbol(change.kind))
                                    .frame(width: 36, height: 36)
                                    .background(AnchorPalette.cyan.opacity(0.25), in: .circle)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(change.title).font(.headline)
                                    Text(change.detail)
                                        .font(.subheadline)
                                        .foregroundStyle(AnchorPalette.secondaryInk)
                                    Text(change.occurredAt, style: .time)
                                        .font(.caption.monospacedDigit())
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    Button(L10n.continueWorking) {
                        Task { await model.continueWorking() }
                    }
                    .buttonStyle(AnchorPrimaryButtonStyle())
                    .accessibilityIdentifier("return.continue.button")
                    Button(action: onNote) {
                        Label(L10n.anchorNote, systemImage: "scope")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    .tint(AnchorPalette.ink)
                }
                .padding(AnchorSpacing.large)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(AnchorPalette.paper)
            .toolbar(.hidden, for: .navigationBar)
        }
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        .accessibilityIdentifier("return.screen")
    }

    private var recommendedProcess: AnchorProcess? {
        guard let id = projection.session?.returnSummary?.recommendedProcessID else { return nil }
        return projection.session?.processes.first { $0.id == id }
    }
}
#endif
