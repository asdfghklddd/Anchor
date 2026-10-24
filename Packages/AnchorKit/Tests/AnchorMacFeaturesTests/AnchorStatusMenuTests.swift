import AnchorCore
import Foundation
import Testing
@testable import AnchorMacFeatures

@Suite("Menu bar item")
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
        #expect(state.icon == .connected)
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

    @Test("The icon dims while the phone is away and marks what needs the person")
    func icon() {
        #expect(menu().icon == .away)
        #expect(menu(radio: .off).icon == .needsAttention)
        #expect(menu(connection: .failed).icon == .needsAttention)
        #expect(menu(connection: .connected, codex: false, claude: false).icon == .needsAttention)
        #expect(menu(connection: .connected, codex: false, claude: true).icon == .connected)
    }

    @Test("Saved updates are counted for the line under the status")
    func unsent() {
        #expect(menu(unsent: 3).unsent == 3)
    }

    @Test("Settings starts on the menu bar icon and remembers the boat")
    func style() throws {
        let defaults = try #require(UserDefaults(suiteName: "anchor.status.style.\(UUID())"))
        #expect(MacInterfaceStyle.current(in: defaults) == .menuBar)
        defaults.set(MacInterfaceStyle.boat.rawValue, forKey: MacInterfaceStyle.defaultsKey)
        #expect(MacInterfaceStyle.current(in: defaults) == .boat)
    }
}
