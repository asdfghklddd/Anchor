#if os(macOS)
import AppKit
import CoreGraphics

/// Where the island sits and how big each of its shapes is. Everything is in
/// screen points, measured from the top of the screen it lives on.
public struct NotchIslandGeometry: Equatable, Sendable {
    /// The camera housing, or the stand-in drawn on a screen without one.
    public let notch: CGSize
    /// The notch's horizontal center, in screen coordinates.
    public let notchMidX: CGFloat
    /// The top edge of the screen, in screen coordinates.
    public let screenMaxY: CGFloat
    public let hasNotch: Bool

    /// A screen without a camera housing still gets a dark handle this wide.
    static let standInWidth: CGFloat = 164
    /// The island's widest shape; the expanded panel never grows past it.
    public static let expandedWidth: CGFloat = 500
    /// Room around the expanded island for its shadow.
    static let shadowRoom: CGFloat = 48
    /// The panel stays this tall; only the island inside it changes size.
    static let panelHeight: CGFloat = 460

    public init(notch: CGSize, notchMidX: CGFloat, screenMaxY: CGFloat, hasNotch: Bool) {
        self.notch = notch
        self.notchMidX = notchMidX
        self.screenMaxY = screenMaxY
        self.hasNotch = hasNotch
    }

    /// Reads the housing from the screen's unobscured top corners; a screen
    /// without one gets a handle as tall as its menu bar.
    @MainActor
    public init(screen: NSScreen) {
        let frame = screen.frame
        if screen.safeAreaInsets.top > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let width = frame.width - left.width - right.width
            self.init(
                notch: CGSize(width: width, height: screen.safeAreaInsets.top),
                notchMidX: frame.minX + left.width + width / 2,
                screenMaxY: frame.maxY,
                hasNotch: true
            )
        } else {
            let menuBar = frame.maxY - screen.visibleFrame.maxY
            self.init(
                notch: CGSize(width: Self.standInWidth, height: menuBar > 0 ? menuBar : 24),
                notchMidX: frame.midX,
                screenMaxY: frame.maxY,
                hasNotch: false
            )
        }
    }

    /// The screen with a camera housing, else the one with the menu bar.
    @MainActor
    public static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens.first
    }

    /// One ear beside the housing, wide enough for a dot per task.
    public func earWidth(dots: Int) -> CGFloat {
        let content = CGFloat(max(1, dots)) * NotchIslandMetrics.dot
            + CGFloat(max(0, dots - 1)) * NotchIslandMetrics.dotSpacing
        return max(36, content + 22)
    }

    public func compactSize(dots: Int) -> CGSize {
        CGSize(width: notch.width + earWidth(dots: dots) * 2, height: notch.height)
    }

    /// The small swell that answers the pointer before the island opens.
    public func primedSize(dots: Int) -> CGSize {
        let compact = compactSize(dots: dots)
        return CGSize(width: compact.width + 10, height: compact.height + 3)
    }

    public var expandedWidth: CGFloat {
        max(Self.expandedWidth, notch.width + 260)
    }

    /// As wide as the open island, so opening a peek only grows it downward.
    public var peekSize: CGSize {
        CGSize(width: expandedWidth, height: notch.height + 4)
    }

    /// The panel: wide and tall enough for the expanded island and its shadow,
    /// hanging from the top of the screen and centered on the housing.
    public var panelFrame: CGRect {
        let width = expandedWidth + Self.shadowRoom * 2
        return CGRect(
            x: notchMidX - width / 2,
            y: screenMaxY - Self.panelHeight,
            width: width,
            height: Self.panelHeight
        )
    }

    /// The island's shape in screen coordinates for a given size.
    public func islandFrame(size: CGSize) -> CGRect {
        CGRect(x: notchMidX - size.width / 2, y: screenMaxY - size.height,
               width: size.width, height: size.height)
    }
}

/// Fixed measures shared by the island's shape and its contents.
public enum NotchIslandMetrics {
    static let dot: CGFloat = 8
    static let dotSpacing: CGFloat = 9
    /// The flare where the island meets the screen's top edge.
    static let compactFlare: CGFloat = 6
    static let expandedFlare: CGFloat = 10
    static let compactRadius: CGFloat = 10
    static let primedRadius: CGFloat = 12
    static let peekRadius: CGFloat = 16
    static let expandedRadius: CGFloat = 24
    static let inset: CGFloat = 14
}
#endif
