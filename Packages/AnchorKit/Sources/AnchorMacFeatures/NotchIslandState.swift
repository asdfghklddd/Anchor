#if os(macOS)
import CoreGraphics
import Foundation
import Observation

public enum NotchIslandPhase: Equatable, Sendable {
    /// Hugging the housing: a dot per task, the phone link.
    case compact
    /// The pointer arrived; a small swell answers it before the island opens.
    case primed
    /// Stretched sideways for a few seconds to show one piece of news.
    case peek
    case expanded
}

/// When the island opens and closes under the pointer. The pointer has to
/// rest a moment before the island opens, so passing by does nothing, and
/// may slip out briefly without closing it. Opened from the keyboard, it
/// stays until dismissed.
public struct NotchHoverMachine: Equatable, Sendable {
    public enum Timer: Equatable, Sendable {
        case dwell
        case grace
    }

    public static let dwell = Duration.milliseconds(90)
    public static let grace = Duration.milliseconds(350)

    public private(set) var phase = NotchIslandPhase.compact
    public private(set) var isPinned = false
    public private(set) var isPointerInside = false

    public init() {}

    /// The timer to start, if any. Pointing at a peek opens it at once.
    public mutating func pointerEntered() -> Timer? {
        guard !isPointerInside else { return nil }
        isPointerInside = true
        switch phase {
        case .compact:
            phase = .primed
            return .dwell
        case .peek:
            phase = .expanded
            return nil
        case .primed, .expanded:
            return nil
        }
    }

    public mutating func pointerExited() -> Timer? {
        guard isPointerInside else { return nil }
        isPointerInside = false
        switch phase {
        case .primed:
            phase = .compact
            return nil
        case .expanded:
            return isPinned ? nil : .grace
        case .compact, .peek:
            return nil
        }
    }

    /// Only a closed island the pointer is not on shows news.
    public mutating func showPeek() -> Bool {
        guard phase == .compact, !isPointerInside else { return phase == .peek }
        phase = .peek
        return true
    }

    public mutating func endPeek() {
        if phase == .peek { phase = .compact }
    }

    public mutating func dwellElapsed() {
        if phase == .primed, isPointerInside { phase = .expanded }
    }

    public mutating func graceElapsed() {
        if phase == .expanded, !isPointerInside, !isPinned { phase = .compact }
    }

    /// Opens without the pointer, from the keyboard or a notification.
    public mutating func open(pinned: Bool) {
        phase = .expanded
        isPinned = isPinned || pinned
    }

    /// Esc, a click elsewhere, or the shortcut again. The pointer has to leave
    /// and come back before hovering opens it again.
    public mutating func dismiss() {
        phase = .compact
        isPinned = false
    }
}

/// What the island view draws; the panel controller writes it.
@MainActor
@Observable
public final class NotchIslandState {
    public var phase = NotchIslandPhase.compact
    public var content: NotchIslandContent
    public var geometry: NotchIslandGeometry
    /// The open island's content below the housing, as last measured.
    public var contentHeight: CGFloat = 180
    /// The news the island is stretched out to show.
    public var peek: NotchPeek?
    /// The task the person opened the island from a peek about.
    public var highlightedTaskID: UUID?
    /// Bumped to make the closed island give a small sideways nudge.
    public var nudges = 0
    /// Bumped per task to make its dot light up once.
    public var flashes: [UUID: Int] = [:]

    public init(content: NotchIslandContent, geometry: NotchIslandGeometry) {
        self.content = content
        self.geometry = geometry
    }

    public func flash(_ taskID: UUID) {
        flashes[taskID, default: 0] += 1
    }

    public var islandSize: CGSize {
        switch phase {
        case .compact: geometry.compactSize
        case .primed: geometry.primedSize
        case .peek: geometry.peekSize
        case .expanded: CGSize(width: geometry.expandedWidth, height: geometry.notch.height + contentHeight)
        }
    }

    /// Where the pointer counts as on the island, in screen coordinates. The
    /// closed island's zone reaches a little below it, so the pointer need not
    /// land exactly on its edge.
    public var pointerZone: CGRect {
        let frame = geometry.islandFrame(size: islandSize)
        switch phase {
        case .compact, .primed, .peek:
            return CGRect(x: frame.minX - 2, y: frame.minY - 4, width: frame.width + 4, height: frame.height + 4)
        case .expanded: return frame.insetBy(dx: -8, dy: -8)
        }
    }
}
#endif
