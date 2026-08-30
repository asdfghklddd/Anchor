import AnchorCore
import Foundation
import SafariServices

/// Validates Safari messages before they enter Anchor's shared observation inbox.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        do {
            let request = context.inputItems.first as? NSExtensionItem
            guard let message = request?.userInfo?[SFExtensionMessageKey] else {
                throw SafariWebExtensionError.missingMessage
            }
            let data = try JSONSerialization.data(withJSONObject: message)
            let signal = try JSONDecoder.anchorExternal.decode(
                WebProcessSignal.self,
                from: data
            )
            try signal.validate()
            try queue(signal)
            complete(context, response: ["ok": true])
        } catch {
            complete(context, response: ["ok": false])
        }
    }

    private func queue(_ signal: WebProcessSignal) throws {
        let directoryURL = FileProcessSource.defaultWebInboxURL()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let temporaryURL = directoryURL.appending(
            path: ".\(signal.id.uuidString).tmp",
            directoryHint: .notDirectory
        )
        let destinationURL = directoryURL.appending(
            path: "\(signal.id.uuidString).json",
            directoryHint: .notDirectory
        )
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try JSONEncoder.anchorExternal.encode(signal).write(
            to: temporaryURL,
            options: .atomic
        )
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
    }

    private func complete(
        _ context: NSExtensionContext,
        response: [String: Any]
    ) {
        let item = NSExtensionItem()
        item.userInfo = [SFExtensionMessageKey: response]
        context.completeRequest(returningItems: [item])
    }
}

private enum SafariWebExtensionError: Error {
    case missingMessage
}
