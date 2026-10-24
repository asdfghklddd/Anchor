import AnchorCore
import SwiftUI

/// One paired device, as the system Bluetooth list shows it: what it is,
/// its name, and whether it is connected right now.
public struct PeerDeviceRow: View {
    private let info: PeerDeviceInfo
    private let route: DevicePairingRoute?
    private let isConnected: Bool

    public init(info: PeerDeviceInfo, route: DevicePairingRoute?, isConnected: Bool) {
        self.info = info
        self.route = route
        self.isConnected = isConnected
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: info.symbolName)
                .font(.title2)
                .foregroundStyle(isConnected ? AnchorPalette.interaction : AnchorPalette.secondaryInk)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AnchorPalette.ink)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .lineLimit(1)
            }
            .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Text(isConnected ? PeerDeviceCopy.connected : PeerDeviceCopy.notConnected)
                .font(.subheadline)
                .foregroundStyle(isConnected ? AnchorPalette.mintInk : AnchorPalette.secondaryInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("pairing.peer-device")
    }

    private var detail: String {
        guard isConnected, let route else { return info.detail }
        return [info.detail, PeerDeviceCopy.route(route)].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

public enum PeerDeviceCopy {
    public static let connected = AnchorStrings.value("pair.device.connected", default: "Connected")
    public static let notConnected = AnchorStrings.value("pair.device.not-connected", default: "Not Connected")

    public static func route(_ route: DevicePairingRoute) -> String {
        switch route {
        case .bluetooth: AnchorStrings.value("pair.device.route.bluetooth", default: "Bluetooth")
        case .iCloud: AnchorStrings.value("pair.device.route.icloud", default: "iCloud")
        case .trustedDevice, .verificationCode:
            AnchorStrings.value("pair.device.route.network", default: "Local Network")
        }
    }
}
