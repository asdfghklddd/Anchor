#if os(macOS)
import Foundation

/// Observes regular GUI applications using public NSWorkspace lifecycle
/// notifications, with a periodic snapshot to recover any missed signals.
public struct MacWorkspaceProcessSource: ProcessSource, Sendable {
    public static let defaultSourceID = UUID(
        uuidString: "00000000-0000-4000-8000-000000000403"
    ) ?? UUID()

    public let descriptor: SourceDescriptor

    private let sessionIDProvider: @Sendable () async -> UUID?
    private let snapshotProvider: @Sendable () async -> [MacApplicationSnapshot]
    private let signalProvider: @Sendable () async -> AsyncStream<Void>

    @MainActor
    public init(
        reconciliationInterval: TimeInterval = 10,
        excludedBundleIdentifiers: Set<String> = [
            "com.andywang.anchor",
            "com.andywang.anchor.demo",
        ],
        descriptor: SourceDescriptor? = nil,
        sessionIDProvider: @escaping @Sendable () async -> UUID?
    ) {
        let observer = SystemMacWorkspaceObserver(
            excludedBundleIdentifiers: excludedBundleIdentifiers
        )
        self.init(
            descriptor: descriptor ?? SourceDescriptor(
                id: Self.defaultSourceID,
                name: MacWorkspaceStrings.sourceName,
                kind: .integration,
                symbol: "M",
                tone: "cyan",
                capabilities: [.observe]
            ),
            sessionIDProvider: sessionIDProvider,
            snapshotProvider: { await observer.snapshot() },
            signalProvider: {
                await observer.changes(
                    reconciliationInterval: max(1, reconciliationInterval)
                )
            }
        )
    }

    init(
        descriptor: SourceDescriptor = SourceDescriptor(
            id: MacWorkspaceProcessSource.defaultSourceID,
            name: "Mac Applications",
            kind: .integration,
            symbol: "M",
            tone: "cyan",
            capabilities: [.observe]
        ),
        sessionIDProvider: @escaping @Sendable () async -> UUID?,
        snapshotProvider: @escaping @Sendable () async -> [MacApplicationSnapshot],
        signalProvider: @escaping @Sendable () async -> AsyncStream<Void>
    ) {
        self.descriptor = descriptor
        self.sessionIDProvider = sessionIDProvider
        self.snapshotProvider = snapshotProvider
        self.signalProvider = signalProvider
    }

    public func events() -> AsyncThrowingStream<ExternalProcessEvent, Error> {
        let sourceID = descriptor.id
        let sessionIDProvider = self.sessionIDProvider
        let snapshotProvider = self.snapshotProvider
        let signalProvider = self.signalProvider

        return AsyncThrowingStream { continuation in
            let task = Task {
                let reducer = MacWorkspaceObservationReducer(sourceID: sourceID)
                let signals = await signalProvider()

                for await _ in signals {
                    guard !Task.isCancelled else { break }
                    guard let sessionID = await sessionIDProvider() else { continue }

                    let snapshots = await snapshotProvider()
                    let events = await reducer.reconcile(
                        snapshots,
                        sessionID: sessionID,
                        observedAt: .now
                    )
                    for event in events {
                        continuation.yield(event)
                    }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
#endif
