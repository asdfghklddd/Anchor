import AppKit

/// A small panel beside the boat: the welcome-back card, or the buttons the
/// boat opens. It takes key focus without activating Anchor, so Esc closes it
/// while the person's own app stays in front.
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
