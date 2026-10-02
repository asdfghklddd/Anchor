import Testing
@testable import AnchorIOSFeatures

@MainActor
@Suite("Note submission feedback")
struct AnchorNoteSubmissionTests {
    @Test func failureKeepsInputAndDoesNotReportSuccessThenAllowsRetry() async {
        let submission = AnchorNoteSubmission()
        submission.text = "Remember the next step"
        #expect(await submission.save { _ in false } == false)
        #expect(submission.text == "Remember the next step")
        #expect(submission.hasFailed)
        #expect(submission.successCount == 0)
        #expect(submission.canSave)
        #expect(await submission.save { _ in true })
        #expect(!submission.hasFailed)
        #expect(submission.successCount == 1)
        #expect(!submission.canSave)
    }

    @Test func pendingSaveRejectsRepeatedSubmissionsAndWaitsForPersistence() async {
        let submission = AnchorNoteSubmission()
        submission.text = "Only one note"
        var completion: CheckedContinuation<Bool, Never>?
        var persisted: [String] = []
        let first = Task {
            await submission.save { text in
                persisted.append(text)
                return await withCheckedContinuation { completion = $0 }
            }
        }
        while completion == nil { await Task.yield() }
        #expect(submission.isSaving)
        #expect(submission.successCount == 0)
        #expect(await submission.save { text in persisted.append(text); return true } == false)
        completion?.resume(returning: true)
        #expect(await first.value)
        #expect(submission.successCount == 1)
        #expect(!submission.isSaving)
        #expect(await submission.save { text in persisted.append(text); return true } == false)
        #expect(persisted == ["Only one note"])
    }

    @Test func whitespaceDoesNotSubmit() async {
        let submission = AnchorNoteSubmission()
        submission.text = " \n "
        var called = false
        #expect(await submission.save { _ in called = true; return true } == false)
        #expect(!called)
        #expect(submission.successCount == 0)
    }
}
