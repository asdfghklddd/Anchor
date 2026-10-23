#if os(iOS)
import AnchorDesign

/// Copy stays in the shared string catalog alongside the rest of the app.
enum SetupCopy {
    static let title = AnchorStrings.value("setup.plan.title", default: "Task anchoring")
    static let steps = AnchorStrings.value("setup.plan.steps", default: "Action plan")
    static let titleLabel = AnchorStrings.value("setup.title.label", default: "Title")
    static let titlePlaceholder = AnchorStrings.value("setup.title.placeholder", default: "What's the task?")
    static let titleMeter = AnchorStrings.value("setup.title.meter", default: "Title length")
    static let titleTooLong = AnchorStrings.value("setup.title.over", default: "Too long for a title. The extra words will move to the plan.")
    static let titleTooLongToSave = AnchorStrings.value("goal.title.over", default: "A title fits about 16 Chinese or 32 Latin characters. Shorten it to save.")
    static let titleMoved = AnchorStrings.value("setup.title.moved", default: "The extra words moved to the plan.")
    static let planLabel = AnchorStrings.value("setup.plan.label", default: "Plan (optional)")
    static let planExample = AnchorStrings.value("setup.plan.example", default: "One step per line ✍️\nread → build → test (＾▽＾)ノ")
    static let planExampleHint = AnchorStrings.value("setup.plan.example.hint", default: "One step per line, or say them in order")
    static let splitOne = AnchorStrings.value("setup.plan.split.one", default: "Becomes 1 step")
    static let splitMany = AnchorStrings.value("setup.plan.split", default: "Becomes %lld steps")
    static let splitHint = AnchorStrings.value("setup.plan.split.hint", default: "Shows the steps")
    static let drop = AnchorStrings.value("setup.drop", default: "Drop anchor")
    static let dropOne = AnchorStrings.value("setup.drop.one", default: "Drop · 1 step")
    static let dropMany = AnchorStrings.value("setup.drop.steps", default: "Drop · %lld steps")
    static let slide = AnchorStrings.value("setup.slide.drop", default: "Slide to drop anchor")
    static let slideOne = AnchorStrings.value("setup.slide.drop.one", default: "Slide to drop · 1 step")
    static let slideMany = AnchorStrings.value("setup.slide.drop.steps", default: "Slide to drop · %lld steps")
    static let slideHint = AnchorStrings.value("setup.slide.hint", default: "Slide the anchor to the right to drop it")
    static let voiceRelease = AnchorStrings.value("setup.voice.release", default: "Listening · release to finish")
    static let voiceTapStop = AnchorStrings.value("setup.voice.tap-stop", default: "Listening · tap to stop")
    static let voiceHoldHint = AnchorStrings.value("setup.voice.hold.hint", default: "Hold to talk, or tap to start and stop")
    static let dropped = AnchorStrings.value("setup.dropped", default: "Anchor dropped: %@")
    static let saving = AnchorStrings.value("setup.plan.saving", default: "Saving…")
    static let saveFailed = AnchorStrings.value("setup.plan.save.failed", default: "Could not save this task. Your input is still here. Please try again.")
    static let removePhoto = AnchorStrings.value("setup.plan.photo.remove", default: "Remove image")
    static let photo = AnchorStrings.value("setup.plan.photo", default: "Reference image")
    static let doneEditing = AnchorStrings.value("setup.plan.edit.done", default: "Done editing")
    static let draftKept = AnchorStrings.value("setup.draft.kept", default: "Close and reopen to continue this draft.")
    static let discardDraft = AnchorStrings.value("setup.draft.discard", default: "Discard draft")
    static let discardDraftQuestion = AnchorStrings.value("setup.draft.discard.question", default: "Discard this draft?")

    static func split(_ count: Int) -> String {
        count == 1 ? splitOne : String(format: splitMany, count)
    }

    static func slideLabel(steps count: Int) -> String {
        switch count {
        case 0: slide
        case 1: slideOne
        default: String(format: slideMany, count)
        }
    }

    static func dropButton(steps count: Int) -> String {
        switch count {
        case 0: drop
        case 1: dropOne
        default: String(format: dropMany, count)
        }
    }
}
#endif
