#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// A hosted task in the library. The identity color matches its lane in the
/// glance card; the status line names every state its conversations report.
struct HostedTaskCard: View {
    let task: AnchorSession
    let height: CGFloat
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 20
    @AnchorReducedMotion private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var ringSize: CGFloat = 13

    /// Tall cards have room to say what last happened.
    private var showsLatest: Bool { dynamicTypeSize.isAccessibilitySize || height >= 160 }

    var body: some View {
        let tint = HostedTaskAppearance.tint(task)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Text(task.goal.title).font(.system(size: titleSize, weight: .semibold))
                    .foregroundStyle(AnchorIOSStyle.text)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if summary.isComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AnchorStateTone.done.ink)
                        .frame(width: 26, height: 26)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .animation(reduceMotion ? .easeOut(duration: 0.16) : .spring(duration: 0.36, bounce: 0.3),
                       value: summary.isComplete)
            if showsLatest, let latest = latestEvent {
                latestLine(latest)
            }
            Spacer(minLength: 0)
            HStack(alignment: .center, spacing: 6) {
                statusLine(tint: tint)
                Spacer(minLength: 4)
                if let progress = displayedProgress {
                    progressCapsule(progress, tint: tint)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .frame(minHeight: height, maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : height, alignment: .topLeading)
        .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: AnchorIOSStyle.cardRadius))
        .overlay(alignment: .topLeading) {
            // Identity tab: ties the card to its lane without a thick border.
            Capsule().fill(tint).frame(width: 22, height: 4).padding(.leading, 14).padding(.top, 7)
                .accessibilityHidden(true)
        }
        .shadow(color: AnchorIOSStyle.heading.opacity(0.10), radius: 9, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(task.goal.title)
        .accessibilityValue(accessibleStatus)
    }

    // MARK: State

    private var summary: HostedTaskStatus { HostedTaskStatus(task: task) }

    private var latestEvent: (event: ProcessEvent, process: AnchorProcess)? {
        task.taskProcesses
            .flatMap { process in
                process.events.filter { [.created, .outputReady, .decisionRequired, .completed, .failed].contains($0.kind) }
                    .map { ($0, process) }
            }
            .max { $0.0.occurredAt < $1.0.occurredAt }
    }

    private var displayedProgress: Double? {
        guard let value = task.conversationsInJoiningOrder.first?.progress, value.isFinite else { return nil }
        return min(1, max(0, value))
    }

    private var accessibleStatus: String {
        var parts = [statusText]
        if let progress = displayedProgress {
            parts.append("\(L10n.taskProgress) \(progress.formatted(.percent.precision(.fractionLength(0))))")
        } else if summary.hasSources {
            parts.append(L10n.cardProgressUnreported)
        }
        return parts.joined(separator: ", ")
    }

    private var statusText: String { summary.summary }

    private var statusSymbol: (name: String, color: Color) { summary.symbol }

    // MARK: Pieces

    private func statusLine(tint: Color) -> some View {
        let symbol = statusSymbol
        return HStack(spacing: 5) {
            Image(systemName: symbol.name)
                .foregroundStyle(symbol.color)
                .contentTransition(.symbolEffect(.replace))
            Text(statusText)
                .foregroundStyle(AnchorIOSStyle.text)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption.weight(.semibold))
        .animation(AnchorMotion.micro, value: statusText)
    }

    private func latestLine(_ latest: (event: ProcessEvent, process: AnchorProcess)) -> some View {
        let interrupted = latest.event.isInterruption
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(latest.process.title) \(L10n.eventVerb(latest.event.kind, interrupted: interrupted))")
                .font(.footnote)
                .foregroundStyle(AnchorIOSStyle.text)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
            Text("\(latest.process.sourceName) · \(latest.event.occurredAt.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))")
                .font(.caption2)
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .lineLimit(1)
        }
        .padding(.top, 2)
    }

    private func progressCapsule(_ progress: Double, tint: Color) -> some View {
        let text = progress.formatted(.percent.precision(.fractionLength(0)))
        let animation = reduceMotion ? Animation.easeOut(duration: 0.16) : AnchorMotion.continuity
        return HStack(spacing: 5) {
            ZStack {
                Circle().stroke(tint.opacity(0.25), lineWidth: 2)
                Circle().trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(animation, value: progress)
            }
            .frame(width: ringSize, height: ringSize)
            .accessibilityHidden(true)
            Text(text)
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .contentTransition(reduceMotion ? .opacity : .numericText(value: progress))
                .animation(animation, value: text)
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(AnchorIOSStyle.text)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.18), in: .capsule)
    }
}
#endif
