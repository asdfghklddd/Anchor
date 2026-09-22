import Foundation
import Testing
@testable import AnchorCore

@Suite("Projection availability")
struct ProjectionAvailabilityTests {
    private let session = AnchorSession(
        goal: AnchorGoal(title: "Ship", completionCriteria: "Verified")
    )

    @Test("An empty workspace has no live or historical status")
    func emptyWorkspace() {
        let projection = SessionProjection(connection: .connected)

        #expect(projection.availability(at: .now) == .empty)
    }

    @Test("A recent authenticated observation is live")
    func recentConnectedObservation() {
        let observedAt = Date(timeIntervalSince1970: 1_000)
        let projection = SessionProjection(
            session: session,
            connection: .connected,
            dataObservedAt: observedAt
        )

        #expect(
            projection.availability(at: observedAt.addingTimeInterval(299))
                == .live(lastObservedAt: observedAt)
        )
    }

    @Test("A connected projection expires when no work data arrives")
    func connectedButExpired() {
        let observedAt = Date(timeIntervalSince1970: 1_000)
        let projection = SessionProjection(
            session: session,
            connection: .connected,
            dataObservedAt: observedAt
        )

        #expect(
            projection.availability(at: observedAt.addingTimeInterval(301))
                == .lastKnown(lastObservedAt: observedAt)
        )
    }

    @Test("Disconnect immediately changes a recent observation to last-known")
    func disconnectedObservation() {
        let observedAt = Date(timeIntervalSince1970: 1_000)
        let projection = SessionProjection(
            session: session,
            connection: .disconnected,
            dataObservedAt: observedAt
        )

        #expect(
            projection.availability(at: observedAt.addingTimeInterval(1))
                == .lastKnown(lastObservedAt: observedAt)
        )
    }

    @Test("Pairing is syncing instead of live")
    func pairingProjection() {
        let observedAt = Date(timeIntervalSince1970: 1_000)
        let projection = SessionProjection(
            session: session,
            connection: .pairing,
            dataObservedAt: observedAt
        )

        #expect(
            projection.availability(at: observedAt)
                == .syncing(lastObservedAt: observedAt)
        )
    }

    @Test("Missing observation time never becomes live")
    func missingObservationTime() {
        let projection = SessionProjection(
            session: session,
            connection: .connected,
            dataObservedAt: nil
        )

        #expect(
            projection.availability(at: .now)
                == .lastKnown(lastObservedAt: nil)
        )
    }

    @Test("An old task requires review until the user explicitly continues")
    func recoveryReviewAcknowledgement() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let reviewedAt = startedAt.addingTimeInterval(90_000)
        let projection = SessionProjection(
            session: AnchorSession(
                goal: AnchorGoal(title: "Long task", completionCriteria: "Reviewed"),
                startedAt: startedAt
            )
        )

        #expect(!projection.needsRecoveryReview(at: startedAt.addingTimeInterval(86_399)))
        #expect(projection.needsRecoveryReview(at: reviewedAt))

        let continued = try SessionReducer.reduce(
            projection,
            command: .resumeSession,
            now: reviewedAt
        )

        #expect(continued.session?.lastContinuedAt == reviewedAt)
        #expect(!continued.needsRecoveryReview(at: reviewedAt.addingTimeInterval(60)))
    }
}
