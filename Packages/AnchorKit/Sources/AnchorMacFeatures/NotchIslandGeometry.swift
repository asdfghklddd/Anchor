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
    public static let expandedWidth: CGFloat = 420
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

    /// One ear beside the housing: the stacked task pills on the left, the
    /// plan ring or a link warning on the right. Both sides match, so the
    /// island stays centred on the camera.
    public var earWidth: CGFloat {
        NotchIslandMetrics.pillWidth + 14
    }

    public var compactSize: CGSize {
        CGSize(width: notch.width + earWidth * 2, height: notch.height)
    }

    /// The small swell that answers the pointer before the island opens.
    public var primedSize: CGSize {
        CGSize(width: compactSize.width + 10, height: compactSize.height + 3)
    }

    public var expandedWidth: CGFloat {
        max(Self.expandedWidth, notch.width + 220)
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
    /// A task's dot, where a peek names the task.
    static let dot: CGFloat = 8
    /// A task's pill, one per row like the open island's task list.
    static let pillWidth: CGFloat = 12
    static let pillHeight: CGFloat = 4
    static let pillSpacing: CGFloat = 4
    /// The current task's plan ring in the right ear.
    static let ring: CGFloat = 13
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
