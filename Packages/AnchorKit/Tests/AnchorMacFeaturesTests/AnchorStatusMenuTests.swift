import AnchorCore
import Foundation
import Testing
@testable import AnchorMacFeatures

@Suite("Phone link")
struct AnchorStatusMenuTests {
    private func menu(
        connection: ConnectionState = .disconnected,
        radio: MacBluetoothRadio = .on,
        pairing: DevicePairingStatus = .automatic,
        unsent: Int = 0,
        codex: Bool = true,
        claude: Bool = false
    ) -> AnchorStatusMenu {
        AnchorStatusMenu(
            projection: SessionProjection(connection: connection, unsentChanges: unsent),
            radio: radio, pairing: pairing, codexReady: codex, claudeReady: claude)
    }

    @Test("Connected wins even with Bluetooth off, since Wi-Fi can carry the link")
    func connectedOverWiFi() {
        let state = menu(connection: .connected, radio: .off)
        #expect(state.link == .connected(viaBluetooth: false))
        #expect(state.fix == nil)
        let bluetooth = menu(connection: .connected,
                             pairing: DevicePairingStatus(phase: .connected, route: .bluetooth))
        #expect(bluetooth.link == .connected(viaBluetooth: true))
    }

    @Test("Each way of being apart offers the one fix that moves it forward")
    func oneFixPerState() {
        #expect(menu(radio: .notAllowed).fix == .openBluetoothPrivacy)
        #expect(menu(radio: .off).fix == .openBluetoothSettings)
        #expect(menu(pairing: .verificationCodeRequired).link == .notPaired)
        #expect(menu(pairing: .verificationCodeRequired).fix == nil)
        #expect(menu(connection: .failed).fix == .reconnect)
        #expect(menu().link == .searching)
        #expect(menu().fix == .reconnect)
    }
}
