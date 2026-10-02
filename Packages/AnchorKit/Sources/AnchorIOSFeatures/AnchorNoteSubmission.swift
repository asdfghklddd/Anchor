import Foundation
import Observation

/// Keeps input and success feedback tied to the local persistence result.
@MainActor
@Observable
final class AnchorNoteSubmission {
    var text = ""
    private(set) var isSaving = false
    private(set) var didSave = false
    private(set) var hasFailed = false
    private(set) var successCount = 0

    var canSave: Bool {
        !isSaving && !didSave && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func save(using persist: @MainActor (String) async -> Bool) async -> Bool {
        guard canSave else { return false }
        let submittedText = text
        isSaving = true
        hasFailed = false
        defer { isSaving = false }
        guard await persist(submittedText) else {
            hasFailed = true
            return false
        }
        didSave = true
        successCount += 1
        return true
    }
}
