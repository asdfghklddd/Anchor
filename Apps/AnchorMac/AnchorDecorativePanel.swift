import AppKit

/// Keeps the visual-only travel layer out of VoiceOver and window managers.
final class AnchorDecorativePanel: NSPanel {
    nonisolated override func accessibilityIsIgnored() -> Bool {
        true
    }

    nonisolated override func accessibilityHitTest(_ point: NSPoint) -> Any? {
        nil
    }
}
