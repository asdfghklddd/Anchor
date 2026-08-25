#if os(macOS)
import Foundation

/// A privacy-minimal snapshot of a regular macOS application. The workspace
/// source deliberately avoids window titles, documents, and application data.
public struct MacApplicationSnapshot: Hashable, Sendable {
    public let identifier: String
    public let localizedName: String
    public let processIdentifier: Int32
    public let isActive: Bool
    public let launchDate: Date?

    public init(
        identifier: String,
        localizedName: String,
        processIdentifier: Int32,
        isActive: Bool,
        launchDate: Date? = nil
    ) {
        self.identifier = identifier
        self.localizedName = localizedName
        self.processIdentifier = processIdentifier
        self.isActive = isActive
        self.launchDate = launchDate
    }
}
#endif
