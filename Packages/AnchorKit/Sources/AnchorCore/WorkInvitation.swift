import Foundation

/// When the iPhone invites the person to turn it into the landscape work desk.
///
/// The invitation appears only at the workstation: an anchor is down, the Mac
/// is connected and the person is at their desk, with the phone in portrait.
/// It is offered once per desk session; turning to landscape accepts it, and
/// letting it fade declines it. A new anchor after none, or coming back from
/// being away, starts a new desk session. Brief connection drops do not, so a
/// flickering link never re-invites.
public struct WorkInvitation: Equatable, Sendable {
    public enum Event: Equatable, Sendable {
        /// Show the hanging anchor and its gentle current.
        case offered
        /// Portrait to landscape with work anchored: the anchor sets (haptic).
        case arrived
        /// Landscape to portrait with work anchored: the anchor is weighed.
        case weighed
    }

    public private(set) var isOffered = false
    private var settledThisSession = false
    private var posture = DevicePosture.unknown

    public init() {}

    public mutating func update(
        hasAnchor: Bool,
        macConnected: Bool,
        atDesk: Bool,
        posture newPosture: DevicePosture
    ) -> Event? {
        let previous = posture
        posture = newPosture
        // Lifting the last anchor ends the desk session.
        if !hasAnchor { settledThisSession = false }

        var event: Event?
        if previous == .portrait, newPosture == .landscape, hasAnchor {
            settledThisSession = true
            event = .arrived
        } else if previous == .landscape, newPosture == .portrait, hasAnchor {
            event = .weighed
        }

        let atWorkstation = hasAnchor && macConnected && atDesk && newPosture == .portrait
        if isOffered, !atWorkstation {
            isOffered = false
        } else if !isOffered, atWorkstation, !settledThisSession, event == nil {
            isOffered = true
            event = .offered
        }
        return event
    }

    /// The invitation faded without a turn; stay quiet for this desk session.
    public mutating func expire() {
        isOffered = false
        settledThisSession = true
    }

    /// Coming back to the desk after being away starts a new desk session.
    public mutating func beginDeskSession() {
        settledThisSession = false
    }
}
