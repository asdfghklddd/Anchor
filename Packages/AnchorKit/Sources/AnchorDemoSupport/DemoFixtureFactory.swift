import AnchorCore
import Foundation

public enum DemoFixtureFactory {
    public static let schemaVersion = 1

    public static func projection(
        for scenario: DemoScenario,
        now: Date = .now
    ) -> SessionProjection {
        guard scenario != .empty else {
            return SessionProjection(
                generatedAt: now,
                dataObservedAt: now
            )
        }

        var session = baselineSession(now: now)
        var connection = ConnectionState.connected
        var proximity = ProximityState.near
        var observedAt = now
        var errorMessage: String?

        switch scenario {
        case .active:
            resolvePendingDecisions(in: &session, at: now)
        case .needsDecision:
            session.processes[1].status = .needsDecision
        case .away18Minutes:
            session.presence = .away
            let awaySince = now.addingTimeInterval(-18 * 60)
            session.snapshots = [sessionSnapshot(session, at: awaySince)]
            session.timeline = returnEvents(session: session, now: now)
            connection = .disconnected
            proximity = .far
        case .returning:
            session.presence = .returning
            let changes = returnChanges(session: session, now: now)
            session.returnSummary = ReturnSummary(
                awaySince: now.addingTimeInterval(-18 * 60),
                generatedAt: now,
                changes: changes,
                recommendedProcessID: session.processes[1].id
            )
        case .completed:
            resolvePendingDecisions(in: &session, at: now)
            session.status = .completed
            session.completedAt = now.addingTimeInterval(-120)
            for index in session.processes.indices {
                session.processes[index].status = .completed
                session.processes[index].progress = 1
            }
        case .empty:
            break
        case .disconnected:
            resolvePendingDecisions(in: &session, at: now)
            connection = .disconnected
            proximity = .unknown
        case .permissionDenied:
            resolvePendingDecisions(in: &session, at: now)
            session.presence = .unknown
            connection = .permissionDenied
            proximity = .permissionDenied
        case .staleData:
            resolvePendingDecisions(in: &session, at: now)
            observedAt = now.addingTimeInterval(-12 * 60)
        case .retryableError:
            resolvePendingDecisions(in: &session, at: now)
            connection = .failed
            proximity = .unknown
            errorMessage = text("demo.error.connection", default: "The Mac connection was interrupted. Try again.")
        }

        return SessionProjection(
            session: session,
            connection: connection,
            proximity: proximity,
            generatedAt: now,
            dataObservedAt: observedAt,
            errorMessage: errorMessage
        )
    }

    public static func signals(
        for scenario: DemoScenario,
        now: Date = .now
    ) -> PresenceSignals {
        switch scenario {
        case .away18Minutes:
            PresenceSignals(
                posture: .portrait,
                connection: .disconnected,
                proximity: .far,
                observedAt: now
            )
        case .returning, .active, .needsDecision, .completed:
            PresenceSignals(
                posture: .portrait,
                connection: .connected,
                proximity: .near,
                observedAt: now
            )
        case .disconnected, .staleData, .retryableError, .empty:
            PresenceSignals(
                posture: .portrait,
                connection: .disconnected,
                proximity: .unknown,
                observedAt: now
            )
        case .permissionDenied:
            PresenceSignals(
                posture: .portrait,
                connection: .permissionDenied,
                proximity: .permissionDenied,
                observedAt: now
            )
        }
    }

    private static func baselineSession(now: Date) -> AnchorSession {
        let scriptID = stableID("00000000-0000-4000-8000-000000000101")
        let storyboardID = stableID("00000000-0000-4000-8000-000000000102")
        let renderID = stableID("00000000-0000-4000-8000-000000000103")
        let editID = stableID("00000000-0000-4000-8000-000000000104")
        let directionA = DecisionOption(
            id: stableID("00000000-0000-4000-8000-000000000201"),
            title: text("demo.option.documentary", default: "Warm documentary"),
            detail: text("demo.option.documentary.detail", default: "Natural light, restrained motion, human details")
        )
        let directionB = DecisionOption(
            id: stableID("00000000-0000-4000-8000-000000000202"),
            title: text("demo.option.candy", default: "Candy Harbor"),
            detail: text("demo.option.candy.detail", default: "Confident color, tactile cards, playful transitions")
        )
        let directionC = DecisionOption(
            id: stableID("00000000-0000-4000-8000-000000000203"),
            title: text("demo.option.minimal", default: "Product minimal"),
            detail: text("demo.option.minimal.detail", default: "Quiet typography and close product framing")
        )

        let processes = [
            AnchorProcess(
                id: scriptID,
                sourceName: "Claude",
                sourceSymbol: "C",
                sourceTone: "coral",
                title: text("demo.script.title", default: "Polish the third-act script"),
                status: .running,
                progress: 0.64,
                metric: "58s",
                metricLabel: text("demo.script.metric", default: "Target length"),
                detail: text("demo.script.detail", default: "Compressing the closing narration and aligning the product voice."),
                estimatedCompletion: text("demo.script.eta", default: "About 7 minutes"),
                updatedAt: now,
                tileSize: .standard,
                events: [
                    ProcessEvent(processID: scriptID, occurredAt: now.addingTimeInterval(-240), kind: .progress, title: text("demo.script.event.merged", default: "Merged two narrative directions")),
                    ProcessEvent(processID: scriptID, occurredAt: now.addingTimeInterval(-60), kind: .progress, title: text("demo.script.event.rewriting", default: "Rewriting the closing narration")),
                ]
            ),
            AnchorProcess(
                id: storyboardID,
                sourceName: "Gemini",
                sourceSymbol: "G",
                sourceTone: "periwinkle",
                title: text("demo.storyboard.title", default: "Confirm the storyboard"),
                status: .needsDecision,
                progress: 0.82,
                metric: "12",
                metricLabel: text("demo.storyboard.metric", default: "Candidate frames"),
                detail: text("demo.storyboard.detail", default: "Three visual directions are ready for your judgment."),
                estimatedCompletion: text("demo.storyboard.eta", default: "Needs your decision"),
                updatedAt: now.addingTimeInterval(-120),
                tileSize: .standard,
                events: [
                    ProcessEvent(processID: storyboardID, occurredAt: now.addingTimeInterval(-180), kind: .outputReady, title: text("demo.storyboard.event.created", default: "Created 12 candidate frames")),
                    ProcessEvent(processID: storyboardID, occurredAt: now.addingTimeInterval(-120), kind: .decisionRequired, title: text("demo.storyboard.event.choose", default: "Choose a visual direction")),
                ]
            ),
            AnchorProcess(
                id: renderID,
                sourceName: "Seedance",
                sourceSymbol: "S",
                sourceTone: "cyan",
                title: text("demo.render.title", default: "Generate transition shots"),
                status: .running,
                progress: 0.37,
                metric: "04/10",
                metricLabel: text("demo.render.metric", default: "Current shot"),
                detail: text("demo.render.detail", default: "Shot 04 is rendering with stable motion."),
                estimatedCompletion: text("demo.render.eta", default: "About 18 minutes"),
                updatedAt: now,
                tileSize: .standard,
                events: [
                    ProcessEvent(processID: renderID, occurredAt: now.addingTimeInterval(-360), kind: .progress, title: text("demo.render.event.three", default: "Completed the first three shots")),
                    ProcessEvent(processID: renderID, occurredAt: now.addingTimeInterval(-30), kind: .progress, title: text("demo.render.event.four", default: "Rendering shot 04")),
                ]
            ),
            AnchorProcess(
                id: editID,
                sourceName: "Final Cut",
                sourceSymbol: "F",
                sourceTone: "ink",
                title: text("demo.edit.title", default: "Finish the rhythm edit"),
                status: .queued,
                progress: 0.18,
                metric: "60s",
                metricLabel: text("demo.edit.metric", default: "Edit timeline"),
                detail: text("demo.edit.detail", default: "The project is ready and waiting for storyboard approval."),
                estimatedCompletion: text("demo.edit.eta", default: "Waiting on prerequisite"),
                updatedAt: now.addingTimeInterval(-300),
                tileSize: .standard,
                events: [
                    ProcessEvent(processID: editID, occurredAt: now.addingTimeInterval(-600), kind: .created, title: text("demo.edit.event.created", default: "Created the 60-second timeline")),
                ]
            ),
        ]

        let decision = Decision(
            id: stableID("00000000-0000-4000-8000-000000000301"),
            processID: storyboardID,
            title: text("demo.decision.title", default: "Choose the lead visual direction"),
            prompt: text("demo.decision.prompt", default: "Which direction best carries the calm, capable personality of Anchor?"),
            options: [directionA, directionB, directionC],
            requestedAt: now.addingTimeInterval(-120)
        )

        return AnchorSession(
            id: stableID("00000000-0000-4000-8000-000000000001"),
            goal: AnchorGoal(
                id: stableID("00000000-0000-4000-8000-000000000002"),
                title: text("demo.goal.title", default: "Finish the Anchor product film"),
                completionCriteria: text("demo.goal.criteria", default: "Export a polished 60-second cut today."),
                note: text("demo.goal.note", default: "Lock the script and storyboard, generate the shots, then make the final rhythm and taste decisions."),
                createdAt: now.addingTimeInterval(-42 * 60)
            ),
            status: .active,
            presence: .atDesk,
            startedAt: now.addingTimeInterval(-42 * 60),
            processes: processes,
            decisions: [decision],
            timeline: processes.flatMap(\.events).sorted { $0.occurredAt > $1.occurredAt }
        )
    }

    private static func returnEvents(session: AnchorSession, now: Date) -> [ProcessEvent] {
        zip(returnChanges(session: session, now: now), session.processes).map { change, process in
            ProcessEvent(
                processID: process.id,
                occurredAt: change.occurredAt,
                kind: change.kind,
                title: change.title,
                detail: change.detail
            )
        }
    }

    private static func returnChanges(session: AnchorSession, now: Date) -> [ReturnChange] {
        [
            ReturnChange(
                occurredAt: now.addingTimeInterval(-7 * 60),
                title: text("demo.return.storyboard", default: "Gemini completed 12 storyboard frames"),
                detail: text("demo.return.storyboard.detail", default: "Three directions are waiting for judgment."),
                kind: .decisionRequired
            ),
            ReturnChange(
                occurredAt: now.addingTimeInterval(-3 * 60),
                title: text("demo.return.render", default: "Seedance completed shot 03"),
                detail: text("demo.return.render.detail", default: "Motion stability passed."),
                kind: .completed
            ),
            ReturnChange(
                occurredAt: now.addingTimeInterval(-60),
                title: text("demo.return.script", default: "Claude compressed the script to 58 seconds"),
                detail: text("demo.return.script.detail", default: "The narration now fits the target."),
                kind: .progress
            ),
        ]
    }

    private static func sessionSnapshot(_ session: AnchorSession, at date: Date) -> ContextSnapshot {
        ContextSnapshot(
            createdAt: date,
            goalTitle: session.goal.title,
            processes: session.processes,
            openDecisionIDs: session.decisions.filter { $0.status == .open }.map(\.id),
            latestNote: session.notes.first?.text
        )
    }

    private static func resolvePendingDecisions(in session: inout AnchorSession, at date: Date) {
        for decisionIndex in session.decisions.indices where session.decisions[decisionIndex].status == .open {
            let selectedOptionID = session.decisions[decisionIndex].options.first?.id
            session.decisions[decisionIndex].status = .resolved
            session.decisions[decisionIndex].selectedOptionID = selectedOptionID
            session.decisions[decisionIndex].resolvedAt = date

            let processID = session.decisions[decisionIndex].processID
            if let processIndex = session.processes.firstIndex(where: { $0.id == processID }),
               session.processes[processIndex].status == .needsDecision {
                session.processes[processIndex].status = .running
                session.processes[processIndex].updatedAt = date
            }
        }
    }

    private static func stableID(_ value: String) -> UUID {
        UUID(uuidString: value) ?? UUID()
    }

    private static func text(_ key: StaticString, default defaultValue: String.LocalizationValue) -> String {
        String(localized: key, defaultValue: defaultValue, bundle: .module)
    }
}
