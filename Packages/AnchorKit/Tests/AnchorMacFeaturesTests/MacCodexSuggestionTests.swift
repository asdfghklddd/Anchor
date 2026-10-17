#if os(macOS)
import Foundation
import AnchorCore
import Testing
@testable import AnchorMacFeatures

@MainActor
@Test func codexSuggestionRequiresConfirmationAndKeepsChosenOwner() async throws {
    let fixture = try CodexSuggestionFixture()
    defer { fixture.cleanup() }
    var calls: [(UUID, Bool)] = []
    let model = fixture.model { _, owner, automatic in calls.append((owner, automatic)) }
    defer { model.stopObserving() }
    var attentionCount = 0
    model.onNeedsAttention = { attentionCount += 1 }
    model.presentCodexSetupIfNeeded()
    #expect(model.showsCodexOnboarding)
    await model.observeAuthorizedCodexFolder(fixture.root)
    await model.automaticallyAssociate([fixture.candidate])
    let suggestion = try #require(model.codexSuggestions.first)
    #expect(calls.isEmpty)
    #expect(suggestion.suggestedTaskIDs == [fixture.owner.id])
    #expect(attentionCount == 1)
    model.finishCodexOnboarding()
    #expect(model.showsCodexReview)
    model.showsCodexReview = false
    await model.automaticallyAssociate([fixture.candidate])
    #expect(!model.showsCodexReview)
    // Correct the recommendation to a different task without switching the dashboard.
    await model.confirmSuggestion(suggestion, taskID: fixture.other.id)
    await model.confirmSuggestion(suggestion, taskID: fixture.other.id)
    #expect(calls.count == 1)
    #expect(calls.first?.0 == fixture.other.id)
    #expect(calls.first?.1 == false)
    #expect(model.trackedCodexSessionIDs.isEmpty)
    #expect(model.codexSuggestions.isEmpty)
    model.stopObserving()
    let restored = fixture.model { _, owner, automatic in calls.append((owner, automatic)) }
    defer { restored.stopObserving() }
    await restored.observeAuthorizedCodexFolder(fixture.root)
    #expect(calls.count == 2)
    #expect(calls.last?.0 == fixture.other.id)
    restored.presentCodexSetupIfNeeded()
    #expect(!restored.showsCodexOnboarding)
}

@MainActor
@Test func codexIgnoredSuggestionStaysIgnoredAfterRestart() async throws {
    let fixture = try CodexSuggestionFixture()
    defer { fixture.cleanup() }
    let model = fixture.model { _, _, _ in Issue.record("Ignored suggestion must not bind") }
    await model.observeAuthorizedCodexFolder(fixture.root)
    await model.automaticallyAssociate([fixture.candidate])
    model.dismissSuggestion(try #require(model.codexSuggestions.first))
    await model.automaticallyAssociate([fixture.candidate])
    #expect(model.codexSuggestions.isEmpty)
    model.stopObserving()
    let restored = fixture.model { _, _, _ in Issue.record("Ignored suggestion must not bind") }
    defer { restored.stopObserving() }
    await restored.observeAuthorizedCodexFolder(fixture.root)
    await restored.automaticallyAssociate([fixture.candidate])
    #expect(restored.codexSuggestions.isEmpty)
}

@MainActor
@Test func codexCannotConfirmCompletedTask() async throws {
    let fixture = try CodexSuggestionFixture()
    defer { fixture.cleanup() }
    let model = fixture.model { _, _, _ in Issue.record("Completed task must not bind") }
    defer { model.stopObserving() }
    await model.observeAuthorizedCodexFolder(fixture.root)
    await model.automaticallyAssociate([fixture.candidate])
    let suggestion = try #require(model.codexSuggestions.first)
    try await fixture.repository.send(.forSession(fixture.owner.id, .completeSession))
    await model.confirmSuggestion(suggestion, taskID: fixture.owner.id)
    #expect(model.errorMessage != nil)
    #expect(model.trackedCodexSessionIDs.isEmpty)
}

@MainActor
private struct CodexSuggestionFixture {
    let root: URL
    let suite: String
    let defaults: UserDefaults
    let owner: AnchorSession
    let other: AnchorSession
    let repository: InMemorySessionRepository
    let candidate: CodexTaskCandidate

    init() throws {
        root = URL.temporaryDirectory.appending(path: "anchor-suggestions-\(UUID())")
        suite = "anchor-suggestions-\(UUID())"
        defaults = try #require(UserDefaults(suiteName: suite))
        owner = AnchorSession(goal: AnchorGoal(title: "Anchor", completionCriteria: "Ship"), startedAt: .now.addingTimeInterval(-60))
        other = AnchorSession(goal: AnchorGoal(title: "Other project", completionCriteria: "Ship"))
        repository = InMemorySessionRepository(initialProjection: SessionProjection(session: owner, additionalSessions: [other]))
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appending(path: "existing.jsonl")
        try Data("""
        {"type":"session_meta","payload":{"id":"existing-thread"}}
        {"type":"event_msg","payload":{"type":"user_message","message":"Old unrelated topic"}}
        {"type":"event_msg","payload":{"type":"user_message","message":"Fix Anchor"}}

        """.utf8).write(to: file)
        candidate = CodexTaskCandidate(id: "existing-thread", fileURL: file, workspaceName: "Anchor", originator: nil,
            modifiedAt: .now, activity: .running, activityObservedAt: .now, createdAt: .now.addingTimeInterval(-86_400))
    }

    func model(onBind: @escaping @MainActor @Sendable (URL, UUID, Bool) async throws -> Void) -> MacSourceSetupModel {
        let repository = repository
        return MacSourceSetupModel(defaults: defaults,
            currentAnchorSessionID: { await repository.currentProjection().session?.id },
            autoAssociationSessions: { await repository.currentProjection().hostedSessions },
            onCodexSessionAssociated: onBind)
    }

    func cleanup() {
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: root)
    }
}
#endif

#if os(macOS)
import AppKit
import SwiftUI

@MainActor
@Test func codexConnectionSheetPreviews() async throws {
    guard let destination = ProcessInfo.processInfo.environment["ANCHOR_DESIGN_PREVIEW_EXPORT"] else { return }
    let fixture = try CodexSuggestionFixture()
    defer { fixture.cleanup() }
    let model = fixture.model { _, _, _ in }
    defer { model.stopObserving() }
    model.presentCodexSetupIfNeeded()
    func export(_ name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            let view = NSHostingView(rootView: MacCodexConnectionSheet(model: model)
                .environment(\.colorScheme, scheme)
                .environment(\.locale, Locale(identifier: "zh-Hans")))
            view.setFrameSize(view.fittingSize)
            view.layoutSubtreeIfNeeded()
            let bitmap = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let png = try #require(bitmap.representation(using: .png, properties: [:]))
            let directory = URL(filePath: destination)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try png.write(to: directory.appending(path: "\(name)-\(scheme == .dark ? "dark" : "light").png"))
        }
    }
    try export("codex-onboarding")
    await model.observeAuthorizedCodexFolder(fixture.root)
    await model.automaticallyAssociate([fixture.candidate])
    model.finishCodexOnboarding()
    try export("codex-review")
}
#endif
