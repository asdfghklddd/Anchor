#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacReturnMemoryView: View {
    let session: AnchorSession
    let projection: SessionProjection
    let onOpenProcess: (UUID) -> Void
    let onContinue: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showingChanges = false

    private var isReturning: Bool {
        session.presence == .returning
    }

    private var changes: [ReturnChange] {
        session.returnSummary?.changes ?? []
    }

    private var recommendedProcess: AnchorProcess? {
        guard let processID = session.returnSummary?.recommendedProcessID else { return nil }
        return session.processes.first { $0.id == processID }
    }

    private var awaySince: Date? {
        session.returnSummary?.awaySince ?? session.snapshots.first?.createdAt
    }

    private var runningCount: Int {
        session.processes.filter { $0.status == .running }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.large) {
            if isReturning {
                returningContent
            } else {
                awayContent
            }
        }
        .padding(AnchorSpacing.large)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    isReturning ? AnchorPalette.seafoam.opacity(0.42) : AnchorPalette.deepSea.opacity(0.20),
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.presence.memory")
    }

    private var awayContent: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        Label(awayDuration(at: context.date), systemImage: "circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AnchorPalette.mintInk)
                    }
                    Text(L10n.away)
                        .font(.title.bold())
                        .foregroundStyle(AnchorPalette.ink)
                    Text(L10n.awayDetail)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AnchorSpacing.medium)

                Button(L10n.continueWorking, systemImage: "play.fill", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .tint(AnchorPalette.deepSea)
                    .controlSize(.small)
                    .accessibilityIdentifier("mac.presence.continue")
            }

            awaySummary
        }
    }

    private var awaySummary: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                Text(L10n.currentAnchor)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AnchorPalette.oceanHighlight)
                    .textCase(.uppercase)
                Text(session.goal.title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L10n.processAttentionSummary(
                    processes: session.processes.count,
                    attention: projection.openDecisions.count
                ))
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
            }

            VStack(spacing: AnchorSpacing.small) {
                ForEach(session.processes) { process in
                    awayProcessRow(process)
                }
            }
        }
        .padding(AnchorSpacing.large)
        .background(
            LinearGradient(
                colors: [
                    AnchorPalette.deepSea.opacity(0.98),
                    AnchorPalette.deepSea.opacity(0.82),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: 20, style: .continuous)
        )
        .shadow(color: AnchorPalette.deepSea.opacity(0.18), radius: 14, y: 8)
    }

    private func awayProcessRow(_ process: AnchorProcess) -> some View {
        HStack(spacing: AnchorSpacing.small) {
            SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 32)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: AnchorSpacing.xSmall) {
                    Text(process.sourceName)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer(minLength: AnchorSpacing.small)
                    Text(progressText(for: process))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.82))
                }

                if let progress = process.progress {
                    ProgressView(value: progress, total: 1)
                        .tint(AnchorPalette.source(process.sourceTone))
                } else {
                    Label(L10n.unknown, systemImage: "minus")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.70))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(process.sourceName), \(process.title)")
        .accessibilityValue("\(progressText(for: process)), \(L10n.status(process.status))")
    }

    private var returningContent: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                HStack(spacing: AnchorSpacing.small) {
                    ZStack {
                        Circle()
                            .stroke(AnchorPalette.cyan.opacity(0.24), lineWidth: 1)
                            .frame(width: 66, height: 66)
                        Circle()
                            .stroke(AnchorPalette.cyan.opacity(0.16), lineWidth: 1)
                            .frame(width: 84, height: 84)
                        HarborBrandMark(size: 44)
                    }
                    .frame(width: 92, height: 84)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                        if let awaySince {
                            Text(awayDuration(from: awaySince))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AnchorPalette.deepSea)
                        }
                        Text(L10n.returning)
                            .font(.title.bold())
                            .foregroundStyle(AnchorPalette.ink)
                        Text(L10n.returnHeadline)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(AnchorPalette.secondaryInk)
                        Text(session.goal.title)
                            .font(.caption)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: AnchorSpacing.medium)

                Button(L10n.continueWorking, systemImage: "play.fill", action: onContinue)
                    .buttonStyle(.borderedProminent)
                    .tint(AnchorPalette.deepSea)
                    .controlSize(.small)
                    .accessibilityIdentifier("mac.presence.continue")
            }

            impactCard
            changesDisclosure

            if let recommendedProcess {
                nextStepCard(recommendedProcess)
            }
        }
    }

    private var impactCard: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            HStack {
                Text(L10n.returnImpact)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AnchorPalette.mintInk)
                    .textCase(.uppercase)
                Spacer(minLength: AnchorSpacing.small)
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AnchorPalette.mintInk)
                    .accessibilityHidden(true)
            }

            Text(L10n.returnDetail)
                .font(.headline)
                .foregroundStyle(AnchorPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                returnMetric(
                    value: changes.count,
                    label: L10n.returnChanges,
                    symbol: "clock.arrow.circlepath"
                )
                Divider().padding(.vertical, AnchorSpacing.xSmall)
                returnMetric(
                    value: runningCount,
                    label: L10n.live,
                    symbol: "play.fill"
                )
                Divider().padding(.vertical, AnchorSpacing.xSmall)
                returnMetric(
                    value: projection.openDecisions.count,
                    label: L10n.decisions,
                    symbol: "exclamationmark.bubble"
                )
            }
        }
        .padding(AnchorSpacing.medium)
        .background(AnchorPalette.seafoam.opacity(0.18), in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AnchorPalette.seafoam.opacity(0.32), lineWidth: 1)
        }
    }

    private func returnMetric(value: Int, label: String, symbol: String) -> some View {
        VStack(spacing: AnchorSpacing.xSmall) {
            HStack(spacing: AnchorSpacing.xSmall) {
                Image(systemName: symbol)
                    .accessibilityHidden(true)
                Text(value, format: .number)
            }
            .font(.title3.bold().monospacedDigit())
            .foregroundStyle(AnchorPalette.ink)
            Text(label)
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var changesDisclosure: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(duration: 0.36)) {
                    showingChanges.toggle()
                }
            } label: {
                HStack(spacing: AnchorSpacing.small) {
                    Label(L10n.returnChanges, systemImage: "clock.arrow.circlepath")
                        .font(.callout.weight(.semibold))
                    Spacer(minLength: AnchorSpacing.small)
                    Text(changes.count, format: .number)
                        .font(.caption.weight(.bold).monospacedDigit())
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(showingChanges ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(AnchorPalette.ink)
                .padding(.horizontal, AnchorSpacing.medium)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mac.return.changes")

            if showingChanges {
                Divider().padding(.horizontal, AnchorSpacing.medium)
                VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                    if changes.isEmpty {
                        Text(L10n.noEvents)
                            .font(.callout)
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    } else {
                        ForEach(changes) { change in
                            HStack(alignment: .top, spacing: AnchorSpacing.small) {
                                Text(change.occurredAt, style: .time)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(AnchorPalette.secondaryInk)
                                    .frame(width: 48, alignment: .leading)
                                Circle()
                                    .fill(AnchorPalette.coral)
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 5)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(change.title)
                                        .font(.callout.weight(.semibold))
                                    if !change.detail.isEmpty {
                                        Text(change.detail)
                                            .font(.caption)
                                            .foregroundStyle(AnchorPalette.secondaryInk)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .padding(AnchorSpacing.medium)
            }
        }
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AnchorPalette.ink.opacity(0.08), lineWidth: 1)
        }
    }

    private func nextStepCard(_ process: AnchorProcess) -> some View {
        Button {
            onOpenProcess(process.id)
        } label: {
            HStack(alignment: .top, spacing: AnchorSpacing.small) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(AnchorPalette.sourceInk("sand"))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.yourNextStep)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AnchorPalette.ink)
                        .textCase(.uppercase)
                    Text(process.title)
                        .font(.headline)
                        .foregroundStyle(AnchorPalette.ink)
                    Text(process.detail)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: AnchorSpacing.small)
                Image(systemName: "arrow.up.right")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AnchorPalette.ink)
                    .accessibilityHidden(true)
            }
            .padding(AnchorSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AnchorPalette.sand.opacity(0.28), in: .rect(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mac.return.next")
    }

    private func progressText(for process: AnchorProcess) -> String {
        guard let progress = process.progress else { return L10n.unknown }
        return progress.formatted(.percent.precision(.fractionLength(0)))
    }

    private func awayDuration(at date: Date) -> String {
        guard let awaySince else { return L10n.away }
        return L10n.awayDuration(max(1, Int(date.timeIntervalSince(awaySince) / 60)))
    }

    private func awayDuration(from date: Date) -> String {
        L10n.awayDuration(max(1, Int(Date.now.timeIntervalSince(date) / 60)))
    }
}
#endif
