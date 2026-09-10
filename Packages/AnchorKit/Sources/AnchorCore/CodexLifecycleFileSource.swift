import Foundation

private actor CodexLifecycleDeliveryState {
    enum Resolution: Sendable {
        case acknowledged
        case retry
    }

    struct Pending: Sendable {
        let identity: CodexLifecycleFileIdentity
        let scannerCheckpoint: Data
    }

    private var pendingByEventID: [UUID: Pending] = [:]
    private var resolutionByEventID: [UUID: Resolution] = [:]

    func prepare(
        eventID: UUID,
        identity: CodexLifecycleFileIdentity,
        scannerCheckpoint: Data
    ) {
        pendingByEventID[eventID] = Pending(
            identity: identity,
            scannerCheckpoint: scannerCheckpoint
        )
        resolutionByEventID[eventID] = nil
    }

    func pending(eventID: UUID) -> Pending? {
        pendingByEventID[eventID]
    }

    func resolve(eventID: UUID, as resolution: Resolution) {
        guard pendingByEventID[eventID] != nil else { return }
        resolutionByEventID[eventID] = resolution
    }

    func takeResolution(eventID: UUID) -> Resolution? {
        guard let resolution = resolutionByEventID.removeValue(forKey: eventID) else {
            return nil
        }
        pendingByEventID[eventID] = nil
        return resolution
    }
}

/// Read-only Codex lifecycle source. It observes JSONL growth and emits only
/// sanitized lifecycle events; the source never forwards message bodies.
public struct CodexLifecycleFileSource: ProcessSource, Sendable {
    public static let defaultSourceID = UUID(
        uuidString: "00000000-0000-4000-8000-000000000404"
    )!

    public let fileURL: URL
    public let pollInterval: TimeInterval
    public let maximumReadBytes: Int
    public let descriptor: SourceDescriptor
    private let checkpointStore: CodexLifecycleCheckpointStore?
    private let sessionContextProvider: @Sendable () async -> ProcessSourceSessionContext?
    private let deliveryState = CodexLifecycleDeliveryState()

    public init(fileURL: URL, pollInterval: TimeInterval = 0.25,
                maximumReadBytes: Int = 4 * 1_024 * 1_024,
                sessionContextProvider: @escaping @Sendable () async -> ProcessSourceSessionContext?,
                checkpointStore: CodexLifecycleCheckpointStore? = nil,
                descriptor: SourceDescriptor = SourceDescriptor(
                    id: CodexLifecycleFileSource.defaultSourceID, name: "Codex", kind: .integration,
                    symbol: "C", tone: "cyan", capabilities: [.observe])) {
        self.fileURL = fileURL; self.pollInterval = max(0.05, pollInterval)
        self.maximumReadBytes = max(1, maximumReadBytes)
        self.sessionContextProvider = sessionContextProvider; self.checkpointStore = checkpointStore; self.descriptor = descriptor
    }

    static func checkpointKey(for sourceID: UUID) -> String {
        "codex.lifecycle." + sourceID.uuidString.lowercased()
    }

    public func events() -> AsyncThrowingStream<ExternalProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var scanner = CodexIncrementalScanner()
                var offset: UInt64 = 0
                var identity: CodexLifecycleFileIdentity?
                // The checkpoint key must not persist the user's session path.
                let sourceKey = Self.checkpointKey(for: descriptor.id)
                do {
                    if let store = checkpointStore,
                       let checkpoint = try await store.load(for: sourceKey),
                       let currentIdentity = try fileIdentity(for: fileURL),
                       checkpoint.identity == currentIdentity {
                        scanner = try CodexIncrementalScanner(checkpoint: checkpoint.scannerCheckpoint)
                        offset = scanner.offset
                        identity = currentIdentity
                    }
                    while !Task.isCancelled {
                        let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
                        let size = (attributes?[.size] as? NSNumber)?.uint64Value ?? 0
                        let currentIdentity = attributes.flatMap(Self.fileIdentity)
                        if currentIdentity != identity {
                            scanner.reset()
                            offset = 0
                            identity = currentIdentity
                            if let store = checkpointStore {
                                try await store.remove(for: sourceKey)
                            }
                        } else if size < offset {
                            scanner.reset()
                            offset = 0
                            if let store = checkpointStore {
                                try await store.remove(for: sourceKey)
                            }
                        }
                        if size > offset,
                           let context = await sessionContextProvider(),
                           let handle = try? FileHandle(forReadingFrom: fileURL) {
                            try handle.seek(toOffset: offset)
                            let remainingBytes = size - offset
                            let readCount = Int(
                                min(UInt64(maximumReadBytes), remainingBytes)
                            )
                            let bytes = try handle.read(upToCount: readCount) ?? Data()
                            try handle.close()
                            offset += UInt64(bytes.count)
                            let scannedRecords = scanner.appendWithOffsets(bytes)
                            for scanned in scannedRecords {
                                if scanned.record.timestamp < context.startedAt {
                                    if let store = checkpointStore, let identity {
                                        try await store.save(
                                            CodexLifecycleCheckpoint(
                                                identity: identity,
                                                scannerCheckpoint: try scanner.checkpoint(
                                                    committedThrough: scanned.committedOffset
                                                )
                                            ),
                                            for: sourceKey
                                        )
                                    }
                                    continue
                                }

                                let event = scanned.record.externalEvent(
                                    sessionID: context.sessionID,
                                    sourceID: descriptor.id
                                )
                                if let identity, checkpointStore != nil {
                                    await deliveryState.prepare(
                                        eventID: event.id,
                                        identity: identity,
                                        scannerCheckpoint: try scanner.checkpoint(
                                            committedThrough: scanned.committedOffset
                                        )
                                    )
                                }
                                continuation.yield(event)

                                if checkpointStore != nil {
                                    switch try await waitForResolution(of: event.id) {
                                    case .acknowledged:
                                        break
                                    case .retry:
                                        throw CancellationError()
                                    }
                                }
                            }
                            if let store = checkpointStore, let identity {
                                try await store.save(
                                    CodexLifecycleCheckpoint(
                                        identity: identity,
                                        scannerCheckpoint: try scanner.checkpoint()
                                    ),
                                    for: sourceKey
                                )
                            }
                        }
                        try await Task.sleep(for: .seconds(pollInterval))
                    }
                    continuation.finish()
                } catch is CancellationError { continuation.finish() }
                catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func acknowledge(_ event: ExternalProcessEvent) async throws {
        guard let checkpointStore,
              let pending = await deliveryState.pending(eventID: event.id) else { return }
        try await checkpointStore.save(
            CodexLifecycleCheckpoint(
                identity: pending.identity,
                scannerCheckpoint: pending.scannerCheckpoint
            ),
            for: Self.checkpointKey(for: descriptor.id)
        )
        await deliveryState.resolve(eventID: event.id, as: .acknowledged)
    }

    public func retry(_ event: ExternalProcessEvent) async throws {
        await deliveryState.resolve(eventID: event.id, as: .retry)
    }

    private func waitForResolution(
        of eventID: UUID
    ) async throws -> CodexLifecycleDeliveryState.Resolution {
        while !Task.isCancelled {
            if let resolution = await deliveryState.takeResolution(eventID: eventID) {
                return resolution
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw CancellationError()
    }

    private static func fileIdentity(_ attributes: [FileAttributeKey: Any]) -> CodexLifecycleFileIdentity? {
        guard attributes[.size] != nil else { return nil }
        return CodexLifecycleFileIdentity(
            fileNumber: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value,
            creationDate: attributes[.creationDate] as? Date
        )
    }

    private func fileIdentity(for url: URL) throws -> CodexLifecycleFileIdentity? {
        Self.fileIdentity(try FileManager.default.attributesOfItem(atPath: url.path))
    }
}
