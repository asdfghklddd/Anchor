#if os(macOS)
import AnchorDesign
import SwiftUI

/// One piece of news either side of the housing: who it is about on the
/// left, what happened on the right. A task waiting on the person speaks in
/// its own color; the pairing code is set large enough to type from.
struct NotchPeekStrip: View {
    let peek: NotchPeek
    let geometry: NotchIslandGeometry

    var body: some View {
        let wing = (geometry.peekSize.width - geometry.notch.width) / 2
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                leading
                if !peek.title.isEmpty {
                    Text(peek.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(NotchIslandInk.primary)
                        .lineLimit(1)
                }
            }
            .padding(.leading, 18)
            .frame(width: wing, alignment: .leading)
            Color.clear
                .frame(width: geometry.notch.width)
            trailing
                .padding(.trailing, 18)
                .frame(width: wing, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var leading: some View {
        switch peek.kind {
        case .finished, .waiting:
            NotchTaskDot(task: NotchIslandContent.Task(
                id: peek.taskID ?? peek.id, title: peek.title, colorIndex: peek.colorIndex,
                conversation: nil, signal: peek.kind == .waiting ? .waiting : .done))
                .accessibilityHidden(true)
        case .linkLost:
            Image(systemName: "iphone.slash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchIslandInk.faint)
                .accessibilityHidden(true)
        case .pairing:
            Image(systemName: "iphone")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(NotchIslandInk.secondary)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch peek.kind {
        case .finished:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                Text(peek.detail)
            }
            .font(.system(size: 12))
            .foregroundStyle(NotchIslandInk.secondary)
            .lineLimit(1)
        case .waiting:
            Text(peek.detail)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(NotchIslandInk.task(peek.colorIndex))
                .lineLimit(1)
        case .linkLost:
            Text(peek.detail)
                .font(.system(size: 12))
                .foregroundStyle(NotchIslandInk.secondary)
                .lineLimit(1)
        case .pairing:
            Text(peek.detail)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .tracking(2)
                .foregroundStyle(NotchIslandInk.primary)
                .lineLimit(1)
                .textSelection(.enabled)
        }
    }
}
#endif
