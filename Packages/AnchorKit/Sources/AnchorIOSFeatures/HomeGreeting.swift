#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The greeting's second line. Short, warm English lines in the mockup's
/// voice, picked from what is true right now; a line holds for a few hours so
/// the home doesn't flicker between them.
enum HomeGreetingLine {
    enum Moment: CaseIterable {
        case goalReached, needsYou, allDone, justLinked, weekend
        case earlyMorning, morning, afternoon, evening, lateNight
    }

    static let fallback = "Let’s start with your tasks!"

    static let lines: [Moment: [String]] = [
        .goalReached: ["Goal reached. Nicely done!", "Anchored enough for today!", "You hit today’s goal!"],
        .needsYou: ["Your agents are waiting!", "Someone needs your call!", "A reply is waiting for you!"],
        .allDone: ["All tasks done. Breathe!", "Clean deck. Well sailed!", "Everything’s done. Rest up!"],
        .justLinked: ["Mac’s here. Let’s anchor in!", "Docked at the desk. Begin!", "Connected and ready to go!"],
        .weekend: ["Weekend mode, light anchors!", "Easy pace for the weekend!", "A calm weekend harbor!"],
        .earlyMorning: [fallback, "Early tide, fresh start!", "Coffee first, then commits!", "The harbor is quiet. Begin!"],
        .morning: [fallback, "Morning! Anchors up, focus on.", "A clear head for the morning!", "Pick one task and dive in!"],
        .afternoon: ["Keep the afternoon steady!", "Halfway there. Keep sailing!", "Back to it after lunch!", "One more push this afternoon!"],
        .evening: ["Evening tide. Wrap it up!", "Close one loop before dinner!", "Steady hands, almost there!", "Good work today. Keep going!"],
        .lateNight: ["Burning the midnight oil?", "Late tide. Don’t forget sleep!", "Quiet night, clear mind!", "One last task, then rest!"],
    ]

    static func moment(tasks: [AnchorSession], anchored: TimeInterval, goal: TimeInterval,
                       linkedSince: Date?, now: Date, calendar: Calendar = .current) -> Moment {
        if goal > 0, anchored >= goal { return .goalReached }
        if tasks.contains(where: { TaskNextAction(task: $0)?.asksForALook == true }) { return .needsYou }
        if !tasks.isEmpty, tasks.allSatisfy({ HostedTaskIndicator(task: $0).isComplete }) { return .allDone }
        if let linkedSince, now.timeIntervalSince(linkedSince) < 10 * 60 { return .justLinked }
        let hour = calendar.component(.hour, from: now)
        if calendar.isDateInWeekend(now), (9..<22).contains(hour) { return .weekend }
        switch hour {
        case 5..<9: return .earlyMorning
        case 9..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<22: return .evening
        default: return .lateNight
        }
    }

    /// The same line for the same moment within a three-hour block of the day.
    static func line(for moment: Moment, now: Date, calendar: Calendar = .current) -> String {
        guard let options = lines[moment], !options.isEmpty else { return fallback }
        let day = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        let block = calendar.component(.hour, from: now) / 3
        return options[(day * 8 + block) % options.count]
    }
}

/// "Hi! <name>", its second line, and the person's pet beside it.
struct HomeGreeting: View {
    let tasks: [AnchorSession]
    let log: AnchoringLog
    @AppStorage("anchor.profile.name", store: ProfilePreferences.store) private var displayName = "Anchor"
    @AppStorage(AnchoringLog.goalKey) private var goalMinutes = AnchoringLog.defaultGoalMinutes

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            VStack(alignment: .leading, spacing: -7) {
                Text("Hi! \(displayName)")
                    .font(AnchorFonts.poppins(36, medium: true, relativeTo: .largeTitle))
                    .foregroundStyle(HomeStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(height: 54)
                    .accessibilityAddTraits(.isHeader)
                Text(line(now: context.date))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(HomeStyle.quiet)
                    .frame(minHeight: 22)
                    .padding(.leading, 2)
                    .contentTransition(.opacity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.trailing, 96)
        .overlay(alignment: .topTrailing) {
            HomePet(tasks: tasks)
                .padding(.trailing, 36)
                .padding(.top, 2)
        }
    }

    private func line(now: Date) -> String {
        let moment = HomeGreetingLine.moment(
            tasks: tasks, anchored: log.total(now: now), goal: TimeInterval(goalMinutes * 60),
            linkedSince: log.linkedSince, now: now)
        return HomeGreetingLine.line(for: moment, now: now)
    }
}

/// The person's pet, small and in place: the same pet as on the landscape
/// desk (`DeskPetLife`), with the same memory and day, only without its nook,
/// so it never walks off. A tap, a burst of taps and a long press get the
/// answers they get on the desk.
struct HomePet: View {
    let tasks: [AnchorSession]
    @AppStorage(DeskPetKind.defaultsKey, store: ProfilePreferences.store) private var kind = DeskPetKind.crab
    @AnchorReducedMotion private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var life = DeskPetLife.shared
    @State private var touches = 0
    private static let pixel: CGFloat = 2.4

    var body: some View {
        if kind != .off {
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    guard let brain = life.brain, brain.kind == kind else { return }
                    let look = DeskPetLook.of(kind)
                    let columns = Int(size.width / Self.pixel)
                    let rows = Int(size.height / Self.pixel)
                    DeskPetRenderer(look: look, kind: kind, context: context,
                                    left: max(0, (columns - look.width) / 2), ground: rows - 1, pixel: Self.pixel)
                        .draw(DeskPetFrame(brain, still: reduceMotion))
                }
                if kind == .jelly { bubbles }
            }
            .frame(width: 72, height: 68)
            .contentShape(.rect)
            .onLongPressGesture(minimumDuration: 0.5) {
                touches += 1
                life.press()
            }
            .onTapGesture {
                touches += 1
                life.tap()
            }
            .sensoryFeedback(.impact(weight: .light, intensity: 0.5), trigger: touches)
            .onChange(of: kind, initial: true) { life.use(kind) }
            .onChange(of: DeskPetContext.of(tasks), initial: true) { _, context in life.update(desk: context) }
            .task(id: reduceMotion) { await live() }
            .onDisappear { life.save() }
            .onChange(of: scenePhase) { if scenePhase != .active { life.save() } }
            .accessibilityElement()
            .accessibilityLabel(kind.title)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("home.pet")
        }
    }

    /// The jellyfish's two bubbles, as in the mockup.
    private var bubbles: some View {
        let tick = life.brain?.tick ?? 0
        let rise = reduceMotion ? 0 : CGFloat((tick / 4) % 2)
        return ZStack(alignment: .topLeading) {
            Circle().stroke(HomeStyle.bubble.opacity(0.7), lineWidth: 1).frame(width: 10, height: 10)
            Circle().stroke(HomeStyle.bubble.opacity(0.7), lineWidth: 1).frame(width: 6, height: 6)
                .offset(x: -6, y: 12)
        }
        .offset(x: -4, y: -6 - rise)
        .accessibilityHidden(true)
    }

    /// Eight steps a second; with reduced motion only time away is lived,
    /// for the right still pose.
    private func live() async {
        guard !reduceMotion else {
            life.settle(now: .now)
            return
        }
        while !Task.isCancelled {
            life.advance(now: .now, stage: .compact)
            try? await Task.sleep(for: .milliseconds(125))
        }
    }
}
#endif
