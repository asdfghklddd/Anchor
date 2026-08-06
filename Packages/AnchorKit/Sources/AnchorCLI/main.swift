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
        case "emit":
            try emit(arguments)
        case "schema":
            try printSchema()
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
        let encoded = try JSONEncoder.anchorExternal.encode(event)
        let inbox = options.inboxURL ?? FileProcessSource.defaultInboxURL()
        try FileManager.default.createDirectory(
            at: inbox,
            withIntermediateDirectories: true
        )

        let temporary = inbox.appending(path: ".\(event.id.uuidString).tmp")
        let destination = inbox.appending(path: "\(event.id.uuidString).json")
        try encoded.write(to: temporary, options: .atomic)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temporary, to: destination)
        print("Queued Anchor event \(event.id.uuidString) at \(destination.path)")
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

    private static func printUsage() {
        print(
            """
            Anchor CLI

            anchor schema
              Print the versioned JSON event contract.

            anchor emit --file EVENT.json [--inbox PATH]
              Atomically queue one ExternalProcessEvent for the Mac companion.
              Without --file, emit reads the JSON event from stdin.
            """
        )
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
    case missingInput
    case missingValue(String)
    case unknownCommand(String)
    case unknownOption(String)

    var errorDescription: String? {
        switch self {
        case .helpRequested: ""
        case .missingInput: "No event JSON was supplied. Use --file or stdin."
        case let .missingValue(option): "Missing value for \(option)."
        case let .unknownCommand(command): "Unknown command: \(command)."
        case let .unknownOption(option): "Unknown option: \(option)."
        }
    }
}
