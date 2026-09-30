#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// One color is one hosted task. The first joined conversation is the thick main line.
struct HomeAnchorChart: View {
    let tasks: [AnchorSession]
    var height: CGFloat = 247
    private var lineLength: CGFloat { max(40, height - 102) }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Anchors").font(.headline).foregroundStyle(.primary)
                Spacer()
                HarborAnchorGlyph(color: AnchorIOSStyle.text, lineWidth: 1.3)
                    .frame(width: 13, height: 15).accessibilityHidden(true)
            }

            GeometryReader { geometry in
                if tasks.isEmpty {
                    Text(AnchorStrings.value("home.empty.tasks", default: "Drop an anchor to host your first task"))
                        .font(.caption).foregroundStyle(AnchorIOSStyle.secondaryText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 8) {
                            ForEach(tasks) { task in
                                group(task, width: max(dynamicTypeSize.isAccessibilitySize ? 125 : 76, (geometry.size.width - 24) / 4))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .background {
                VStack {
                    ForEach(0..<3) { _ in
                        Spacer()
                        gridLine
                    }
                }
                .padding(.top, 30).padding(.bottom, 10)
                .accessibilityHidden(true)
            }
        }
        .padding(12)
        .frame(height: dynamicTypeSize.isAccessibilitySize ? max(290, height) : height)
        .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: 16))
        .accessibilityIdentifier("home.anchor.chart")
    }

    private var gridLine: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
            }
            .stroke(AnchorIOSStyle.border.opacity(0.7), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
        }.frame(height: 0.5)
    }

    private func displayOrder(_ conversations: [AnchorProcess]) -> [AnchorProcess] {
        guard conversations.count > 1 else { return conversations }
        return [conversations[1], conversations[0]] + Array(conversations.dropFirst(2))
    }

    private func group(_ task: AnchorSession, width: CGFloat) -> some View {
        let conversations = task.conversationsInJoiningOrder
        let color = HostedTaskAppearance.tint(task)
        return VStack(spacing: 8) {
            Text(task.goal.title).font(.system(size: labelSize)).foregroundStyle(.secondary)
                .lineLimit(1).frame(width: width)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 6) {
                    if conversations.isEmpty {
                        // A newly created task still owns an anchor. No measured
                        // progress is available until a process is attached.
                        HarborAnchorGlyph(color: AnchorIOSStyle.border, lineWidth: 1.2)
                            .frame(width: 9, height: 16).padding(.top, 8)
                        ZStack(alignment: .top) {
                            Capsule().stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                                .frame(width: 31, height: 31 + lineLength)
                            HarborAnchorGlyph(color: .white, lineWidth: 1.8)
                                .frame(width: 19, height: 19).frame(width: 31, height: 31)
                                .background(color, in: .circle)
                        }
                        .accessibilityLabel(task.goal.title)
                        .accessibilityValue(L10n.taskProgress + " —")
                    }
                    ForEach(displayOrder(conversations), id: \.id) { process in
                        let index = process.id == conversations.first?.id ? 0 : 1
                        conversationLine(process, main: index == 0, tint: color)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(process.title)
                        .accessibilityValue(process.progress?.formatted(.percent) ?? L10n.status(process.status))
                    }
                }
                .padding(.horizontal, 3)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: width, alignment: .leading)
    }
    @ViewBuilder
    private func conversationLine(_ process: AnchorProcess, main: Bool, tint: Color) -> some View {
        let progress = process.progress.map { min(1, max(0, $0)) }
        if main {
            ZStack(alignment: .top) {
                if let progress {
                    Capsule().fill(tint.opacity(0.18)).frame(width: 31, height: 31 + lineLength * progress)
                } else {
                    Capsule().stroke(tint.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .frame(width: 31, height: 31 + lineLength)
                }
                HarborAnchorGlyph(color: .white, lineWidth: 1.8)
                    .frame(width: 19, height: 19).frame(width: 31, height: 31)
                    .background(tint, in: .circle)
            }
        } else {
            VStack(spacing: 4) {
                HarborAnchorGlyph(color: process.status == .queued ? AnchorIOSStyle.border : tint, lineWidth: 1.2).frame(width: 9, height: 16)
                if let progress, progress > 0 {
                    Capsule().fill(tint.opacity(0.24)).frame(width: 7, height: max(2, lineLength * progress))
                } else if progress == nil {
                    Capsule().stroke(tint.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .frame(width: 7, height: lineLength)
                }
            }
            .padding(.top, 8)
        }
    }

}
#endif
