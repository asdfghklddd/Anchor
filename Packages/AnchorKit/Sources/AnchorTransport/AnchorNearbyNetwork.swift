import Foundation
import Network

/// Enables the same Bonjour/TCP protocol on both infrastructure Wi-Fi and
/// Apple's peer-to-peer Wi-Fi. Network.framework chooses the best available
/// interface, so callers do not need to manage a second connection state.
enum AnchorNearbyNetwork {
    static func tcpParameters() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        return parameters
    }
}
