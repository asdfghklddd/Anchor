import Foundation

/// A deterministic source for development and acceptance tests. It contains no
/// product fixtures; callers provide the sanitized event script explicitly.
public struct SimulatedProcessSource: ProcessSource, Sendable {
    public let descriptor: SourceDescriptor
    public let script: [ExternalProcessEvent]
    public let interval: TimeInterval

    public init(
        descriptor: SourceDescriptor = SourceDescriptor(
            id: UUID(uuidString: "00000000-0000-4000-8000-000000000402") ?? UUID(),
            name: "Simulated source",
            kind: .simulated,
            symbol: "S",
            tone: "periwinkle"
        ),
        script: [ExternalProcessEvent],
        interval: TimeInterval = 0
    ) {
        self.descriptor = descriptor
        self.script = script
        self.interval = max(0, interval)
    }

    public func events() -> AsyncThrowingStream<ExternalProcessEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for event in script {
                        try Task.checkCancellation()
                        if interval > 0 {
                            try await Task.sleep(for: .seconds(interval))
                        }
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
