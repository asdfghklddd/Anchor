import Foundation

/// The kind of external producer that supplied a process observation.
public enum ProcessSourceKind: String, Codable, CaseIterable, Sendable {
    case manual
    case simulated
    case cli
    case integration
}

public enum SourceCapability: String, Codable, CaseIterable, Sendable {
    case observe
    case open
    case resolveDecision
}

public enum SourcePermissionState: String, Codable, CaseIterable, Sendable {
    case notRequired
    case requested
    case granted
    case denied
    case restricted
}

public enum SourceHealthStatus: String, Codable, CaseIterable, Sendable {
    case idle
    case waitingForSession
    case running
    case stopped
    case failed
    case permissionDenied
}

public struct SourceDescriptor: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let kind: ProcessSourceKind
    public let symbol: String
    public let tone: String
    public let capabilities: Set<SourceCapability>
    public let permission: SourcePermissionState

    public init(
        id: UUID,
        name: String,
        kind: ProcessSourceKind,
        symbol: String,
        tone: String,
        capabilities: Set<SourceCapability> = [.observe],
        permission: SourcePermissionState = .notRequired
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.symbol = symbol
        self.tone = tone
        self.capabilities = capabilities
        self.permission = permission
    }
}

public struct SourceHealth: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let descriptor: SourceDescriptor
    public var status: SourceHealthStatus
    public var lastAttemptAt: Date?
    public var lastEventAt: Date?
    public var eventCount: Int
    public var consecutiveFailures: Int
    public var lastError: String?

    public init(
        descriptor: SourceDescriptor,
        status: SourceHealthStatus = .idle,
        lastAttemptAt: Date? = nil,
        lastEventAt: Date? = nil,
        eventCount: Int = 0,
        consecutiveFailures: Int = 0,
        lastError: String? = nil
    ) {
        id = descriptor.id
        self.descriptor = descriptor
        self.status = status
        self.lastAttemptAt = lastAttemptAt
        self.lastEventAt = lastEventAt
        self.eventCount = eventCount
        self.consecutiveFailures = consecutiveFailures
        self.lastError = lastError
    }
}

public enum SourceAction: Codable, Hashable, Sendable {
    case open(URL)
    case resolveDecision(decisionID: UUID, optionID: UUID)
}

public struct SourceActionReceipt: Codable, Hashable, Sendable {
    public let id: UUID
    public let sourceID: UUID
    public let action: SourceAction
    public let performedAt: Date
    public let deepLink: URL?

    public init(
        id: UUID = UUID(),
        sourceID: UUID,
        action: SourceAction,
        performedAt: Date = .now,
        deepLink: URL? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.action = action
        self.performedAt = performedAt
        self.deepLink = deepLink
    }
}

/// A normalized observation emitted by a source adapter. The adapter owns
/// source-specific parsing; Anchor only accepts this small, privacy-conscious
/// value type and never needs raw prompts, documents, or model output.
public struct ExternalProcessEvent: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let sourceID: UUID
    public let sequence: UInt64
    public let occurredAt: Date
    public let process: AnchorProcess
    public let event: ProcessEvent?
    public let decision: Decision?
    public let deduplicationKey: String?

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        sourceID: UUID,
        sequence: UInt64,
        occurredAt: Date = .now,
        process: AnchorProcess,
        event: ProcessEvent? = nil,
        decision: Decision? = nil,
        deduplicationKey: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.sourceID = sourceID
        self.sequence = sequence
        self.occurredAt = occurredAt
        self.process = process
        self.event = event
        self.decision = decision
        self.deduplicationKey = deduplicationKey
    }

    /// Converts an external observation into the operation consumed by the
    /// event-backed repository, while validating the source/session boundary.
    public func observation(receivedAt: Date = .now) throws -> ProcessObservation {
        guard process.sessionID == nil || process.sessionID == sessionID else {
            throw ProcessSourceError.sessionMismatch
        }
        guard process.sourceID == nil || process.sourceID == sourceID else {
            throw ProcessSourceError.sourceMismatch
        }
        if let progress = process.progress, !(0 ... 1).contains(progress) {
            throw ProcessSourceError.invalidProgress
        }
        if let decision, decision.processID != process.id {
            throw ProcessSourceError.decisionProcessMismatch
        }

        var normalizedProcess = process
        normalizedProcess.sessionID = sessionID
        normalizedProcess.sourceID = sourceID

        let normalizedEvent: ProcessEvent?
        if let event {
            guard event.sessionID == nil || event.sessionID == sessionID else {
                throw ProcessSourceError.sessionMismatch
            }
            guard event.sourceID == nil || event.sourceID == sourceID else {
                throw ProcessSourceError.sourceMismatch
            }
            guard event.processID == nil || event.processID == process.id else {
                throw ProcessSourceError.eventProcessMismatch
            }
            if let progress = event.progress, !(0 ... 1).contains(progress) {
                throw ProcessSourceError.invalidProgress
            }
            normalizedEvent = ProcessEvent(
                id: event.id,
                sessionID: sessionID,
                processID: process.id,
                sourceID: sourceID,
                externalID: event.externalID,
                deduplicationKey: event.deduplicationKey,
                occurredAt: event.occurredAt,
                receivedAt: event.receivedAt ?? receivedAt,
                kind: event.kind,
                title: event.title,
                detail: event.detail,
                progress: event.progress,
                metric: event.metric,
                metricLabel: event.metricLabel,
                deepLink: event.deepLink
            )
        } else {
            normalizedEvent = nil
        }

        return ProcessObservation(
            process: normalizedProcess,
            event: normalizedEvent,
            decision: decision,
            deduplicationKey: deduplicationKey
        )
    }
}

public enum ProcessSourceError: LocalizedError, Codable, Hashable, Sendable {
    case sessionMismatch
    case sourceMismatch
    case eventProcessMismatch
    case decisionProcessMismatch
    case invalidProgress
    case unsupportedAction

    public var errorDescription: String? {
        switch self {
        case .sessionMismatch:
            "The source event belongs to another Anchor session."
        case .sourceMismatch:
            "The source event does not match its declared source."
        case .eventProcessMismatch:
            "The process event references another process."
        case .decisionProcessMismatch:
            "The decision references another process."
        case .invalidProgress:
            "Process progress must be between 0 and 1."
        case .unsupportedAction:
            "This source does not support that action."
        }
    }
}

public protocol ProcessSource: Sendable {
    var descriptor: SourceDescriptor { get }
    func events() -> AsyncThrowingStream<ExternalProcessEvent, Error>
    func perform(_ action: SourceAction) async throws -> SourceActionReceipt
    func retry(_ event: ExternalProcessEvent) async throws
}

public protocol SourceHealthProviding: Sendable {
    func healthChanges() async -> AsyncStream<[SourceHealth]>
}

/// A narrow command boundary used by the Mac companion when a decision is
/// resolved on either device. The source adapter remains responsible for
/// translating the normalized action into its own API or deep link.
public protocol SourceActionPerforming: Sendable {
    func perform(_ action: SourceAction, on sourceID: UUID) async throws -> SourceActionReceipt
}

public extension ProcessSource {
    func perform(_ action: SourceAction) async throws -> SourceActionReceipt {
        throw ProcessSourceError.unsupportedAction
    }

    func retry(_ event: ExternalProcessEvent) async throws {
        _ = event
    }
}
