#if os(macOS)
import AnchorCore
import Foundation

@MainActor
final class BrowserSetupServiceClient {
    func prepareBrowser(_ browser: MacSourceSetupBrowser) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, any Error>) in
            let connection = makeConnection()
            guard let service = connection.remoteObjectProxyWithErrorHandler({ error in
                connection.invalidate()
                continuation.resume(throwing: error)
            }) as? BrowserSetupXPCProtocol else {
                connection.invalidate()
                continuation.resume(throwing: BrowserSetupClientError.unavailable)
                return
            }
            service.prepareBrowser(forBrowser: browser.rawValue) { success, message in
                connection.invalidate()
                if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: BrowserSetupClientError.serviceFailure(message)
                    )
                }
            }
        }
    }

    func browserIsPrepared(_ browser: MacSourceSetupBrowser) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            let connection = makeConnection()
            guard let service = connection.remoteObjectProxyWithErrorHandler({ error in
                connection.invalidate()
                continuation.resume(throwing: error)
            }) as? BrowserSetupXPCProtocol else {
                connection.invalidate()
                continuation.resume(throwing: BrowserSetupClientError.unavailable)
                return
            }
            service.browserIsPrepared(forBrowser: browser.rawValue) { isCurrent, message in
                connection.invalidate()
                if let message {
                    continuation.resume(
                        throwing: BrowserSetupClientError.serviceFailure(message)
                    )
                } else {
                    continuation.resume(returning: isCurrent)
                }
            }
        }
    }

    private func makeConnection() -> NSXPCConnection {
        let connection = NSXPCConnection(
            serviceName: BrowserSetupServiceConfiguration.serviceName
        )
        connection.remoteObjectInterface = NSXPCInterface(with: BrowserSetupXPCProtocol.self)
        connection.resume()
        return connection
    }
}

private enum BrowserSetupClientError: LocalizedError {
    case serviceFailure(String?)
    case unavailable

    var errorDescription: String? {
        switch self {
        case let .serviceFailure(message):
            message ?? "Anchor could not configure this browser."
        case .unavailable:
            "Anchor's browser setup service is unavailable."
        }
    }
}
#endif
