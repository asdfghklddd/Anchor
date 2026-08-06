import Foundation

/// A durable remote event store. CloudKit is one implementation; a fake store
/// can exercise the same retry and merge behavior without network access.
public protocol DurableEventStore: Sendable {
    func save(_ envelope: EventEnvelope) async throws
    func events(for sessionID: UUID, onOrAfter date: Date?) async throws -> [EventEnvelope]
}

public struct DurableSyncReport: Codable, Hashable, Sendable {
    public let uploadedCount: Int
    public let downloadedCount: Int
    public let completedAt: Date
    public let watermark: Date?

    public init(
        uploadedCount: Int,
        downloadedCount: Int,
        completedAt: Date = .now,
        watermark: Date?
    ) {
        self.uploadedCount = uploadedCount
        self.downloadedCount = downloadedCount
        self.completedAt = completedAt
        self.watermark = watermark
    }
}

public protocol DurableSyncStatusProviding: Sendable {
    func statusChanges() async -> AsyncStream<DurableSyncState>
}

/// Coordinates one local event-backed repository with a durable remote store.
/// Uploads are acknowledged only after the remote store accepts an event; a
/// failed upload therefore remains in the local outbox for the next attempt.
public actor DurableEventSynchronizer {
    private let local: any EventBackedSessionRepository
    private let remote: any DurableEventStore
    private var watermark: Date?

    public init(
        local: any EventBackedSessionRepository,
        remote: any DurableEventStore,
        initialWatermark: Date? = nil
    ) {
        self.local = local
        self.remote = remote
        watermark = initialWatermark
    }

    public func sync() async throws -> DurableSyncReport {
        guard let sessionID = await local.currentProjection().session?.id else {
            return DurableSyncReport(
                uploadedCount: 0,
                downloadedCount: 0,
                watermark: watermark
            )
        }

        var uploaded = 0
        for event in await local.pendingEvents() {
            try Task.checkCancellation()
            try await remote.save(event)
            try await local.markDelivered(event.id)
            uploaded += 1
        }

        let remoteEvents = try await remote.events(
            for: sessionID,
            onOrAfter: watermark
        )
        var downloaded = 0
        for event in remoteEvents.sorted(by: Self.eventSort) {
            try Task.checkCancellation()
            try await local.applyRemote(event)
            watermark = max(watermark ?? event.timestamp, event.timestamp)
            downloaded += 1
        }

        return DurableSyncReport(
            uploadedCount: uploaded,
            downloadedCount: downloaded,
            watermark: watermark
        )
    }

    public func currentWatermark() -> Date? { watermark }

    private static func eventSort(_ lhs: EventEnvelope, _ rhs: EventEnvelope) -> Bool {
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        if lhs.sourceID != rhs.sourceID {
            return lhs.sourceID.uuidString < rhs.sourceID.uuidString
        }
        if lhs.sequence != rhs.sequence { return lhs.sequence < rhs.sequence }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

/// Runs foreground durable sync on a bounded cadence and exposes an honest
/// status stream to the presentation model. CloudKit background delivery can
/// be added around this same synchronizer once the app's remote-notification
/// entitlement is configured.
public actor DurableSyncRunner: DurableSyncStatusProviding {
    private let synchronizer: DurableEventSynchronizer
    private let interval: TimeInterval
    private var task: Task<Void, Never>?
    private var state: DurableSyncState = .idle
    private var continuations: [UUID: AsyncStream<DurableSyncState>.Continuation] = [:]

    public init(
        synchronizer: DurableEventSynchronizer,
        interval: TimeInterval = 60
    ) {
        self.synchronizer = synchronizer
        self.interval = max(5, interval)
    }

    public func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            guard let self else { return }
            _ = await self.syncNow()
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(self.interval))
                } catch {
                    return
                }
                guard !Task.isCancelled else { return }
                _ = await self.syncNow()
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        setState(.idle)
    }

    @discardableResult
    public func syncNow() async -> DurableSyncReport? {
        setState(.syncing)
        do {
            let report = try await synchronizer.sync()
            setState(.available)
            return report
        } catch is CancellationError {
            setState(.offline)
            return nil
        } catch {
            setState(.failed)
            return nil
        }
    }

    public func currentState() -> DurableSyncState { state }

    public func statusChanges() -> AsyncStream<DurableSyncState> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.yield(state)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id) }
            }
        }
    }

    private func setState(_ next: DurableSyncState) {
        state = next
        for continuation in continuations.values {
            continuation.yield(next)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
