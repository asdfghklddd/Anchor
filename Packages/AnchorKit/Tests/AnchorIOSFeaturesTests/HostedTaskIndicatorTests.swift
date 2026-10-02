import Foundation
import Testing
import AnchorCore
@testable import AnchorIOSFeatures

@Suite("Hosted task indicator")
struct HostedTaskIndicatorTests {
    @Test(arguments: ProcessStatus.allCases)
    func sourceStatusMapsToTheRequestedLights(_ status: ProcessStatus) {
        let indicator = HostedTaskIndicator(task: task([process(status)]))
        #expect(indicator.isRunning == (status == .running))
        #expect(indicator.hasFailure == (status == .failed))
        #expect(indicator.hasWarning == [.needsDecision, .blocked, .disconnected].contains(status))
        #expect(indicator.isComplete == (status == .completed))
    }

    @Test func mixedSessionsRetainEachRelevantLightUntilAllComplete() {
        let indicator = HostedTaskIndicator(task: task([process(.running), process(.failed), process(.needsDecision)]))
        #expect(indicator.isRunning && indicator.hasFailure && indicator.hasWarning)
        #expect(!indicator.isComplete)
        #expect(!HostedTaskIndicator(task: task([process(.completed), process(.queued)])).isComplete)
        #expect(HostedTaskIndicator(task: task([process(.completed), process(.completed)])).isComplete)
    }

    @Test func personalPlanDoesNotLookCompleteWithoutProcesses() {
        var plan = task([])
        plan.status = .active
        #expect(HostedTaskIndicator(task: plan).isRunning)
        #expect(!HostedTaskIndicator(task: plan).isComplete)
        plan.status = .completed
        let completed = HostedTaskIndicator(task: plan)
        #expect(completed.isComplete)
        #expect(!completed.isRunning && !completed.hasFailure && !completed.hasWarning)
    }

    @Test func ambientAppsDoNotPreventCompletionAndInterruptedTurnsAreWarnings() {
        var ambient = process(.running)
        ambient.sourceID = BuiltInProcessSourceID.macWorkspace
        #expect(HostedTaskIndicator(task: task([process(.completed), ambient])).isComplete)
        var interrupted = process(.failed)
        interrupted.sourceName = "Codex"
        interrupted.events = [ProcessEvent(occurredAt: interrupted.updatedAt, kind: .failed, title: "Codex turn_aborted")]
        let indicator = HostedTaskIndicator(task: task([interrupted]))
        #expect(indicator.hasWarning)
        #expect(!indicator.hasFailure && !indicator.isComplete)
    }

    private func task(_ processes: [AnchorProcess]) -> AnchorSession {
        AnchorSession(goal: AnchorGoal(title: "Task", completionCriteria: "Reviewed"), processes: processes)
    }

    private func process(_ status: ProcessStatus) -> AnchorProcess {
        AnchorProcess(sourceName: "Source", sourceSymbol: "S", sourceTone: "cyan", title: "Conversation", status: status)
    }
}
