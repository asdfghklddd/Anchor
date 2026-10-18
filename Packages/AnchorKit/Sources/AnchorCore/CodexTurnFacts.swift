import Foundation

/// Whether a turn ran tests and how they ended. Only this verdict leaves the
/// Mac: commands and their output are read transiently and never kept.
public enum TestOutcome: String, Codable, Hashable, Sendable {
    case passed
    case failed
    /// Tests ran, but no exit status was visible in the log.
    case ran
    /// A long turn that ran no tests.
    case notRun

    /// A newer peer may report outcomes this build does not know; read them as "ran".
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TestOutcome(rawValue: raw) ?? .ran
    }
}

/// What one Codex turn did that matters beyond its reply (B3): whether it ran
/// tests and how they ended, and whether it asked the person something still
/// unanswered. Lines are read one at a time and only these facts are kept.
struct CodexTurnFacts: Sendable {
    /// A turn at least this long that ran no tests reads as "not tested".
    static let longTurn: TimeInterval = 3 * 60

    private var sawTurnStart = false
    private var pendingTestCalls: Set<String> = []
    private var testRuns = 0
    private var lastTestExit: Int?
    /// When the person was asked something they have not answered yet.
    private(set) var questionAskedAt: Date?
    /// Questions that hold the turn until answered (`request_user_input`).
    private var blockingQuestions: Set<String> = []

    /// A new turn: test facts start over; an open question stays open until answered.
    mutating func turnStarted() {
        sawTurnStart = true
        pendingTestCalls = []
        testRuns = 0
        lastTestExit = nil
    }

    /// The turn's test verdict. "Not tested" is claimed only for a long turn
    /// read from its start, so a partial read never accuses a run.
    func tests(duration: TimeInterval?) -> TestOutcome? {
        if testRuns > 0 {
            guard let lastTestExit else { return .ran }
            return lastTestExit == 0 ? .passed : .failed
        }
        guard sawTurnStart, let duration, duration >= Self.longTurn else { return nil }
        return .notRun
    }

    /// An open question once the turn ended, or one that holds a running turn.
    func isWaitingForReply(turnEnded: Bool) -> Bool {
        questionAskedAt != nil && (turnEnded || !blockingQuestions.isEmpty)
    }

    mutating func consume(_ line: Data) {
        // Most lines are reasoning, messages and tool output: read the record's own
        // type from its head, never from text a tool printed further on.
        let head = String(decoding: line.prefix(600), as: UTF8.self)
        guard let type = head.firstMatch(of: /"payload":\{"type":"([a-z_]+)"/).map({ String($0.output.1) }) else { return }
        if type == "user_message" || (type == "message" && head.contains(#""payload":{"type":"message","role":"user""#)) {
            questionAskedAt = nil
            blockingQuestions = []
            return
        }
        let isOutput = type == "custom_tool_call_output" || type == "function_call_output"
        let isCall = type == "custom_tool_call" || type == "function_call"
        if isOutput {
            // Only the outputs of calls that matter are decoded; tool output can be large.
            guard let id = Self.callID(in: head), pendingTestCalls.contains(id) || blockingQuestions.contains(id),
                  let payload = try? JSONDecoder().decode(Envelope.self, from: line).payload else { return }
            if blockingQuestions.remove(id) != nil {
                questionAskedAt = nil
            } else if pendingTestCalls.remove(id) != nil, let code = payload.outputText.flatMap(Self.exitCode) {
                lastTestExit = code
            }
        } else if isCall, let envelope = try? JSONDecoder().decode(Envelope.self, from: line) {
            let payload = envelope.payload
            let name = payload.name ?? ""
            if name == "request_user_input" || name == "request_user_input_async" {
                questionAskedAt = Self.date(envelope.timestamp) ?? questionAskedAt ?? .now
                if name == "request_user_input", let id = payload.callID { blockingQuestions.insert(id) }
                return
            }
            guard let command = Self.command(payload), Self.runsTests(command) else { return }
            testRuns += 1
            if let id = payload.callID { pendingTestCalls.insert(id) }
        }
    }

    // MARK: Reading a line

    static func runsTests(_ command: String) -> Bool {
        command.contains(/\b(swift test|xcodebuild\b[^\n|;&]*\btest(-without-building)?|(npm|pnpm|yarn|bun) (run )?test|pytest|python3? -m (pytest|unittest)|go test|cargo test|jest|vitest|make test|gradlew? test|mvn test|rspec|phpunit|ctest|deno test)\b/)
    }

    /// The last exit status the output reports, in any of the shapes Codex has written.
    static func exitCode(in text: String) -> Int? {
        let matches = text.matches(of: /"exit_code"\s*:\s*(-?\d+)|Exit code: (-?\d+)|exited with code (-?\d+)/)
        guard let last = matches.last else { return nil }
        return (last.output.1 ?? last.output.2 ?? last.output.3).flatMap { Int($0) }
    }

    /// The shell the call runs: a script for the current `exec` and `js` tools,
    /// a command line or argument list for older shell tools.
    private static func command(_ payload: Payload) -> String? {
        if let input = payload.input { return input }
        guard let arguments = payload.arguments, let data = arguments.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        for key in ["code", "cmd", "command"] {
            if let text = object[key] as? String { return text }
            if let parts = object[key] as? [String] { return parts.joined(separator: " ") }
        }
        return nil
    }

    private static func callID(in head: String) -> String? {
        guard let match = head.firstMatch(of: /"call_id":"([^"]+)"/) else { return nil }
        return String(match.output.1)
    }

    private static func date(_ timestamp: String?) -> Date? {
        guard let timestamp else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: timestamp) ?? ISO8601DateFormatter().date(from: timestamp)
    }

    private struct Envelope: Decodable {
        let timestamp: String?
        let payload: Payload
    }

    private struct Payload: Decodable {
        let name: String?
        let callID: String?
        let input: String?
        let arguments: String?
        let outputText: String?

        enum CodingKeys: String, CodingKey {
            case name, input, arguments, output
            case callID = "call_id"
        }

        init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            name = try? values.decodeIfPresent(String.self, forKey: .name)
            callID = try? values.decodeIfPresent(String.self, forKey: .callID)
            input = try? values.decodeIfPresent(String.self, forKey: .input)
            arguments = try? values.decodeIfPresent(String.self, forKey: .arguments)
            if let text = try? values.decodeIfPresent(String.self, forKey: .output) {
                outputText = text
            } else if let items = try? values.decodeIfPresent([OutputItem].self, forKey: .output) {
                outputText = items.compactMap(\.text).joined(separator: "\n")
            } else {
                outputText = nil
            }
        }
    }

    private struct OutputItem: Decodable {
        let text: String?
    }
}
