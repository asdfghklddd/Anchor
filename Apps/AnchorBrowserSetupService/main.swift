import AnchorCore
import Darwin
import Foundation

private final class BrowserSetupService: NSObject, BrowserSetupXPCProtocol {
    private let installer = SourceArtifactInstaller()

    func prepareBrowser(
        forBrowser browser: String,
        withReply reply: @escaping (Bool, String?) -> Void
    ) {
        do {
            let target = try browserTarget(for: browser)
            try installer.installBrowserManifest(
                helperURL: try embeddedBridgeURL(),
                browser: target
            )
            try installer.installExternalExtensionPreference(browser: target)
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    func browserIsPrepared(
        forBrowser browser: String,
        withReply reply: @escaping (Bool, String?) -> Void
    ) {
        do {
            let target = try browserTarget(for: browser)
            let manifestIsCurrent = installer.browserManifestIsCurrent(
                at: target.nativeMessagingManifestURL(
                    homeDirectory: FileManager.default.homeDirectoryForCurrentUser
                ),
                helperURL: try embeddedBridgeURL()
            )
            let extensionIsPrepared = installer.externalExtensionPreferenceIsCurrent(
                browser: target
            )
            reply(manifestIsCurrent && extensionIsPrepared, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }

    private func browserTarget(for rawValue: String) throws -> ChromiumBrowserTarget {
        guard let browser = ChromiumBrowserTarget(rawValue: rawValue) else {
            throw BrowserSetupServiceError.unsupportedBrowser
        }
        return browser
    }

    private func embeddedBridgeURL() throws -> URL {
        let contentsURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let bridgeURL = contentsURL.appending(
            path: "Helpers/AnchorWebBridge",
            directoryHint: .notDirectory
        )
        guard FileManager.default.isExecutableFile(atPath: bridgeURL.path) else {
            throw BrowserSetupServiceError.missingBridge
        }
        return bridgeURL
    }
}

private final class BrowserSetupServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        guard newConnection.effectiveUserIdentifier == getuid() else { return false }
        newConnection.exportedInterface = NSXPCInterface(with: BrowserSetupXPCProtocol.self)
        newConnection.exportedObject = BrowserSetupService()
        newConnection.resume()
        return true
    }
}

private enum BrowserSetupServiceError: LocalizedError {
    case missingBridge
    case unsupportedBrowser

    var errorDescription: String? {
        switch self {
        case .missingBridge:
            "The signed Anchor browser bridge is missing."
        case .unsupportedBrowser:
            "Anchor does not support this browser."
        }
    }
}

private let listener = NSXPCListener.service()
private let delegate = BrowserSetupServiceDelegate()
listener.delegate = delegate
listener.resume()
dispatchMain()
