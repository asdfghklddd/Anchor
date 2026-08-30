import Foundation

/// Consumes privacy-minimal browser-extension signals from a dedicated App
/// Group inbox. Keeping the directory separate prevents the CLI and browser
/// adapters from racing to consume each other's files.
public struct WebProcessSource: ProcessSource, Sendable {
    public static let defaultSourceID = UUID(
        uuidString: "00000000-0000-4000-8000-000000000402"
    ) ?? UUID()

    public let descriptor: SourceDescriptor
    private let fileSource: FileProcessSource

    public init(
        directoryURL: URL = FileProcessSource.defaultWebInboxURL(),
        pollInterval: TimeInterval = 0.25,
        maximumFileSize: Int = 1_048_576,
        sessionContextProvider: @escaping @Sendable () async -> ProcessSourceSessionContext? = { nil }
    ) {
        let descriptor = SourceDescriptor(
            id: Self.defaultSourceID,
            name: "Web Apps",
            kind: .integration,
            symbol: "W",
            tone: "periwinkle",
            capabilities: [.observe],
            permission: .requested
        )
        self.descriptor = descriptor
        fileSource = FileProcessSource(
            directoryURL: directoryURL,
            pollInterval: pollInterval,
            maximumFileSize: maximumFileSize,
            sessionContextProvider: sessionContextProvider,
            signalKind: .web,
            descriptor: descriptor
        )
    }

    public func events() -> AsyncThrowingStream<ExternalProcessEvent, Error> {
        fileSource.events()
    }

    public func retry(_ event: ExternalProcessEvent) async throws {
        try await fileSource.retry(event)
    }
}
