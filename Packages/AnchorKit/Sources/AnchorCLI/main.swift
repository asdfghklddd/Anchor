import AnchorCore
import Foundation

@main
struct AnchorCLI {
    static func main() async throws {
        var arguments = Array(CommandLine.arguments.dropFirst())
        let command = arguments.first ?? "help"
        if !arguments.isEmpty {
            arguments.removeFirst()
        }

        switch command {
        case "command":
            try commandLifecycle(arguments)
        case "emit":
            try emit(arguments)
        case "schema":
            try printSchema()
        case "shell":
            try printShellIntegration(arguments)
        case "help", "--help", "-h":
            printUsage()
        default:
            printUsage()
            throw CLIError.unknownCommand(command)
        }
    }

    private static func emit(_ arguments: [String]) throws {
        let options = try CLIOptions(arguments: arguments)
        let data: Data
        if let filePath = options.inputFile {
            data = try Data(contentsOf: URL(filePath: filePath))
        } else {
            data = FileHandle.standardInput.readDataToEndOfFile()
        }

        guard !data.isEmpty else {
            throw CLIError.missingInput
        }
        let event = try JSONDecoder.anchorExternal.decode(ExternalProcessEvent.self, from: data)
        let inbox = options.inboxURL ?? FileProcessSource.defaultInboxURL()
        let destination = try queue(
            try JSONEncoder.anchorExternal.encode(event),
            itemID: event.id,
            inbox: inbox
        )
        print("Queued Anchor event \(event.id.uuidString) at \(destination.path)")
    }

    private static func commandLifecycle(_ arguments: [String]) throws {
        guard let subcommand = arguments.first else {
            throw CLIError.unknownCommand("command")
        }
        let phase: CLICommandPhase
        switch subcommand {
        case "start":
            phase = .started
        case "finish":
            phase = .finished
        default:
            throw CLIError.unknownCommand(arguments.first.map { "command \($0)" } ?? "command")
        }
        let options = try CommandLifecycleOptions(
            phase: phase,
            arguments: Array(arguments.dropFirst())
        )
        let commandID = try options.resolvedCommandID()
        let signal = CLIProcessSignal(
            commandID: commandID,
            phase: phase,
            executableName: options.executableName,
            workspaceName: options.workspaceName,
            terminalName: options.terminalName,
            exitCode: options.exitCode
        )
        let inbox = options.inboxURL ?? FileProcessSource.defaultInboxURL()
        let phaseOrder = phase == .started ? "0" : "1"
        let timestamp = UInt64(max(0, signal.occurredAt.timeIntervalSince1970 * 1_000))
        let destination = try queue(
            try JSONEncoder.anchorExternal.encode(signal),
            itemID: signal.id,
            inbox: inbox,
            filename: "\(timestamp)-\(phaseOrder)-cli-\(signal.id.uuidString).json"
        )

        if phase == .started {
            print(commandID.uuidString)
        } else {
            print("Queued command completion at \(destination.path)")
        }
    }

    private static func queue(
        _ data: Data,
        itemID: UUID,
        inbox: URL,
        filename: String? = nil
    ) throws -> URL {
        try FileManager.default.createDirectory(
            at: inbox,
            withIntermediateDirectories: true
        )

        let temporary = inbox.appending(path: ".\(itemID.uuidString).tmp")
        let destination = inbox.appending(path: filename ?? "\(itemID.uuidString).json")
        try data.write(to: temporary, options: .atomic)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }

    private static func printSchema() throws {
        let processID = UUID(uuidString: "00000000-0000-4000-8000-000000000501") ?? UUID()
        let sessionID = UUID(uuidString: "00000000-0000-4000-8000-000000000502") ?? UUID()
        let sourceID = UUID(uuidString: "00000000-0000-4000-8000-000000000503") ?? UUID()
        let process = AnchorProcess(
            id: processID,
            sourceID: sourceID,
            sourceName: "Example source",
            sourceSymbol: "E",
            sourceTone: "cyan",
            title: "A process observed by Anchor",
            status: .running,
            progress: 0.5,
            detail: "A concise status summary only."
        )
        let event = ExternalProcessEvent(
            sessionID: sessionID,
            sourceID: sourceID,
            sequence: 1,
            process: process,
            event: ProcessEvent(
                sessionID: sessionID,
                processID: processID,
                sourceID: sourceID,
                kind: .progress,
                title: "Halfway"
            ),
            deduplicationKey: "example-1"
        )
        let data = try JSONEncoder.anchorExternal.encode(event)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func printShellIntegration(_ arguments: [String]) throws {
        guard arguments == ["zsh"] else {
            throw CLIError.unknownCommand(
                arguments.first.map { "shell \($0)" } ?? "shell"
            )
        }
        print(
            """
            autoload -Uz add-zsh-hook

            typeset -g ANCHOR_COMMAND_ID=""
            typeset -g ANCHOR_COMMAND_NAME=""

            _anchor_preexec() {
              local command_line="$1"
              local executable="${command_line%%[[:space:]]*}"
              [[ "$executable" == "anchor" ]] && return 0
              command -v anchor >/dev/null 2>&1 || return 0

              ANCHOR_COMMAND_NAME="${executable:t}"
              ANCHOR_COMMAND_ID="$(command anchor command start --name "$ANCHOR_COMMAND_NAME" --workspace "$PWD" --terminal "${TERM_PROGRAM:-Terminal}" 2>/dev/null)"
            }

            _anchor_precmd() {
              local command_status="$?"
              if [[ -n "$ANCHOR_COMMAND_ID" ]]; then
                command anchor command finish --id "$ANCHOR_COMMAND_ID" --name "$ANCHOR_COMMAND_NAME" --workspace "$PWD" --terminal "${TERM_PROGRAM:-Terminal}" --exit-code "$command_status" >/dev/null 2>&1
                ANCHOR_COMMAND_ID=""
                ANCHOR_COMMAND_NAME=""
              fi
              return "$command_status"
            }

            add-zsh-hook preexec _anchor_preexec
            add-zsh-hook precmd _anchor_precmd
            """
        )
    }

    private static func printUsage() {
        print(
            """
            Anchor CLI

            anchor schema
              Print the versioned JSON event contract.

            anchor emit --file EVENT.json [--inbox PATH]
              Atomically queue one ExternalProcessEvent for the Mac companion.
              Without --file, emit reads the JSON event from stdin.

            anchor command start --name EXECUTABLE [--id UUID] [--workspace PATH]
              Queue a privacy-minimal command start signal and print its command ID.

            anchor command finish --id UUID --name EXECUTABLE --exit-code CODE
              Queue the matching command completion signal.

            Both command subcommands also accept --terminal NAME and --inbox PATH.
            Command arguments and full working-directory paths are never stored.

            anchor shell zsh
              Print an opt-in zsh preexec/precmd integration script.
            """
        )
    }
}

private struct CommandLifecycleOptions {
    let phase: CLICommandPhase
    let commandID: UUID?
    let executableName: String
    let workspaceName: String?
    let terminalName: String?
    let exitCode: Int?
    let inboxURL: URL?

    init(phase: CLICommandPhase, arguments: [String]) throws {
        self.phase = phase
        var commandID: UUID?
        var executableName: String?
        var workspaceName: String?
        var terminalName: String?
        var exitCode: Int?
        var inboxURL: URL?
        var index = 0

        while index < arguments.count {
            let option = arguments[index]
            index += 1
            guard arguments.indices.contains(index) else {
                throw CLIError.missingValue(option)
            }
            let value = arguments[index]

            switch option {
            case "--id":
                guard let parsed = UUID(uuidString: value) else {
                    throw CLIError.invalidValue(option, value)
                }
                commandID = parsed
            case "--name":
                executableName = value
            case "--workspace":
                workspaceName = value
            case "--terminal":
                terminalName = value
            case "--exit-code":
                guard let parsed = Int(value) else {
                    throw CLIError.invalidValue(option, value)
                }
                exitCode = parsed
            case "--inbox":
                inboxURL = URL(filePath: value)
            default:
                throw CLIError.unknownOption(option)
            }
            index += 1
        }

        guard let executableName,
              !executableName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CLIError.missingOption("--name")
        }
        if phase == .finished, commandID == nil {
            throw CLIError.missingOption("--id")
        }
        if phase == .finished, exitCode == nil {
            throw CLIError.missingOption("--exit-code")
        }

        self.commandID = commandID
        self.executableName = executableName
        self.workspaceName = workspaceName
        self.terminalName = terminalName
        self.exitCode = exitCode
        self.inboxURL = inboxURL
    }

    func resolvedCommandID() throws -> UUID {
        if let commandID {
            return commandID
        }
        guard phase == .started else {
            throw CLIError.missingOption("--id")
        }
        return UUID()
    }
}

private struct CLIOptions {
    let inputFile: String?
    let inboxURL: URL?

    init(arguments: [String]) throws {
        var inputFile: String?
        var inboxURL: URL?
        var index = 0
        while index < arguments.count {
            switch arguments[index] {
            case "--file":
                index += 1
                guard arguments.indices.contains(index) else { throw CLIError.missingValue("--file") }
                inputFile = arguments[index]
            case "--inbox":
                index += 1
                guard arguments.indices.contains(index) else { throw CLIError.missingValue("--inbox") }
                inboxURL = URL(filePath: arguments[index])
            case "--help", "-h":
                throw CLIError.helpRequested
            default:
                throw CLIError.unknownOption(arguments[index])
            }
            index += 1
        }
        self.inputFile = inputFile
        self.inboxURL = inboxURL
    }
}

private enum CLIError: LocalizedError {
    case helpRequested
    case invalidValue(String, String)
    case missingInput
    case missingOption(String)
    case missingValue(String)
    case unknownCommand(String)
    case unknownOption(String)

    var errorDescription: String? {
        switch self {
        case .helpRequested: ""
        case let .invalidValue(option, value): "Invalid value for \(option): \(value)."
        case .missingInput: "No event JSON was supplied. Use --file or stdin."
        case let .missingOption(option): "Missing required option \(option)."
        case let .missingValue(option): "Missing value for \(option)."
        case let .unknownCommand(command): "Unknown command: \(command)."
        case let .unknownOption(option): "Unknown option: \(option)."
        }
    }
}
