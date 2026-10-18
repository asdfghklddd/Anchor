import AppKit

/// The welcome-back card's own small panel above the boat. It never takes
/// focus on its own; a click makes it key without activating Anchor, so Esc
/// can dismiss it.
final class AnchorWelcomePanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
