import Foundation
import Testing
@testable import AnchorCore

private let lifecycleLine = #"{"timestamp":"2026-09-05T01:02:03.123Z","type":"event_msg","payload":{"type":"task_started","turn_id":"t-2"}}"# + "\n"

@Test("Checkpoint stores only complete-line offset and rereads private partial bytes")
func checkpointRestoresScanner() throws {
    let complete = Data(lifecycleLine.utf8)
    let partial = Data(#"{"private":"secret-body""#.utf8)
    var first = CodexIncrementalScanner()
    #expect(first.append(complete).count == 1)
    #expect(first.append(partial).isEmpty)
    let checkpoint = try first.checkpoint()
    let dictionary = try #require(JSONSerialization.jsonObject(with: checkpoint) as? [String: Any])
    #expect(Set(dictionary.keys) == ["version", "offset"])
    #expect(!String(decoding: checkpoint, as: UTF8.self).contains("secret-body"))
    var second = try CodexIncrementalScanner(checkpoint: checkpoint)
    #expect(second.offset == UInt64(complete.count))
    #expect(second.append(partial + Data("}\n".utf8)).isEmpty)
    #expect(second.append(complete).map(\.turnID) == ["t-2"])
}

@Test("Scanner defers partial rows and skips malformed, unknown and oversized rows")
func scannerBoundsAndPartialLines() {
    var scanner = CodexIncrementalScanner()
    #expect(scanner.append(Data(lifecycleLine.dropLast().utf8)).isEmpty)
    #expect(scanner.append(Data("\n".utf8)).count == 1)
    let unknown = #"{"timestamp":"2026-09-05T01:02:03Z","type":"event_msg","payload":{"type":"message"}}"#
    #expect(scanner.append(Data(("{broken}\n" + unknown + "\n").utf8)).isEmpty)
    #expect(scanner.append(Data(repeating: 120, count: 2 * 1_024 * 1_024 + 1)).isEmpty)
    #expect(scanner.append(Data(("\n" + lifecycleLine).utf8)).count == 1)
    scanner.reset()
    #expect(scanner.offset == 0)
    #expect(scanner.append(Data(lifecycleLine.utf8)).count == 1)
}

@Test("Unknown checkpoint version fails rather than silently resetting")
func rejectsUnknownCheckpoint() {
    #expect(throws: (any Error).self) {
        try CodexIncrementalScanner(checkpoint: Data(#"{"version":99,"offset":0}"#.utf8))
    }
}
