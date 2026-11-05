// Role: the Me page: name, week chart, streak, finished tasks, agents, returns.
// Rule: the pet stays off this page, by the owner's choice.

#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The Me page: who you are, how your week went, and what your agents did.
struct ProfileView: View {
    let projection: SessionProjection
    var log = AnchoringLog.shared
    let onRoute: (AnchorRoute) -> Void

    @AppStorage("anchor.profile.name", store: ProfilePreferences.store) private var displayName = "Anchor"
    @Environment(\.openConnectionCard) private var openConnectionCard

    var body: some View {
        let groups = SourceGroup.all(in: projection)
        let finished = ProfileStats.finished(in: projection)
        ZStack {
            HomeWater()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    identity
                    ProfileWeekCard(log: log)
                    tiles(finished: finished.count, groups: groups)
                    if !groups.isEmpty {
                        ProfileAgentsCard(groups: groups, onRoute: onRoute)
                    }
                    recent(finished)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, AnchorSpacing.xLarge)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(L10n.profile)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier("profile.screen")
    }

    private var identity: some View {
        HStack(spacing: 14) {
            ProfileAvatarButton(size: 64)
            VStack(alignment: .leading, spacing: 4) {
                ProfileNameField(name: $displayName)
                Button(action: openConnectionCard) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isConnected ? HomeStyle.linked : AnchorIOSStyle.secondaryText.opacity(0.5))
                            .frame(width: 7, height: 7)
                        Text(connectionText)
                            .lineLimit(1)
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(isConnected ? HomeStyle.linked : AnchorIOSStyle.secondaryText)
                    .frame(minHeight: 24)
                    .contentShape(.rect)
                }
                .buttonStyle(AnchorPressButtonStyle(.control))
                .accessibilityIdentifier("profile.connection.button")
            }
            Spacer(minLength: 0)
        }
    }

    private var isConnected: Bool { projection.connection == .connected }

    private var connectionText: String {
        guard isConnected else { return PeerDeviceCopy.notConnected }
        return [PeerDeviceMemory.last()?.displayName, PeerDeviceCopy.connected]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func tiles(finished: Int, groups: [SourceGroup]) -> some View {
        HStack(spacing: 10) {
            tile("\(finished)", label: ProfileCopy.finished)
            tile(ProfileFormat.roundedTime(groups.reduce(0) { $0 + $1.workedSeconds }), label: ProfileCopy.agentTime)
            tile("\(ProfileStats.returns(in: projection))", label: ProfileCopy.returns)
        }
    }

    private func tile(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(AnchorFonts.poppins(21, medium: true, relativeTo: .title3))
                .monospacedDigit()
                .foregroundStyle(HomeStyle.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .profileCard()
        .accessibilityElement(children: .combine)
    }

    private func recent(_ finished: [AnchorSession]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(ProfileCopy.recent).profileCardTitle()
                Spacer()
                Button { onRoute(.history) } label: {
                    HStack(spacing: 3) {
                        Text(ProfileCopy.all)
                        Image(systemName: "chevron.right").font(.caption2.bold())
                    }
                    .font(.subheadline)
                    .foregroundStyle(AnchorIOSStyle.action)
                    .frame(minHeight: 32)
                    .contentShape(.rect)
                }
                .buttonStyle(AnchorPressButtonStyle(.control))
                .accessibilityIdentifier("profile.history.button")
            }
            if finished.isEmpty {
                Text(ProfileCopy.recentEmpty)
                    .font(.subheadline)
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                    .padding(.vertical, 6)
            }
            ForEach(finished.prefix(3)) { task in
                Button { onRoute(.historyDetail(task.id)) } label: { recentRow(task) }
                    .buttonStyle(AnchorPressButtonStyle())
                    .accessibilityIdentifier("profile.recent.\(task.id.uuidString)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .profileCard()
    }

    private func recentRow(_ task: AnchorSession) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(HomeStyle.done)
                .accessibilityHidden(true)
            Text(task.goal.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(recentDetail(task))
                .font(.caption.monospacedDigit())
                .foregroundStyle(AnchorIOSStyle.secondaryText)
                .lineLimit(1)
                .layoutPriority(1)
        }
        .frame(minHeight: 36)
        .contentShape(.rect)
    }

    /// When it finished, and how much of its plan got done when it had one.
    private func recentDetail(_ task: AnchorSession) -> String {
        let date = task.completedAt?.formatted(.dateTime.month().day()) ?? ""
        guard let plan = task.goal.userPlan, !plan.steps.isEmpty else { return date }
        return "\(date) · \(plan.doneCount)/\(plan.steps.count)"
    }
}

/// This week's anchoring. A bar shows a day; tapping one reads it out in the headline.
private struct ProfileWeekCard: View {
    let log: AnchoringLog

    @AppStorage(AnchoringLog.goalKey) private var goalMinutes = AnchoringLog.defaultGoalMinutes
    @AnchorReducedMotion private var reduceMotion
    @State private var selected: Date?
    @State private var risen = false

    private static let chartHeight: CGFloat = 104

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(now: context.date)
        }
        .padding(16)
        .profileCard()
        .sensoryFeedback(.selection, trigger: selected)
        .onAppear { risen = true }
    }

    private func content(now: Date) -> some View {
        let week = ProfileStats.week(now: now) { log.seconds(on: $0, now: now) }
        let streak = ProfileStats.streak(now: now) { log.seconds(on: $0, now: now) }
        let shown = week.first { $0.date == selected }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(ProfileFormat.time(shown?.seconds ?? week.reduce(0) { $0 + $1.seconds }))
                        .font(AnchorFonts.poppins(30, medium: true, relativeTo: .title))
                        .monospacedDigit()
                        .foregroundStyle(HomeStyle.ink)
                        .contentTransition(reduceMotion ? .opacity : .numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(shown?.date.formatted(.dateTime.month().day().weekday()) ?? ProfileCopy.thisWeek)
                        .font(.footnote)
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                        .contentTransition(.opacity)
                }
                .animation(reduceMotion ? nil : AnchorMotion.panel, value: selected)
                Spacer(minLength: 0)
                if streak >= 2 {
                    Text(ProfileCopy.streak(streak))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HomeStyle.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(HomeStyle.dome.opacity(0.45), in: .capsule)
                        .lineLimit(1)
                        .accessibilityIdentifier("profile.streak")
                }
            }
            bars(week)
        }
    }

    private func bars(_ week: [ProfileWeekDay]) -> some View {
        let goal = TimeInterval(goalMinutes * 60)
        let scale = max(goal, week.map(\.seconds).max() ?? 0, 3_600)
        return VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(week.enumerated()), id: \.element.id) { index, day in
                    Button {
                        selected = selected == day.date ? nil : day.date
                    } label: {
                        bar(day, goal: goal, scale: scale, index: index)
                    }
                    .buttonStyle(.plain)
                    .disabled(day.isAhead)
                    .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide)))
                    .accessibilityValue(ProfileFormat.time(day.seconds))
                    .accessibilityAddTraits(selected == day.date ? .isSelected : [])
                }
            }
            .frame(height: Self.chartHeight)
            .background(alignment: .top) {
                if goal > 0 {
                    goalLine.offset(y: Self.chartHeight * (1 - goal / scale))
                }
            }
            HStack(spacing: 8) {
                ForEach(week) { day in
                    Text(day.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2.weight(day.isToday ? .bold : .regular))
                        .foregroundStyle(day.isToday ? HomeStyle.ink : AnchorIOSStyle.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private var goalLine: some View {
        Line()
            .stroke(HomeStyle.quiet.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            .frame(height: 1)
            .accessibilityHidden(true)
    }

    private func bar(_ day: ProfileWeekDay, goal: TimeInterval, scale: TimeInterval, index: Int) -> some View {
        let dimmed = selected != nil && selected != day.date
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            if day.seconds >= 60 {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color(day, goal: goal))
                    .frame(height: max(8, Self.chartHeight * day.seconds / scale))
                    .scaleEffect(y: risen || reduceMotion ? 1 : 0.02, anchor: .bottom)
                    .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.78).delay(Double(index) * 0.035),
                               value: risen)
            } else {
                Capsule()
                    .fill(AnchorIOSStyle.border.opacity(day.isAhead ? 0.5 : 1))
                    .frame(height: 5)
            }
        }
        .opacity(dimmed ? 0.45 : 1)
        .animation(AnchorMotion.micro, value: dimmed)
        .frame(maxWidth: .infinity)
        .frame(height: Self.chartHeight)
        .contentShape(.rect)
    }

    private func color(_ day: ProfileWeekDay, goal: TimeInterval) -> Color {
        if goal > 0, day.seconds >= goal { return HomeStyle.done }
        return day.isToday ? HomeStyle.ink : HomeStyle.ink.opacity(0.32)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}

/// Every agent's time so far, longest first; each opens its conversations.
private struct ProfileAgentsCard: View {
    let groups: [SourceGroup]
    let onRoute: (AnchorRoute) -> Void

    var body: some View {
        let longest = max(groups.map(\.workedSeconds).max() ?? 0, 1)
        VStack(alignment: .leading, spacing: 10) {
            Text(ProfileCopy.agents).profileCardTitle()
            ForEach(groups) { group in
                Button { onRoute(.source(group.name)) } label: { row(group, longest: longest) }
                    .buttonStyle(AnchorPressButtonStyle())
                    .accessibilityIdentifier("profile.agent.\(group.name)")
            }
        }
        .padding(16)
        .profileCard()
    }

    private func row(_ group: SourceGroup, longest: TimeInterval) -> some View {
        HStack(spacing: 12) {
            SourceTile(process: group.latest)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AnchorPalette.ink)
                        .lineLimit(1)
                    if group.isRunning {
                        Circle().fill(HomeStyle.linked).frame(width: 6, height: 6)
                            .accessibilityLabel(L10n.status(.running))
                    }
                    Spacer(minLength: 8)
                    Text(detail(group))
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(AnchorIOSStyle.secondaryText)
                        .lineLimit(1)
                }
                GeometryReader { proxy in
                    Capsule().fill(AnchorIOSStyle.border.opacity(0.6))
                    if group.workedSeconds > 0 {
                        Capsule()
                            .fill(HomeStyle.ink.opacity(0.75))
                            .frame(width: max(6, proxy.size.width * group.workedSeconds / longest))
                    }
                }
                .frame(height: 5)
                .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    /// The agent's time when the Mac reports it; otherwise how many conversations it has had.
    private func detail(_ group: SourceGroup) -> String {
        group.workedSeconds > 0
            ? ProfileFormat.roundedTime(group.workedSeconds)
            : DeskText.conversationCount(group.conversations.count)
    }
}

/// The person's name, edited where it is shown. The home's greeting and top
/// bar read the same setting, so they change as soon as it is saved.
private struct ProfileNameField: View {
    @Binding var name: String
    @State private var draft = ""
    @State private var editing = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if editing {
                TextField(AnchorStrings.value("profile.name", default: "Name"), text: $draft)
                    .textContentType(.nickname)
                    .submitLabel(.done)
                    .focused($focused)
                    .onSubmit(save)
                    .onChange(of: focused) { _, isFocused in if !isFocused { save() } }
                    .accessibilityIdentifier("profile.name.field")
            } else {
                Button {
                    draft = name
                    editing = true
                    focused = true
                } label: {
                    HStack(spacing: 6) {
                        Text(name).lineLimit(1)
                        Image(systemName: "pencil")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AnchorIOSStyle.secondaryText)
                    }
                }
                .buttonStyle(AnchorPressButtonStyle(.control))
                .accessibilityLabel(name)
                .accessibilityHint(AnchorStrings.value("profile.name.edit", default: "Edit name"))
                .accessibilityIdentifier("profile.name.button")
            }
        }
        .font(.title2.bold())
        .foregroundStyle(HomeStyle.ink)
    }

    /// An empty name keeps the old one.
    private func save() {
        let trimmed = String(draft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        if !trimmed.isEmpty { name = trimmed }
        editing = false
    }
}

private extension View {
    func profileCard() -> some View {
        background(AnchorIOSStyle.surface, in: .rect(cornerRadius: 20, style: .continuous))
            .shadow(color: HomeStyle.cardShadow.opacity(0.11), radius: 10, y: 3)
    }
}

private extension Text {
    func profileCardTitle() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(HomeStyle.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Number and duration formats for this page.
enum ProfileFormat {
    /// Hours and minutes: "18h 40m".
    static func time(_ seconds: TimeInterval) -> String {
        Duration.seconds(Int64(seconds / 60) * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }

    /// The largest unit only, for a long running total: "41h".
    static func roundedTime(_ seconds: TimeInterval) -> String {
        Duration.seconds(Int64(seconds / 60) * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .narrow, maximumUnitCount: 1))
    }
}

/// Words for this page.
enum ProfileCopy {
    static let thisWeek = AnchorStrings.value("profile.week.total", default: "Anchored this week")
    static let finished = AnchorStrings.value("profile.tasks.finished", default: "Tasks finished")
    static let agentTime = AnchorStrings.value("profile.agents.total", default: "Agent time")
    static let returns = AnchorStrings.value("profile.returns", default: "Picked back up")
    static let agents = AnchorStrings.value("profile.agents", default: "Your agents")
    static let recent = AnchorStrings.value("profile.recent", default: "Recently finished")
    static let all = AnchorStrings.value("profile.recent.all", default: "All")
    static let recentEmpty = AnchorStrings.value("profile.recent.empty", default: "Finished tasks stay here")

    static func streak(_ days: Int) -> String {
        String.localizedStringWithFormat(AnchorStrings.value("profile.streak", default: "%lld days in a row"), days)
    }
}
#endif
