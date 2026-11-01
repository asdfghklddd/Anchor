import AnchorCore
import AppKit

/// Opens an agent conversation in its app, as the phone asked: Codex at the
/// thread; Claude at its Code tab, with the resume command on the clipboard
/// since the app cannot open one session by itself.
public enum MacConversationOpener {
    @MainActor
    public static func open(logAt fileURL: URL) {
        guard let link = ConversationLink(logAt: fileURL) else { return }
        if let command = link.resumeCommand {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
        }
        NSWorkspace.shared.open(link.url)
    }
}
