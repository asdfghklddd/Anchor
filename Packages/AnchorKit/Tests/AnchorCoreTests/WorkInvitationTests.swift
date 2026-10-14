import Testing
@testable import AnchorCore

@Suite("Work invitation")
struct WorkInvitationTests {
    @Test("Invites only with an anchor down and the Mac connected, in portrait")
    func conditions() {
        var invitation = WorkInvitation()
        #expect(invitation.update(hasAnchor: false, macConnected: true, atDesk: true, posture: .portrait) == nil)
        #expect(invitation.update(hasAnchor: true, macConnected: false, atDesk: true, posture: .portrait) == nil)
        #expect(!invitation.isOffered)
        #expect(invitation.update(hasAnchor: true, macConnected: true, atDesk: true, posture: .portrait) == .offered)
        #expect(invitation.isOffered)
        // Already offered: further updates do not re-announce it.
        #expect(invitation.update(hasAnchor: true, macConnected: true, atDesk: true, posture: .portrait) == nil)
    }

    @Test("Turning to landscape accepts; turning back weighs anchor without re-inviting")
    func acceptAndWeigh() {
        var invitation = WorkInvitation()
        _ = invitation.update(hasAnchor: true, macConnected: true, atDesk: true, posture: .portrait)
        #expect(invitation.update(hasAnchor: true, macConnected: true, atDesk: true, posture: .landscape) == .arrived)
        #expect(!invitation.isOffered)
        #expect(invitation.update(hasAnchor: true, macConnected: true, atDesk: true, posture: .portrait) == .weighed)
        #expect(!invitation.isOffered)
    }

    @Test("A faded invitation stays quiet, even when the link flickers")
    func expireAndFlicker() {
        var invitation = WorkInvitation()
        _ = invitation.update(hasAnchor: true, macConnected: true, atDesk: true, posture: .portrait)
        invitation.expire()
        #expect(invitation.update(hasAnchor: true, macConnected: false, atDesk: true, posture: .portrait) == nil)
        #expect(invitation.update(hasAnchor: true, macConnected: true, atDesk: true, posture: .portrait) == nil)
        #expect(!invitation.isOffered)
    }

    @Test("Coming back from away, or a new anchor after none, invites again")
    func newDeskSession() {
        var invitation = WorkInvitation()
        _ = invitation.update(hasAnchor: true, macConnected: true, atDesk: true, posture: .portrait)
        invitation.expire()
        invitation.beginDeskSession()
        #expect(invitation.update(hasAnchor: true, macConnected: true, atDesk: true, posture: .portrait) == .offered)

        invitation.expire()
        _ = invitation.update(hasAnchor: false, macConnected: true, atDesk: true, posture: .portrait)
        #expect(invitation.update(hasAnchor: true, macConnected: true, atDesk: true, posture: .portrait) == .offered)
    }

    @Test("Leaving the desk or rotating withdraws an open invitation")
    func withdraw() {
        var invitation = WorkInvitation()
        _ = invitation.update(hasAnchor: true, macConnected: true, atDesk: true, posture: .portrait)
        _ = invitation.update(hasAnchor: true, macConnected: true, atDesk: false, posture: .portrait)
        #expect(!invitation.isOffered)
    }

    @Test("Landscape without an anchor is not an arrival")
    func noAnchorNoArrival() {
        var invitation = WorkInvitation()
        _ = invitation.update(hasAnchor: false, macConnected: true, atDesk: true, posture: .portrait)
        #expect(invitation.update(hasAnchor: false, macConnected: true, atDesk: true, posture: .landscape) == nil)
    }
}
