import Foundation

public enum CLICommandPhase: String, Codable, CaseIterable, Sendable {
    case started
    case finished
}

/// A session-independent command lifecycle signal written by shell integration.
/// It stores no command arguments and reduces working directories to a basename.
public struct CLIProcessSignal: Identifiable, Codable, Hashable, Sendable {
    public static let schemaIdentifier = "anchor.cli.command.v1"
    private static let maximumDisplayLength = 120

    public let id: UUID
    public let schema: String
    public let commandID: UUID
    public let phase: CLICommandPhase
    public let occurredAt: Date
    public let executableName: String
    public let workspaceName: String?
    public let terminalName: String?
    public let exitCode: Int?

    public init(
        id: UUID = UUID(),
        commandID: UUID,
        phase: CLICommandPhase,
        occurredAt: Date = .now,
        executableName: String,
        workspaceName: String? = nil,
        terminalName: String? = nil,
        exitCode: Int? = nil
    ) {
        self.id = id
        schema = Self.schemaIdentifier
        self.commandID = commandID
        self.phase = phase
        self.occurredAt = occurredAt
        self.executableName = Self.executableBasename(executableName)
        self.workspaceName = Self.optionalBasename(workspaceName)
        self.terminalName = Self.optionalTrimmed(terminalName)
        self.exitCode = exitCode
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        schema = try values.decode(String.self, forKey: .schema)
        commandID = try values.decode(UUID.self, forKey: .commandID)
        phase = try values.decode(CLICommandPhase.self, forKey: .phase)
        occurredAt = try values.decode(Date.self, forKey: .occurredAt)
        executableName = Self.executableBasename(
            try values.decode(String.self, forKey: .executableName)
        )
        workspaceName = Self.optionalBasename(
            try values.decodeIfPresent(String.self, forKey: .workspaceName)
        )
        terminalName = Self.optionalTrimmed(
            try values.decodeIfPresent(String.self, forKey: .terminalName)
        )
        exitCode = try values.decodeIfPresent(Int.self, forKey: .exitCode)
    }

    public func externalEvent(sessionID: UUID, sourceID: UUID) throws -> ExternalProcessEvent {
        guard schema == Self.schemaIdentifier else {
            throw CLIProcessSignalError.unsupportedSchema(schema)
        }
        guard phase == .started || exitCode != nil else {
            throw CLIProcessSignalError.missingExitCode
        }

        let processID = StableProcessIdentity.id(
            namespace: "cli.command",
            sessionID: sessionID,
            externalID: commandID.uuidString
        )
        let status: ProcessStatus
        let eventKind: ProcessEventKind
        let progress: Double?
        let metric: String
        let metricLabel: String
        let detail: String
        let eventTitle: String

        switch phase {
        case .started:
            status = .running
            eventKind = .created
            progress = nil
            metric = CLIProcessStrings.running
            metricLabel = CLIProcessStrings.commandState
            detail = CLIProcessStrings.runningDetail(
                executableName,
                workspaceName: workspaceName
            )
            eventTitle = CLIProcessStrings.started(executableName)
        case .finished:
            let exitCode = exitCode ?? -1
            let succeeded = exitCode == 0
            status = succeeded ? .completed : .failed
            eventKind = succeeded ? .completed : .failed
            progress = succeeded ? 1 : nil
            metric = String(exitCode)
            metricLabel = CLIProcessStrings.exitCode
            detail = succeeded
                ? CLIProcessStrings.completedDetail(executableName)
                : CLIProcessStrings.failedDetail(executableName, exitCode: exitCode)
            eventTitle = succeeded
                ? CLIProcessStrings.completed(executableName)
                : CLIProcessStrings.failed(executableName)
        }

        let sourceName = terminalName ?? CLIProcessStrings.terminal
        let symbol = sourceName.first.map { String($0).uppercased() } ?? "$"
        let event = ProcessEvent(
            sessionID: sessionID,
            processID: processID,
            sourceID: sourceID,
            externalID: commandID.uuidString,
            occurredAt: occurredAt,
            kind: eventKind,
            title: eventTitle,
            detail: detail,
            progress: progress,
            metric: metric,
            metricLabel: metricLabel
        )

        return ExternalProcessEvent(
            id: id,
            sessionID: sessionID,
            sourceID: sourceID,
            sequence: Self.sequence(for: occurredAt),
            occurredAt: occurredAt,
            process: AnchorProcess(
                id: processID,
                sessionID: sessionID,
                sourceID: sourceID,
                externalID: commandID.uuidString,
                sourceName: sourceName,
                sourceSymbol: symbol,
                sourceTone: "cyan",
                title: executableName,
                status: status,
                progress: progress,
                metric: metric,
                metricLabel: metricLabel,
                detail: detail,
                updatedAt: occurredAt
            ),
            event: event
        )
    }

    private static func executableBasename(_ value: String) -> String {
        let command = value.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
        let basename = URL(filePath: command).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return basename.isEmpty ? "Command" : limited(basename)
    }

    private static func optionalBasename(_ value: String?) -> String? {
        guard let trimmed = optionalTrimmed(value) else { return nil }
        let basename = URL(filePath: trimmed).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return basename.isEmpty ? nil : limited(basename)
    }

    private static func optionalTrimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : limited(trimmed)
    }

    private static func limited(_ value: String) -> String {
        String(value.prefix(maximumDisplayLength))
    }

    private static func sequence(for date: Date) -> UInt64 {
        UInt64(max(0, date.timeIntervalSince1970 * 1_000))
    }
}

public enum CLIProcessSignalError: LocalizedError, Hashable, Sendable {
    case missingExitCode
    case unsupportedSchema(String)

    public var errorDescription: String? {
        switch self {
        case .missingExitCode:
            "A finished CLI command signal requires an exit code."
        case let .unsupportedSchema(schema):
            "Unsupported CLI command signal schema: \(schema)."
        }
    }
}

private enum CLIProcessStrings {
    static let terminal = value("cli.source.terminal", default: "Terminal")
    static let running = value("cli.state.running", default: "Running")
    static let commandState = value("cli.metric.command-state", default: "Command state")
    static let exitCode = value("cli.metric.exit-code", default: "Exit code")

    static func started(_ executable: String) -> String {
        format("cli.event.started", default: "%@ started", executable)
    }

    static func completed(_ executable: String) -> String {
        format("cli.event.completed", default: "%@ completed", executable)
    }

    static func failed(_ executable: String) -> String {
        format("cli.event.failed", default: "%@ failed", executable)
    }

    static func runningDetail(_ executable: String, workspaceName: String?) -> String {
        guard let workspaceName else {
            return format("cli.detail.running", default: "%@ is running.", executable)
        }
        return format(
            "cli.detail.running.workspace",
            default: "%@ is running in %@.",
            executable,
            workspaceName
        )
    }

    static func completedDetail(_ executable: String) -> String {
        format(
            "cli.detail.completed",
            default: "%@ finished successfully.",
            executable
        )
    }

    static func failedDetail(_ executable: String, exitCode: Int) -> String {
        let template = value(
            "cli.detail.failed",
            default: "%@ exited with code %lld."
        )
        return String.localizedStringWithFormat(template, executable, Int64(exitCode))
    }

    private static func format(
        _ key: String,
        default defaultValue: String,
        _ argument: String
    ) -> String {
        String.localizedStringWithFormat(value(key, default: defaultValue), argument)
    }

    private static func format(
        _ key: String,
        default defaultValue: String,
        _ firstArgument: String,
        _ secondArgument: String
    ) -> String {
        String.localizedStringWithFormat(
            value(key, default: defaultValue),
            firstArgument,
            secondArgument
        )
    }

    private static func value(_ key: String, default defaultValue: String) -> String {
        let localized = String(
            localized: String.LocalizationValue(key),
            bundle: .module
        )
        return localized == key ? defaultValue : localized
    }
}
