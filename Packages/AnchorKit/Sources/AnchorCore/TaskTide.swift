import Foundation

/// What a conversation was doing during a stretch of time. Derived only from
/// reported lifecycle events and the source-owned status; never from guesses.
public enum TideState: String, Hashable, Sendable {
    case running
    case attention
    case failed
    case interrupted
    case completed

    /// Ending states are drawn as a marker at the moment they were reported.
    public var isTerminal: Bool {
        self == .failed || self == .interrupted || self == .completed
    }

    /// Higher values sit on top when conversations of one task overlap.
    public var drawingPriority: Int {
        switch self {
        case .running: 0
        case .completed: 1
        case .interrupted: 2
        case .attention: 3
        case .failed: 4
        }
    }
}

public struct TideSegment: Hashable, Sendable {
    public let start: Date
    public let end: Date
    public let state: TideState
    /// True while the state is still current at `now`.
    public let isOpen: Bool

    public init(start: Date, end: Date, state: TideState, isOpen: Bool) {
        self.start = start
        self.end = end
        self.state = state
        self.isOpen = isOpen
    }
}

/// State-over-time for the home dashboard. Sources report lifecycle moments
/// (started, finished, failed, stopped), not percentages, so this is what the
/// glance view shows.
public enum TaskTide {
    /// The visible window: back to the earliest anchor, rounded up to a readable span.
    public static func windowSpan(for tasks: [AnchorSession], now: Date) -> TimeInterval {
        let needed = now.timeIntervalSince(tasks.map(\.startedAt).min() ?? now)
        return [1_800, 3_600, 5_400, 7_200, 10_800, 14_400, 21_600, 28_800].first { $0 >= needed } ?? 28_800
    }

    public static func segments(for session: AnchorSession, now: Date) -> [TideSegment] {
        session.taskProcesses
            .flatMap { segments(for: $0, now: now) }
            .sorted { ($0.state.drawingPriority, $0.start) < ($1.state.drawingPriority, $1.start) }
    }

    public static func segments(for process: AnchorProcess, now: Date) -> [TideSegment] {
        let lifecycle = process.events
            .filter { state(for: $0) != nil }
            .sorted { ($0.occurredAt, $0.id.uuidString) < ($1.occurredAt, $1.id.uuidString) }
        var result: [TideSegment] = []
        var current: (state: TideState, start: Date)?

        func close(at date: Date) {
            guard let open = current else { return }
            result.append(TideSegment(start: open.start, end: max(open.start, date), state: open.state, isOpen: false))
            current = nil
        }

        for event in lifecycle {
            guard let next = state(for: event) else { continue }
            let time = min(event.occurredAt, now)
            if next.isTerminal {
                close(at: time)
                result.append(TideSegment(start: time, end: time, state: next, isOpen: false))
            } else if current?.state != next {
                close(at: time)
                current = (next, time)
            }
        }

        // The source-owned status is the latest truth; it may have moved on
        // without a matching lifecycle event (for example a blocked process).
        let reported = state(for: process)
        let statusTime = min(process.updatedAt, now)
        if let open = current {
            if let reported, reported != open.state, statusTime >= open.start {
                close(at: statusTime)
                if reported.isTerminal {
                    result.append(TideSegment(start: statusTime, end: statusTime, state: reported, isOpen: false))
                } else {
                    result.append(TideSegment(start: statusTime, end: now, state: reported, isOpen: true))
                }
            } else {
                result.append(TideSegment(start: open.start, end: now, state: open.state, isOpen: true))
            }
        } else if let reported {
            let lastTerminal = result.last { $0.state.isTerminal }
            if !reported.isTerminal, lastTerminal.map({ $0.end <= statusTime }) ?? true {
                result.append(TideSegment(start: statusTime, end: now, state: reported, isOpen: true))
            } else if reported.isTerminal, lastTerminal == nil {
                result.append(TideSegment(start: statusTime, end: statusTime, state: reported, isOpen: false))
            }
        }
        return result
    }

    private static func state(for event: ProcessEvent) -> TideState? {
        switch event.kind {
        case .created, .progress, .outputReady, .decisionResolved: .running
        case .decisionRequired: .attention
        case .completed: .completed
        case .failed: event.isInterruption ? .interrupted : .failed
        case .note, .presence, .connection: nil
        }
    }

    private static func state(for process: AnchorProcess) -> TideState? {
        switch process.status {
        case .running: .running
        case .needsDecision, .blocked, .disconnected: .attention
        case .completed: .completed
        case .failed: process.isInterrupted ? .interrupted : .failed
        case .queued: nil
        }
    }
}

/// One answer to "what is happening, and does anything need me?" across all
/// hosted tasks. Counts are per conversation, using the same rules as the
/// task cards' lights (D02).
public struct WorkGlance: Hashable, Sendable {
    public enum Headline: Hashable, Sendable {
        case empty
        case awaitingSources
        case failed(Int)
        case attention(Int)
        case running(Int)
        case allCompleted
        case quiet
    }

    public struct Change: Hashable, Sendable {
        public let event: ProcessEvent
        public let processTitle: String
        public let sourceName: String
        public let taskID: UUID
        public let taskTitle: String
        public let isInterruption: Bool
    }

    public let taskCount: Int
    public let running: Int
    public let attention: Int
    public let failed: Int
    public let completed: Int
    public let latestChange: Change?

    public init(tasks: [AnchorSession]) {
        let processes = tasks.flatMap(\.taskProcesses)
        taskCount = tasks.count
        running = processes.filter { $0.status == .running }.count
        failed = processes.filter { $0.status == .failed && !$0.isInterrupted }.count
        attention = processes.filter {
            [.needsDecision, .blocked, .disconnected].contains($0.status) || $0.isInterrupted
        }.count
        completed = processes.filter { $0.status == .completed }.count

        var latest: Change?
        for task in tasks {
            for process in task.taskProcesses {
                for event in process.events where Self.isMeaningful(event) {
                    if let current = latest?.event,
                       (current.occurredAt, current.id.uuidString) >= (event.occurredAt, event.id.uuidString) { continue }
                    latest = Change(event: event, processTitle: process.title, sourceName: process.sourceName,
                                    taskID: task.id, taskTitle: task.goal.title,
                                    isInterruption: event.isInterruption)
                }
            }
        }
        latestChange = latest
    }

    public var headline: Headline {
        if taskCount == 0 { return .empty }
        if failed > 0 { return .failed(failed) }
        if attention > 0 { return .attention(attention) }
        if running > 0 { return .running(running) }
        if completed > 0 { return .allCompleted }
        return running + attention + failed + completed == 0 ? .awaitingSources : .quiet
    }

    private static func isMeaningful(_ event: ProcessEvent) -> Bool {
        switch event.kind {
        case .created, .outputReady, .decisionRequired, .completed, .failed: true
        case .progress, .decisionResolved, .note, .presence, .connection: false
        }
    }
}
