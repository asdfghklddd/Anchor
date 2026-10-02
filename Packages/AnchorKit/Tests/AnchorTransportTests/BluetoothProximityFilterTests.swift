import Foundation
import Testing
@testable import AnchorTransport

@Suite("Connected Bluetooth RSSI")
struct BluetoothProximityFilterTests {
    @Test("Three samples and a dead band suppress threshold chatter")
    func stabilizesSamples() {
        var filter = BluetoothProximityFilter()
        #expect(filter.sample(-60) == .unknown)
        #expect(filter.sample(-61) == .unknown)
        #expect(filter.sample(-62) == .near)
        #expect(filter.sample(-80) == .near)
        #expect(filter.sample(-70) == .near)
        #expect(filter.sample(-80) == .near)
        #expect(filter.sample(-81) == .near)
        #expect(filter.sample(-82) == .far)
    }

    @Test("The middle band preserves a discrete state, never a linear distance")
    func middleBandAndReversal() {
        var filter = BluetoothProximityFilter()
        for value in [-70, -69, -71] { #expect(filter.sample(value) == .unknown) }
        for _ in 0..<3 { _ = filter.sample(-80) }
        for value in [-70, -69, -71, -64, -76, -64, -76] {
            #expect(filter.sample(value) == .far)
        }
        #expect(filter.sample(-60) == .far)
        #expect(filter.sample(-60) == .far)
        #expect(filter.sample(-60) == .near)
        for value in [-70, -69, -71] { #expect(filter.sample(value) == .near) }
    }

    @Test("Invalid RSSI and stale samples cannot report old proximity")
    func invalidAndStale() {
        var filter = BluetoothProximityFilter()
        let start = Date(timeIntervalSince1970: 1_000)
        for _ in 0..<3 { _ = filter.sample(-60, at: start) }
        #expect(filter.state == .near)
        #expect(filter.sample(127, at: start) == .unknown)
        for _ in 0..<3 { _ = filter.sample(-80, at: start) }
        #expect(filter.state == .far)
        #expect(filter.sample(-80, at: start.addingTimeInterval(13)) == .unknown)
        #expect(filter.reset() == .unknown)
    }
}
