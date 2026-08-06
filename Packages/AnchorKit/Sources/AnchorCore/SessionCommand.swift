import Foundation

public enum SessionCommand: Sendable {
    case createSession(goal: AnchorGoal, processes: [AnchorProcess])
    case updateGoal(title: String, completionCriteria: String, note: String)
    case addNote(String)
    case resolveDecision(decisionID: UUID, optionID: UUID)
    case addProcess(AnchorProcess)
    case updateProcess(AnchorProcess)
    case removeProcess(UUID)
    case reorderProcesses([UUID])
    case updateTileSize(processID: UUID, size: ProcessTileSize)
    case recordEvent(ProcessEvent)
    case applyEnvelope(EventEnvelope, event: ProcessEvent)
    case mergeRemoteSession(EventEnvelope, session: AnchorSession)
    case updatePresence(PresenceStatus, at: Date)
    case updateSignals(connection: ConnectionState, proximity: ProximityState, at: Date)
    case acknowledgeReturn
    case completeSession
    case resumeSession
    case clearError
}

public protocol LocalLinkControlling: Sendable {
    func currentPairingCode() async -> String?
    func pair(using code: String) async throws
    func retryConnection() async
}

public enum SessionRepositoryError: LocalizedError, Sendable {
    case noActiveSession
    case processNotFound
    case decisionNotFound
    case invalidDecisionOption

    public var errorDescription: String? {
        switch self {
        case .noActiveSession:
            String(
                localized: "error.session.none",
                defaultValue: "No active Anchor session.",
                bundle: .module
            )
        case .processNotFound:
            String(
                localized: "error.process.missing",
                defaultValue: "The selected process no longer exists.",
                bundle: .module
            )
        case .decisionNotFound:
            String(
                localized: "error.decision.missing",
                defaultValue: "The decision no longer exists.",
                bundle: .module
            )
        case .invalidDecisionOption:
            String(
                localized: "error.decision.option.invalid",
                defaultValue: "The selected option is unavailable.",
                bundle: .module
            )
        }
    }
}
