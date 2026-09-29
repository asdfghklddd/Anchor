#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Landscape is a dedicated overview, with shared task data and portrait detail routes.
struct LandscapeAmbientDashboard: View {
    let projection: SessionProjection
    let onTask: (UUID) -> Void
    let onManage: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geometry in
            let height = max(280, geometry.size.height - 24)
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    VStack(spacing: 16) {
                        clock(height: 110)
                        HomeAnchorChart(tasks: projection.hostedSessions)
                        library(height: 480)
                    }.padding(16)
                }
            } else {
                HStack(alignment: .top, spacing: 20) {
                    VStack(spacing: 12) {
                        clock(height: height * 0.28)
                        HomeAnchorChart(tasks: projection.hostedSessions, height: height * 0.72 - 12)
                    }
                    .frame(width: max(0, (geometry.size.width - 52) * 0.55))
                    library(height: height)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
        }
        .background { HarborBackground() }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ambient.screen")
    }

    private func clock(height: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(alignment: .center, spacing: 16) {
                Text(context.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)))
                    .font(.system(size: height * 0.90, weight: .black, design: .default))
                    .italic().monospacedDigit().tracking(-4)
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("ambient.time")
                VStack(alignment: .leading, spacing: 3) {
                    Text("Focus").font(.system(.headline, design: .rounded, weight: .heavy))
                    Text("\(focusMinutes(at: context.date)) min")
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(width: 100, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("ambient.focus")
            }
            .foregroundStyle(AnchorIOSStyle.heading)
        }
        .frame(height: height)
    }

    private func library(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(AnchorStrings.value("home.task.library", default: "Task library"))
                    .font(.title2.bold()).foregroundStyle(AnchorIOSStyle.heading)
                Spacer(minLength: 4)
                Button(action: onManage) {
                    HStack(spacing: 4) {
                        Circle().fill(AnchorIOSStyle.success).frame(width: 7, height: 7)
                        Text("\(projection.hostedSessions.count)")
                        HarborAnchorGlyph(color: AnchorIOSStyle.secondaryText, lineWidth: 1.2)
                            .frame(width: 12, height: 12)
                    }
                    .font(.caption).foregroundStyle(AnchorIOSStyle.secondaryText)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel(AnchorStrings.value("home.tasks.manage", default: "Manage hosted tasks"))
                .accessibilityIdentifier("ambient.tasks.manage")
            }
            if projection.hostedSessions.isEmpty {
                Text(AnchorStrings.value("home.empty.tasks", default: "Drop an anchor to host your first task"))
                    .font(.caption).foregroundStyle(AnchorIOSStyle.secondaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AnchorIOSStyle.surface, in: .rect(cornerRadius: 16))
            } else {
                ScrollView {
                    taskGrid(availableHeight: height - 48)
                        .padding(.bottom, 4)
                }.scrollIndicators(.hidden)
            }
        }
        .frame(maxWidth: .infinity).frame(height: height)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ambient.task.library")
    }

    private func taskGrid(availableHeight: CGFloat) -> some View {
        let columns = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        let short = max(86, (availableHeight - 10) * 0.32)
        let tall = max(170, availableHeight - 10 - short)
        return HStack(alignment: .top, spacing: 10) {
            ForEach(0..<columns, id: \.self) { column in
                VStack(spacing: 10) {
                    ForEach(Array(projection.hostedSessions.enumerated()).filter { $0.offset % columns == column }, id: \.element.id) { index, task in
                        Button { onTask(task.id) } label: {
                            HostedTaskCard(task: task, height: dynamicTypeSize.isAccessibilitySize ? 190 : (index % 4 == 0 || index % 4 == 3 ? short : tall))
                        }
                        .buttonStyle(AnchorPressButtonStyle())
                        .accessibilityIdentifier("hosted.task.\(task.id)")
                    }
                }.frame(maxWidth: .infinity)
            }
        }
    }

    private func focusMinutes(at date: Date) -> Int {
        guard let startedAt = projection.session?.startedAt else { return 0 }
        return max(0, Int(date.timeIntervalSince(startedAt) / 60))
    }
}
#endif
