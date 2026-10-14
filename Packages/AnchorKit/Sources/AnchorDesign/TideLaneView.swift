import AnchorCore
import SwiftUI

/// One task across the visible time window.
public struct TideLaneView: View {
    let task: AnchorSession
    let now: Date
    let span: TimeInterval
    let labelWidth: CGFloat
    /// Accessibility sizes put the name above a full-width lane.
    let stacked: Bool
    let reduceMotion: Bool
    /// Rows that already show the task name draw the lane alone.
    let showsLabel: Bool

    public init(task: AnchorSession, now: Date, span: TimeInterval, labelWidth: CGFloat,
                stacked: Bool, reduceMotion: Bool, showsLabel: Bool = true) {
        self.showsLabel = showsLabel
        self.task = task
        self.now = now
        self.span = span
        self.labelWidth = labelWidth
        self.stacked = stacked
        self.reduceMotion = reduceMotion
    }
    @ScaledMetric(relativeTo: .caption) private var laneHeight: CGFloat = 10

    public var body: some View {
        let tint = AnchorTaskIdentity.color(for: task)
        let segments = TaskTide.segments(for: task, now: now)
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(spacing: 8))
        layout {
            if showsLabel {
            HStack(spacing: 6) {
                Circle().fill(tint).frame(width: 8, height: 8)
                Text(task.goal.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AnchorPalette.ink)
                    .lineLimit(1)
            }
            .frame(width: stacked ? nil : labelWidth, alignment: .leading)
            }
            GeometryReader { geometry in
                let width = geometry.size.width
                let start = now.addingTimeInterval(-span)
                let x: (Date) -> CGFloat = { date in
                    CGFloat(max(0, min(1, date.timeIntervalSince(start) / span))) * width
                }
                let taskStart = x(task.startedAt)
                ZStack(alignment: .leading) {
                    // The anchor holds from the moment it was dropped.
                    Capsule()
                        .fill(tint.opacity(0.14))
                        .frame(width: max(laneHeight, width - taskStart), height: laneHeight)
                        .offset(x: min(taskStart, width - laneHeight))
                    if segments.isEmpty {
                        Capsule()
                            .strokeBorder(tint.opacity(0.55), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .frame(width: max(laneHeight, width - taskStart), height: laneHeight)
                            .offset(x: min(taskStart, width - laneHeight))
                    }
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        if segment.state.isTerminal {
                            TideMarker(state: segment.state, tint: tint, size: laneHeight + 6)
                                .offset(x: x(segment.end) - (laneHeight + 6) / 2)
                        } else {
                            let from = x(segment.start), to = x(segment.end)
                            Capsule()
                                .fill(TideStyle.fill(segment.state, tint: tint))
                                .frame(width: max(laneHeight, to - from), height: laneHeight)
                                .offset(x: min(from, width - laneHeight))
                        }
                    }
                    if let open = segments.last(where: \.isOpen), open.state == .running {
                        RunningBeacon(color: tint, size: laneHeight, reduceMotion: reduceMotion)
                            .offset(x: width - laneHeight)
                    }
                }
                .frame(height: geometry.size.height)
            }
            .frame(height: laneHeight + 6)
        }
        .frame(minHeight: 22)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(task.goal.title)
        .accessibilityValue(accessibilityValue(segments))
    }

    private func accessibilityValue(_ segments: [TideSegment]) -> String {
        guard let latest = segments.max(by: { $0.end < $1.end }) else { return L10n.glanceNoRecords }
        return L10n.tideState(latest.state)
    }
}

/// A live run ends in a soft, slow glow. It exists only while the source
/// reports the run, and holds still when motion is reduced.
private struct RunningBeacon: View {
    let color: Color
    let size: CGFloat
    let reduceMotion: Bool
    @State private var glowing = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .background {
                Circle().fill(color.opacity(0.35))
                    .scaleEffect(glowing && !reduceMotion ? 2.0 : 1)
                    .opacity(glowing && !reduceMotion ? 0 : 0.8)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { glowing = true }
            }
            .accessibilityHidden(true)
    }
}

private struct TideMarker: View {
    let state: TideState
    let tint: Color
    let size: CGFloat

    var body: some View {
        let style = TideStyle.marker(state, tint: tint)
        Image(systemName: style.name)
            .font(.system(size: size * 0.52, weight: .heavy))
            .foregroundStyle(AnchorPalette.surface)
            .frame(width: size, height: size)
            .background(style.color, in: .circle)
            .overlay { Circle().strokeBorder(AnchorPalette.surface, lineWidth: 1.5) }
            .accessibilityHidden(true)
    }
}

public enum TideStyle {
    public static func fill(_ state: TideState, tint: Color) -> Color {
        switch state {
        case .running, .completed: tint.opacity(state == .running ? 0.85 : 1)
        case .attention, .failed, .interrupted: AnchorStateTone(state).fill
        }
    }

    public static func marker(_ state: TideState, tint: Color) -> (name: String, color: Color) {
        switch state {
        case .completed: ("checkmark", AnchorStateTone.done.fill)
        case .failed: ("xmark", AnchorStateTone.failed.fill)
        case .interrupted: ("pause.fill", AnchorStateTone.attention.fill)
        case .attention: ("exclamationmark", AnchorStateTone.attention.fill)
        case .running: ("play.fill", tint)
        }
    }

    public static func symbol(for change: WorkGlance.Change) -> (name: String, color: Color) {
        if change.isInterruption { return ("pause.circle.fill", AnchorStateTone.attention.ink) }
        switch change.event.kind {
        case .completed: return ("checkmark.circle.fill", AnchorStateTone.done.ink)
        case .failed: return ("xmark.octagon.fill", AnchorStateTone.failed.ink)
        case .decisionRequired: return ("exclamationmark.circle.fill", AnchorStateTone.attention.ink)
        case .outputReady: return ("sparkles", AnchorPalette.interaction)
        default: return ("play.circle.fill", AnchorPalette.interaction)
        }
    }

}
