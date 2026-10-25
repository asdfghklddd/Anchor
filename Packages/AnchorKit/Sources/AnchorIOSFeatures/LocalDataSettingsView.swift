#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Starting over: clears tasks here and on the paired Mac. The name, pet,
/// reminders and pairing stay.
struct LocalDataSettingsView: View {
    let model: AnchorSessionModel

    private enum Reset: Identifiable {
        case anchors, everything
        var id: Self { self }
    }

    @State private var pending: Reset?
    @State private var isWorking = false
    @State private var finished: Reset?

    private var projection: SessionProjection { model.projection }
    private var anchorCount: Int { projection.hostedSessions.count }
    private var historyCount: Int { projection.archivedSessions.count }

    var body: some View {
        Form {
            Section {
                Button(role: .destructive) { pending = .anchors } label: {
                    row(LocalDataCopy.clearAnchors, detail: LocalDataCopy.anchorCount(anchorCount), symbol: "scope")
                }
                .disabled(anchorCount == 0 || isWorking)
                .accessibilityIdentifier("settings.data.clear-anchors")
            }
            .listRowBackground(AnchorIOSStyle.surface)

            Section {
                Button(role: .destructive) { pending = .everything } label: {
                    row(LocalDataCopy.clearEverything,
                        detail: LocalDataCopy.everythingCount(anchors: anchorCount, history: historyCount),
                        symbol: "trash")
                }
                .disabled(anchorCount + historyCount == 0 || isWorking)
                .accessibilityIdentifier("settings.data.clear-everything")
            }
            .listRowBackground(AnchorIOSStyle.surface)

            if let finished {
                Section {
                    Label(finished == .anchors ? LocalDataCopy.anchorsCleared : LocalDataCopy.everythingCleared,
                          systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AnchorPalette.mintInk)
                    if !projection.connection.isAuthenticatedAndHealthy {
                        Text(LocalDataCopy.macLater)
                            .font(.footnote)
                            .foregroundStyle(AnchorIOSStyle.secondaryText)
                    }
                }
                .listRowBackground(AnchorIOSStyle.surface)
                .accessibilityIdentifier("settings.data.done")
            }
        }
        .anchorIOSListSurface()
        .navigationTitle(LocalDataCopy.title)
        .confirmationDialog(
            pending == .everything ? LocalDataCopy.confirmEverythingTitle : LocalDataCopy.confirmAnchorsTitle,
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { reset in
            Button(reset == .everything ? LocalDataCopy.clearEverything : LocalDataCopy.clearAnchors,
                   role: .destructive) { perform(reset) }
            Button(L10n.cancel, role: .cancel) {}
        } message: { reset in
            Text(reset == .everything ? LocalDataCopy.confirmEverythingMessage : LocalDataCopy.confirmAnchorsMessage)
        }
    }

    private func row(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 32, height: 32)
                .background(Color.red.opacity(0.12), in: .rect(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(detail).font(.caption).foregroundStyle(AnchorIOSStyle.secondaryText)
            }
        }
        .frame(minHeight: 40)
    }

    private func perform(_ reset: Reset) {
        isWorking = true
        Task {
            defer { isWorking = false }
            guard let goals = await model.forgetTasks(includingHistory: reset == .everything) else { return }
            AnchorPlanImages.remove(goalIDs: goals.map(\.id))
            finished = reset
        }
    }
}

enum LocalDataCopy {
    static let title = AnchorStrings.value("settings.data", default: "Local Data")
    static let clearAnchors = AnchorStrings.value("settings.data.clear-anchors", default: "Clear Anchors")
    static let clearEverything = AnchorStrings.value("settings.data.clear-everything", default: "Clear All Local Data")
    static let confirmAnchorsTitle = AnchorStrings.value(
        "settings.data.confirm-anchors.title", default: "Clear all anchors?")
    static let confirmAnchorsMessage = AnchorStrings.value(
        "settings.data.confirm-anchors.message",
        default: "Your current tasks disappear from this iPhone and your Mac. This can't be undone.")
    static let confirmEverythingTitle = AnchorStrings.value(
        "settings.data.confirm-everything.title", default: "Clear all local data?")
    static let confirmEverythingMessage = AnchorStrings.value(
        "settings.data.confirm-everything.message",
        default: "Every task and all history disappear from this iPhone and your Mac. This can't be undone.")
    static let anchorsCleared = AnchorStrings.value("settings.data.anchors-cleared", default: "Anchors cleared")
    static let everythingCleared = AnchorStrings.value("settings.data.everything-cleared", default: "Local data cleared")
    static let macLater = AnchorStrings.value(
        "settings.data.mac-later", default: "Your Mac clears them the next time it connects.")

    static func anchorCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("settings.data.anchor-count", default: "%lld current tasks"), count)
    }

    static func everythingCount(anchors: Int, history: Int) -> String {
        String.localizedStringWithFormat(
            AnchorStrings.value("settings.data.everything-count", default: "%1$lld current · %2$lld in history"),
            anchors, history)
    }
}
#endif
