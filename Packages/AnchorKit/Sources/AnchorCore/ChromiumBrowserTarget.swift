import Foundation

/// Browser locations supported by Anchor's fixed native-messaging installer.
/// The installer never accepts an arbitrary browser support path.
public enum ChromiumBrowserTarget: String, CaseIterable, Codable, Sendable {
    case chrome
    case edge
    case brave
    case chromium

    public var applicationBundleIdentifier: String {
        switch self {
        case .chrome: "com.google.Chrome"
        case .edge: "com.microsoft.edgemac"
        case .brave: "com.brave.Browser"
        case .chromium: "org.chromium.Chromium"
        }
    }

    public var applicationSupportPathComponents: [String] {
        switch self {
        case .chrome: ["Google", "Chrome"]
        case .edge: ["Microsoft Edge"]
        case .brave: ["BraveSoftware", "Brave-Browser"]
        case .chromium: ["Chromium"]
        }
    }

    /// Chrome documents user-level external Web Store installation on macOS.
    /// Other Chromium products retain the explicit store-page fallback until
    /// their product-specific behavior is validated for release.
    public var supportsExternalWebStoreInstall: Bool {
        self == .chrome
    }

    public func applicationSupportURL(homeDirectory: URL) -> URL {
        applicationSupportPathComponents.reduce(
            homeDirectory.appending(
                path: "Library/Application Support",
                directoryHint: .isDirectory
            )
        ) { url, component in
            url.appending(path: component, directoryHint: .isDirectory)
        }
    }

    public func nativeMessagingManifestURL(homeDirectory: URL) -> URL {
        applicationSupportURL(homeDirectory: homeDirectory)
            .appending(
                path: SourceArtifactInstaller.nativeMessagingDirectoryName,
                directoryHint: .isDirectory
            )
            .appending(
                path: SourceArtifactInstaller.nativeMessagingManifestName,
                directoryHint: .notDirectory
            )
    }

    public func externalExtensionPreferenceURL(homeDirectory: URL) -> URL {
        applicationSupportURL(homeDirectory: homeDirectory)
            .appending(path: "External Extensions", directoryHint: .isDirectory)
            .appending(
                path: "\(BrowserHostConfiguration.extensionID).json",
                directoryHint: .notDirectory
            )
    }
}
