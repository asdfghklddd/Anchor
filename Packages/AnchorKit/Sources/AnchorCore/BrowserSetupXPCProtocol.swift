#if os(macOS)
import Foundation

public enum BrowserSetupServiceConfiguration {
    public static let serviceName = "com.andywang.anchor.browser-setup"
}

/// The private XPC surface intentionally accepts only a known browser value.
/// The service computes both source and destination paths itself.
@objc public protocol BrowserSetupXPCProtocol {
    func prepareBrowser(
        forBrowser browser: String,
        withReply reply: @escaping (Bool, String?) -> Void
    )

    func browserIsPrepared(
        forBrowser browser: String,
        withReply reply: @escaping (Bool, String?) -> Void
    )
}
#endif
