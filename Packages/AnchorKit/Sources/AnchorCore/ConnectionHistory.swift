import Foundation

/// One moment the link to the other device came or went.
public struct ConnectionHistoryEntry: Codable, Hashable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case connected
        case disconnected
    }

    public let id: UUID
    public let kind: Kind
    public let date: Date
    public var device: PeerDeviceInfo?
    public var route: DevicePairingRoute?

    public init(id: UUID = UUID(), kind: Kind, date: Date, device: PeerDeviceInfo?, route: DevicePairingRoute?) {
        self.id = id
        self.kind = kind
        self.date = date
        self.device = device
        self.route = route
    }
}

/// This device's own log of the link, newest first, kept like a call list.
/// It lives only here and holds the latest few dozen changes.
public enum ConnectionHistory {
    static let key = "anchor.link.history"
    static let limit = 50

    public static func entries(in defaults: UserDefaults = .standard) -> [ConnectionHistoryEntry] {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([ConnectionHistoryEntry].self, from: $0) } ?? []
    }

    public static func record(
        _ kind: ConnectionHistoryEntry.Kind,
        device: PeerDeviceInfo?,
        route: DevicePairingRoute?,
        at date: Date = .now,
        in defaults: UserDefaults = .standard
    ) {
        var list = entries(in: defaults)
        list.insert(ConnectionHistoryEntry(kind: kind, date: date, device: device, route: route), at: 0)
        save(Array(list.prefix(limit)), in: defaults)
    }

    /// The peer names itself and its route a moment after the link opens;
    /// this completes the connection just recorded.
    public static func describeLatestConnection(
        device: PeerDeviceInfo?,
        route: DevicePairingRoute?,
        in defaults: UserDefaults = .standard
    ) {
        var list = entries(in: defaults)
        guard let latest = list.first, latest.kind == .connected else { return }
        var described = latest
        described.device = device ?? latest.device
        described.route = route ?? latest.route
        guard described != latest else { return }
        list[0] = described
        save(list, in: defaults)
    }

    private static func save(_ list: [ConnectionHistoryEntry], in defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(list) else { return }
        defaults.set(data, forKey: key)
    }
}
