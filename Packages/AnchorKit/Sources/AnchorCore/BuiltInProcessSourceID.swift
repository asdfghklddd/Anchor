import Foundation

/// Stable identities shared by ingestion and presentation across platforms.
public enum BuiltInProcessSourceID {
    public static let file = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0x04, 0x01)
    )
    public static let web = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0x04, 0x02)
    )
    public static let macWorkspace = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0x04, 0x03)
    )
    public static let codex = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0x40, 0, 0x80, 0, 0, 0, 0, 0, 0x04, 0x04)
    )
}
