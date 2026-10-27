import Foundation
import Testing
@testable import AnchorCore

struct DayActivityTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ text: String) -> Date { try! Date.ISO8601FormatStyle().parse(text) }

    @Test func overlappingLinksCountOnce() {
        let links = [
            DateInterval(start: date("2026-10-27T09:00:00Z"), end: date("2026-10-27T10:00:00Z")),
            DateInterval(start: date("2026-10-27T09:30:00Z"), end: date("2026-10-27T10:30:00Z")),
        ]
        #expect(AnchoringTime.total(links, on: date("2026-10-27T12:00:00Z"), calendar: calendar) == 5400)
    }

    @Test func aLinkAcrossMidnightSplitsBetweenDays() {
        let links = [DateInterval(start: date("2026-10-26T23:00:00Z"), end: date("2026-10-27T01:00:00Z"))]
        #expect(AnchoringTime.total(links, on: date("2026-10-26T12:00:00Z"), calendar: calendar) == 3600)
        #expect(AnchoringTime.total(links, on: date("2026-10-27T12:00:00Z"), calendar: calendar) == 3600)
    }

    @Test func tokensFromBothDialectsLandInHalfHours() throws {
        let lines = [
            #"{"timestamp":"2026-10-27T09:05:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1000,"cached_input_tokens":400,"output_tokens":100}}}}"#,
            #"{"timestamp":"2026-10-27T09:40:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":1500,"cached_input_tokens":600,"output_tokens":200}}}}"#,
            #"{"timestamp":"2026-10-27T09:41:00.000Z","type":"assistant","message":{"id":"m1","usage":{"input_tokens":5,"cache_creation_input_tokens":50,"cache_read_input_tokens":9000,"output_tokens":20}}}"#,
            #"{"timestamp":"2026-10-27T09:41:01.000Z","type":"assistant","message":{"id":"m1","usage":{"input_tokens":5,"cache_creation_input_tokens":50,"cache_read_input_tokens":9000,"output_tokens":20}}}"#,
        ]
        // Its own folder: other suites watch the temporary directory for logs.
        let folder = FileManager.default.temporaryDirectory.appending(path: "tally-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "log.jsonl")
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        let slots = TokenTally.read(url)
        #expect(slots[date("2026-10-27T09:00:00Z")] == 700)
        // Codex rose by 300 fresh input and 100 output; Claude's one reply counts once.
        #expect(slots[date("2026-10-27T09:30:00Z")] == 400 + 75)
    }
}
