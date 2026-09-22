import Foundation
import Testing
@testable import AnchorCore

@Suite("Process presentation groups")
struct ProcessPresentationGroupTests {
    @Test("Manual plans, task observations and Mac app activity remain separate")
    func classifiesProcessOwnership() {
        let planned = process(title: "Plan", sourceID: nil)
        let observed = process(title: "Codex run", sourceID: UUID())
        let environment = process(
            title: "Xcode",
            sourceID: BuiltInProcessSourceID.macWorkspace
        )
        let session = AnchorSession(
            goal: AnchorGoal(title: "Ship", completionCriteria: "Verified"),
            processes: [planned, environment, observed]
        )

        #expect(planned.presentationGroup == .planned)
        #expect(observed.presentationGroup == .observedTask)
        #expect(environment.presentationGroup == .environment)
        #expect(session.plannedProcesses.map(\.id) == [planned.id])
        #expect(session.observedTaskProcesses.map(\.id) == [observed.id])
        #expect(session.environmentProcesses.map(\.id) == [environment.id])
        #expect(session.taskProcesses.map(\.id) == [planned.id, observed.id])
    }

    @Test("Built-in production source identities remain distinct")
    func builtInSourceIdentitiesAreDistinct() {
        let identities = [
            BuiltInProcessSourceID.file,
            BuiltInProcessSourceID.web,
            BuiltInProcessSourceID.macWorkspace,
            BuiltInProcessSourceID.codex,
        ]

        #expect(Set(identities).count == identities.count)
        #expect(BuiltInProcessSourceID.file.uuidString == "00000000-0000-4000-8000-000000000401")
        #expect(BuiltInProcessSourceID.web.uuidString == "00000000-0000-4000-8000-000000000402")
        #expect(BuiltInProcessSourceID.macWorkspace.uuidString == "00000000-0000-4000-8000-000000000403")
        #expect(BuiltInProcessSourceID.codex.uuidString == "00000000-0000-4000-8000-000000000404")
        #expect(FileProcessSource.defaultSourceID == BuiltInProcessSourceID.file)
        #expect(WebProcessSource.defaultSourceID == BuiltInProcessSourceID.web)
        #if os(macOS)
        #expect(MacWorkspaceProcessSource.defaultSourceID == BuiltInProcessSourceID.macWorkspace)
        #endif
        #expect(CodexLifecycleFileSource.defaultSourceID == BuiltInProcessSourceID.codex)
    }

    private func process(title: String, sourceID: UUID?) -> AnchorProcess {
        AnchorProcess(
            sourceID: sourceID,
            sourceName: title,
            sourceSymbol: String(title.prefix(1)),
            sourceTone: "cyan",
            title: title,
            status: .running
        )
    }
}
