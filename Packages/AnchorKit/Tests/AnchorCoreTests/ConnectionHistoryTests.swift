import Foundation
import Testing
@testable import AnchorCore

@Suite("Connection history")
struct ConnectionHistoryTests {
    private let mac = PeerDeviceInfo(name: "MacBook Pro", model: "Mac", systemName: "macOS", systemVersion: "26.0")

    private func freshDefaults() -> UserDefaults {
        let name = "ConnectionHistoryTests.\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func newestComesFirst() {
        let defaults = freshDefaults()
        ConnectionHistory.record(.connected, device: mac, route: .bluetooth, at: .init(timeIntervalSince1970: 10), in: defaults)
        ConnectionHistory.record(.disconnected, device: mac, route: nil, at: .init(timeIntervalSince1970: 20), in: defaults)

        let entries = ConnectionHistory.entries(in: defaults)
        #expect(entries.map(\.kind) == [.disconnected, .connected])
        #expect(entries.last?.route == .bluetooth)
    }

    @Test func keepsOnlyTheLatestFifty() {
        let defaults = freshDefaults()
        for index in 0..<60 {
            ConnectionHistory.record(index.isMultiple(of: 2) ? .connected : .disconnected,
                                     device: nil, route: nil,
                                     at: .init(timeIntervalSince1970: TimeInterval(index)), in: defaults)
        }

        let entries = ConnectionHistory.entries(in: defaults)
        #expect(entries.count == 50)
        #expect(entries.first?.date == .init(timeIntervalSince1970: 59))
    }

    @Test func aLateNameCompletesTheConnection() {
        let defaults = freshDefaults()
        ConnectionHistory.record(.connected, device: nil, route: nil, in: defaults)
        ConnectionHistory.describeLatestConnection(device: mac, route: .trustedDevice, in: defaults)

        let latest = ConnectionHistory.entries(in: defaults).first
        #expect(latest?.device == mac)
        #expect(latest?.route == .trustedDevice)
    }

    @Test func aDisconnectionIsNeverRenamed() {
        let defaults = freshDefaults()
        ConnectionHistory.record(.disconnected, device: nil, route: nil, in: defaults)
        ConnectionHistory.describeLatestConnection(device: mac, route: .bluetooth, in: defaults)

        #expect(ConnectionHistory.entries(in: defaults).first?.device == nil)
    }
}
