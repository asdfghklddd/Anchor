#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Reads and saves the recap model's API key; the app backs it with the Keychain.
public struct MacModelKeyAccess: Sendable {
    public let load: @Sendable () -> String?
    public let save: @Sendable (String) -> Bool

    public init(load: @escaping @Sendable () -> String?, save: @escaping @Sendable (String) -> Bool) {
        self.load = load
        self.save = save
    }
}

/// The DeepSeek key that writes the return page's conversation recaps. The
/// field never shows a saved key back; it only says whether one is set.
struct MacRecapKeySection: View {
    let access: MacModelKeyAccess
    @State private var draft = ""
    @State private var hasKey = false
    @State private var failed = false

    var body: some View {
        Section {
            LabeledContent(MacRecapCopy.state) {
                Label(hasKey ? MacRecapCopy.keySet : MacRecapCopy.keyMissing,
                      systemImage: hasKey ? "checkmark.circle.fill" : "key")
                    .foregroundStyle(hasKey ? AnchorPalette.seafoam : AnchorPalette.secondaryInk)
            }
            HStack {
                SecureField(MacRecapCopy.field, text: $draft)
                    .textContentType(.password)
                    .onSubmit(save)
                Button(MacRecapCopy.save, action: save)
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                if hasKey {
                    Button(MacRecapCopy.remove, role: .destructive) {
                        if access.save("") { hasKey = false }
                    }
                }
            }
            Text(failed ? MacRecapCopy.failed : MacRecapCopy.detail)
                .font(.caption)
                .foregroundStyle(failed ? AnchorPalette.coral : .secondary)
                .fixedSize(horizontal: false, vertical: true)
        } header: {
            Text(MacRecapCopy.title)
        }
        .accessibilityIdentifier("settings.recapKey")
        .task { hasKey = access.load() != nil }
    }

    private func save() {
        let key = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        failed = !access.save(key)
        if !failed {
            hasKey = true
            draft = ""
        }
    }
}

enum MacRecapCopy {
    static let title = AnchorStrings.value("mac.recap.title", default: "Return recaps")
    static let state = AnchorStrings.value("mac.recap.state", default: "DeepSeek key")
    static let keySet = AnchorStrings.value("mac.recap.keySet", default: "Saved in Keychain")
    static let keyMissing = AnchorStrings.value("mac.recap.keyMissing", default: "Not set")
    static let field = AnchorStrings.value("mac.recap.field", default: "Paste API key")
    static let save = AnchorStrings.value("mac.recap.save", default: "Save")
    static let remove = AnchorStrings.value("mac.recap.remove", default: "Remove")
    static let detail = AnchorStrings.value(
        "mac.recap.detail",
        default: "When your iPhone comes back after five minutes away, this Mac sends the last five rounds of each task's newest conversations to DeepSeek and shows a short recap of each on the phone. Without a key, the recap is the latest request."
    )
    static let failed = AnchorStrings.value("mac.recap.failed", default: "The key couldn’t be saved to the Keychain.")
}
#endif
