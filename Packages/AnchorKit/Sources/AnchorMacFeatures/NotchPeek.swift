#if os(macOS)
import AnchorCore
import AnchorDesign
import Foundation

/// A moment of news the closed island stretches out to show for a few
/// seconds: a task's agent finished or waits on the person, the phone left,
/// or the phone needs the pairing code, which stays until pairing is done.
public struct NotchPeek: Identifiable, Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case finished
        case waiting
        case linkLost
        case pairing
    }

    public static let enabledDefaultsKey = "anchor.mac.notch.peeks.enabled"

    public let id: UUID
    public let kind: Kind
    public let taskID: UUID?
    public let colorIndex: Int
    /// Left of the housing: the task, or the phone.
    public let title: String
    /// Right of the housing: where the conversation stands, the link, or the code.
    public let detail: String

    public init(kind: Kind, taskID: UUID? = nil, colorIndex: Int = 0, title: String, detail: String) {
        id = UUID()
        self.kind = kind
        self.taskID = taskID
        self.colorIndex = colorIndex
        self.title = title
        self.detail = detail
    }

    /// Waiting on the person stays longer; the pairing code stays until used.
    public var duration: Duration? {
        switch kind {
        case .finished, .linkLost: .seconds(4)
        case .waiting: .seconds(8)
        case .pairing: nil
        }
    }

    public static func pairing(code: String) -> NotchPeek {
        NotchPeek(kind: .pairing, title: L10n.pairingCode, detail: code)
    }
}

/// Finds news by comparing each open task's conversations with how they stood
/// at the previous look. The first look that sees any conversation only takes
/// note, so launching Anchor never replays what the person already saw, and
/// anything older than ten minutes is history (after a sleep, say).
public struct NotchPeekDetector: Sendable {
    static let freshness: TimeInterval = 10 * 60

    private struct Seen: Sendable {
        let signal: NotchIslandContent.Signal
        let updatedAt: Date
    }

    private var seen: [UUID: Seen] = [:]
    private var hasBaseline = false
    private var wasLinked: Bool?

    public init() {}

    public mutating func peeks(in projection: SessionProjection, link: AnchorStatusMenu.Link,
                               now: Date) -> [NotchPeek] {
        var peeks: [NotchPeek] = []
        let tasks = projection.hostedSessions.filter { $0.status == .active || $0.status == .draft }
        for task in tasks {
            for conversation in TaskConversationStack.conversations(of: task) {
                let signal = NotchIslandContent.signal(conversation)
                let before = seen[conversation.conversationKey]
                seen[conversation.conversationKey] = Seen(signal: signal, updatedAt: conversation.updatedAt)
                guard hasBaseline, now.timeIntervalSince(conversation.updatedAt) < Self.freshness else { continue }
                let kind: NotchPeek.Kind? = switch signal {
                case .done:
                    // A turn that ended, whether or not a look caught it running.
                    before.map { $0.signal != .done || conversation.updatedAt > $0.updatedAt } ?? true
                        ? .finished : nil
                case .waiting:
                    before?.signal == .waiting ? nil : .waiting
                case .running, .idle:
                    nil
                }
                if let kind {
                    peeks.append(NotchPeek(kind: kind, taskID: task.id, colorIndex: task.taskColorIndex ?? 0,
                                           title: task.goal.title, detail: L10n.runState(conversation)))
                }
            }
        }
        // An empty look may be the store still loading, not a real starting point.
        if !seen.isEmpty { hasBaseline = true }

        let isLinked = if case .connected = link { true } else { false }
        if wasLinked == true, !isLinked {
            // The icon says it is the phone; the right side says what happened.
            peeks.append(NotchPeek(kind: .linkLost, title: "", detail: StatusMenuCopy.link(link)))
        }
        wasLinked = isLinked
        return peeks
    }
}

/// Peeks waiting their turn. A newer one about the same task replaces the
/// older, so a task never queues twice; the pairing code goes first.
public struct NotchPeekQueue: Equatable, Sendable {
    static let capacity = 4

    public private(set) var items: [NotchPeek] = []

    public init() {}

    public var current: NotchPeek? { items.first }

    public mutating func add(_ peek: NotchPeek) {
        if let index = items.firstIndex(where: { Self.isSameSubject($0, peek) }) {
            items[index] = peek
        } else if peek.kind == .pairing {
            items.insert(peek, at: 0)
        } else {
            items.append(peek)
        }
        if items.count > Self.capacity {
            items.remove(at: 1)
        }
    }

    public mutating func advance() {
        if !items.isEmpty { items.removeFirst() }
    }

    public mutating func removePairing() {
        items.removeAll { $0.kind == .pairing }
    }

    /// Opening the island shows everything at once; only the code waits on.
    public mutating func clearNews() {
        items.removeAll { $0.kind != .pairing }
    }

    private static func isSameSubject(_ lhs: NotchPeek, _ rhs: NotchPeek) -> Bool {
        if let task = lhs.taskID { return task == rhs.taskID }
        return rhs.taskID == nil && lhs.kind == rhs.kind
    }
}
#endif
