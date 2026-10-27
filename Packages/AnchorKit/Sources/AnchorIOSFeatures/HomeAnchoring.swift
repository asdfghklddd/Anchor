#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// The portrait home's colors, from the owner's mockup (2026-10-27).
enum HomeStyle {
    static let canvasTop = Color(AnchorColorTokens.homeCanvasTop)
    static let canvasDeep = Color(AnchorColorTokens.homeCanvasDeep)
    static let dome = Color(AnchorColorTokens.homeDome)
    static let ink = Color(AnchorColorTokens.homeInk)
    static let cardTitle = Color(AnchorColorTokens.homeCardTitle)
    static let disc = Color(AnchorColorTokens.homeDisc)
    static let quiet = Color(AnchorColorTokens.homeQuiet)
    static let synced = Color(AnchorColorTokens.homeSynced)
    static let linked = Color(AnchorColorTokens.homeLinked)
    static let tokens = Color(AnchorColorTokens.homeTokens)
    static let slotPast = Color(AnchorColorTokens.homeSlotPast)
    static let slotAhead = Color(AnchorColorTokens.homeSlotAhead)
    static let anchor = Color(AnchorColorTokens.homeAnchor)
    static let done = Color(AnchorColorTokens.homeDone)
    static let bubble = Color(AnchorColorTokens.homeBubble)
    static let library = Color(AnchorColorTokens.homeLibrary)
    static let libraryTitle = Color(AnchorColorTokens.homeLibraryTitle)
    static let cardText = Color(AnchorColorTokens.homeCardText)
    static let cardNote = Color(AnchorColorTokens.homeCardNote)
    /// The pin around the person's avatar on the task they are on.
    static let pin = Color(AnchorColorTokens.homePin)

    static func task(_ task: AnchorSession) -> Color {
        Color(AnchorColorTokens.homeTasks[(task.taskColorIndex ?? 0) % AnchorColorTokens.homeTasks.count])
    }

    static func wash(_ task: AnchorSession) -> Color {
        Color(AnchorColorTokens.homeTaskWashes[(task.taskColorIndex ?? 0) % AnchorColorTokens.homeTaskWashes.count])
    }
    /// A soft teal shadow under cards, matched to the mockup's placeholder card.
    static let cardShadow = Color(red: 0.12, green: 0.37, blue: 0.45)
}

/// The home's water. The gradient reaches its deep color at twice the screen's
/// height, so the visible part stays pale, as in the mockup.
struct HomeWater: View {
    var body: some View {
        LinearGradient(colors: [HomeStyle.canvasTop, HomeStyle.canvasDeep],
                       startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 1.95))
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// A wide circular crest (radius 343 on a 402-point screen) running down to the bottom.
struct HomeDomeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = 343 * rect.width / 402
        let center = CGPoint(x: rect.midX, y: rect.minY + radius)
        let half = rect.width / 2
        let edgeY = center.y - (radius * radius - half * half).squareRoot()
        let angle = Angle(radians: Double(asin(half / radius)))
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: edgeY))
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(-90) - angle, endAngle: .degrees(-90) + angle, clockwise: false)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Everything around the dome, for keeping its shade outside it.
struct HomeOutsideDome: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(rect.insetBy(dx: -20, dy: -20))
        path.addPath(HomeDomeShape().path(in: rect))
        return path
    }
}

/// The dome's cyan fades into the water over its first 300 points.
struct HomeDome: View {
    static let fade: CGFloat = 300
    static let height: CGFloat = 1_200

    var body: some View {
        HomeDomeShape()
            .fill(LinearGradient(stops: [
                .init(color: HomeStyle.dome, location: 0),
                .init(color: HomeStyle.dome.opacity(0.9), location: 0.08 * Self.fade / Self.height),
                .init(color: HomeStyle.dome.opacity(0.62), location: 0.28 * Self.fade / Self.height),
                .init(color: HomeStyle.dome.opacity(0.27), location: 0.61 * Self.fade / Self.height),
                .init(color: HomeStyle.dome.opacity(0), location: Self.fade / Self.height),
            ], startPoint: .top, endPoint: .bottom))
            // A faint shade just above the crest, kept off the fading cyan itself.
            .background {
                HomeDomeShape().fill(.black.opacity(0.07)).blur(radius: 3).offset(y: -1)
                    .mask { HomeOutsideDome().fill(style: FillStyle(eoFill: true)) }
            }
            .frame(height: Self.height)
            .accessibilityHidden(true)
    }
}

/// "Today's Anchoring": time linked to the Mac today, the goal, and the tokens
/// agents used in each half hour around now.
struct HomeAnchoringPanel: View {
    let log: AnchoringLog
    @AppStorage(AnchoringLog.goalKey) private var goalMinutes = AnchoringLog.defaultGoalMinutes
    @State private var editingGoal = false
    @AnchorReducedMotion private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Text(AnchorStrings.value("home.anchoring.title", default: "Today’s Anchoring"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(HomeStyle.ink)
                .frame(height: 22)
                .accessibilityAddTraits(.isHeader)
            // Ticks each second only while linked; otherwise the total holds still.
            TimelineView(.periodic(from: .now, by: log.linkedSince == nil ? 60 : 1)) { context in
                clock(seconds: log.total(now: context.date))
            }
            .padding(.top, -1)
            goal
                .padding(.top, 9)
            TimelineView(.periodic(from: .now, by: 60)) { context in
                HomeTokenBars(tokens: log.tokens, now: context.date)
            }
            .padding(.top, 12)
        }
        .sheet(isPresented: $editingGoal) {
            HomeGoalPicker(minutes: $goalMinutes)
        }
    }

    private func clock(seconds: TimeInterval) -> some View {
        let reached = seconds >= TimeInterval(goalMinutes * 60) && goalMinutes > 0
        let total = Int(seconds)
        let text = String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
        return Text(text)
            // 62 with a hair of tracking matches the mockup's 60 px Figma render.
            .font(AnchorFonts.poppins(62, relativeTo: .largeTitle))
            .tracking(0.6)
            .monospacedDigit()
            .foregroundStyle(reached ? HomeStyle.done : HomeStyle.ink)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: reached)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(height: 90)
            .accessibilityLabel(Duration.seconds(total).formatted(.units(allowed: [.hours, .minutes], width: .wide)))
            .accessibilityIdentifier("home.anchoring.clock")
    }

    private var goal: some View {
        Button { editingGoal = true } label: {
            HStack(spacing: 6) {
                Text(AnchorStrings.value("home.anchoring.goal", default: "Goal"))
                Text(String(format: "%02d:%02d", goalMinutes / 60, goalMinutes % 60)).monospacedDigit()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).padding(.leading, 6)
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(HomeStyle.ink)
            .frame(minHeight: 20)
            .padding(.horizontal, 12)
            .contentShape(.rect)
        }
        .buttonStyle(AnchorPressButtonStyle())
        .accessibilityIdentifier("home.anchoring.goal")
    }
}

/// Twenty-three half-hour slots, as in the mockup: sixteen up to now, seven still ahead.
/// A slot with tokens is an amber bar scaled to the busiest slot; an empty
/// past slot is a white dash and a slot still ahead a grey one.
struct HomeTokenBars: View {
    let tokens: [Date: Int]
    let now: Date
    static let past = 16
    static let ahead = 7
    private static let pitch: CGFloat = 15
    private static let barWidth: CGFloat = 10
    private static let tallest: CGFloat = 66

    var body: some View {
        let current = DayActivity.slotStart(of: now)
        let starts = (0..<(Self.past + Self.ahead)).map {
            current.addingTimeInterval(Double($0 - Self.past + 1) * DayActivity.slotLength)
        }
        let busiest = max(1, starts.compactMap { tokens[$0] }.max() ?? 1)
        VStack(spacing: 2) {
            HStack(alignment: .bottom, spacing: Self.pitch - Self.barWidth) {
                ForEach(starts, id: \.self) { start in
                    slot(start: start, current: current, busiest: busiest)
                        .frame(width: Self.barWidth, height: Self.tallest, alignment: .bottom)
                }
            }
            HStack(spacing: Self.pitch - Self.barWidth) {
                ForEach(starts, id: \.self) { start in
                    Text(hourMark(start) ?? "")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(HomeStyle.tokens)
                        .fixedSize()
                        .frame(width: Self.barWidth)
                }
            }
            .frame(height: 10)
        }
        .accessibilityElement()
        .accessibilityLabel(AnchorStrings.value("home.tokens.a11y", default: "Tokens used in the last 12 hours"))
    }

    @ViewBuilder
    private func slot(start: Date, current: Date, busiest: Int) -> some View {
        if start > current {
            Capsule().fill(HomeStyle.slotAhead).frame(width: 8, height: 6)
        } else if let used = tokens[start], used > 0 {
            Capsule().fill(HomeStyle.tokens)
                .frame(height: max(Self.barWidth, Self.tallest * CGFloat(used) / CGFloat(busiest)))
        } else {
            Capsule().fill(HomeStyle.slotPast).frame(width: 8, height: 6)
        }
    }

    /// Every third hour, under the slot that starts on it.
    private func hourMark(_ start: Date) -> String? {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: start)
        guard parts.minute == 0, let hour = parts.hour, hour % 3 == 0 else { return nil }
        return "\(hour)"
    }
}

/// How long the person means to anchor today, in quarter hours.
struct HomeGoalPicker: View {
    @Binding var minutes: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("", selection: Binding(get: { minutes / 60 }, set: { minutes = $0 * 60 + minutes % 60 })) {
                    ForEach(0...16, id: \.self) { Text("\($0) \(AnchorStrings.value("home.anchoring.hours", default: "h"))").tag($0) }
                }
                Picker("", selection: Binding(get: { minutes % 60 / 15 * 15 }, set: { minutes = minutes / 60 * 60 + $0 })) {
                    ForEach([0, 15, 30, 45], id: \.self) {
                        Text("\($0) \(AnchorStrings.value("home.anchoring.minutes", default: "min"))").tag($0)
                    }
                }
            }
            .pickerStyle(.wheel)
            .padding(.horizontal, 20)
            .navigationTitle(AnchorStrings.value("home.anchoring.goal.title", default: "Today’s anchoring goal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { dismiss() }
                }
            }
        }
        .presentationDetents([.height(320)])
    }
}
#endif
