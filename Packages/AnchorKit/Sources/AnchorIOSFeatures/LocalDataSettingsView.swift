#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Starting over: clears tasks here and on the paired Mac, takes the Mac's
/// copy instead, or lets the pets forget. The name, reminders and pairing stay.
struct LocalDataSettingsView: View {
    let model: AnchorSessionModel

    private enum Reset: Identifiable {
        case anchors, everything, fromMac, petMemory
        var id: Self { self }

        var action: String {
            switch self {
            case .anchors: LocalDataCopy.clearAnchors
            case .everything: LocalDataCopy.clearEverything
            case .fromMac: LocalDataCopy.fromMac
            case .petMemory: DeskPetCopy.resetAction
            }
        }

        var confirmTitle: String {
            switch self {
            case .anchors: LocalDataCopy.confirmAnchorsTitle
            case .everything: LocalDataCopy.confirmEverythingTitle
            case .fromMac: LocalDataCopy.confirmFromMacTitle
            case .petMemory: DeskPetCopy.resetTitle
            }
        }

        var confirmMessage: String {
            switch self {
            case .anchors: LocalDataCopy.confirmAnchorsMessage
            case .everything: LocalDataCopy.confirmEverythingMessage
            case .fromMac: LocalDataCopy.confirmFromMacMessage
            case .petMemory: DeskPetCopy.resetMessage
            }
        }
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

            Section {
                Button(role: .destructive) { pending = .fromMac } label: {
                    row(LocalDataCopy.fromMac,
                        detail: projection.awaitsPeerCopy ? LocalDataCopy.fromMacWaiting : LocalDataCopy.fromMacDetail,
                        symbol: "arrow.triangle.2.circlepath")
                }
                .disabled(projection.awaitsPeerCopy || isWorking)
                .accessibilityIdentifier("settings.data.from-mac")
            }
            .listRowBackground(AnchorIOSStyle.surface)

            Section {
                Button(role: .destructive) { pending = .petMemory } label: {
                    row(DeskPetCopy.reset, detail: DeskPetCopy.resetDetail, symbol: "pawprint")
                }
                .disabled(isWorking)
                .accessibilityIdentifier("settings.deskPet.reset")
            }
            .listRowBackground(AnchorIOSStyle.surface)

            if let finished, let message = doneMessage(finished) {
                Section {
                    Label(message, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(AnchorPalette.mintInk)
                    if finished != .petMemory, !projection.connection.isAuthenticatedAndHealthy {
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
        .sensoryFeedback(.success, trigger: finished)
        .confirmationDialog(
            pending?.confirmTitle ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { reset in
            Button(reset.action, role: .destructive) { perform(reset) }
            Button(L10n.cancel, role: .cancel) {}
        } message: { reset in
            Text(reset.confirmMessage)
        }
    }

    private func doneMessage(_ reset: Reset) -> String? {
        switch reset {
        case .anchors: LocalDataCopy.anchorsCleared
        case .everything: LocalDataCopy.everythingCleared
        case .petMemory: DeskPetCopy.resetDone
        case .fromMac: nil
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
            if reset == .petMemory {
                DeskPetLife.shared.forgetAll()
                finished = reset
                return
            }
            if reset == .fromMac {
                // The tasks come back from the Mac with their plan images; the row says it waits.
                if await model.awaitPeerCopy() { finished = reset }
                return
            }
            guard let goals = await model.forgetTasks(includingHistory: reset == .everything) else { return }
            AnchorPlanImages.remove(goalIDs: goals.map(\.id))
            finished = reset
        }
    }
}

enum DeskPetCopy {
    static let reset = AnchorStrings.value("settings.deskPet.reset", default: "Reset Pet Memory")
    static let resetDetail = AnchorStrings.value("settings.deskPet.reset.detail", default: "Trust, habits, what it found, and the plant")
    static let resetDone = AnchorStrings.value("settings.deskPet.reset.done", default: "Pet memory reset")
    static let resetTitle = AnchorStrings.value("settings.deskPet.reset.title", default: "Reset pet memory?")
    static let resetMessage = AnchorStrings.value(
        "settings.deskPet.reset.message",
        default: "Every pet forgets its time with you: trust, habits, the things it found and the plant all start over. This can't be undone.")
    static let resetAction = AnchorStrings.value("settings.deskPet.reset.action", default: "Reset")
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
    static let fromMac = AnchorStrings.value("settings.data.from-mac", default: "Sync Again from Mac")
    static let fromMacDetail = AnchorStrings.value(
        "settings.data.from-mac.detail", default: "Empty this iPhone, then take everything on your Mac")
    static let fromMacWaiting = AnchorStrings.value(
        "settings.data.from-mac.waiting", default: "Emptied · waiting for your Mac to connect again")
    static let confirmFromMacTitle = AnchorStrings.value(
        "settings.data.confirm-from-mac.title", default: "Sync again from your Mac?")
    static let confirmFromMacMessage = AnchorStrings.value(
        "settings.data.confirm-from-mac.message",
        default: "This iPhone empties now. The next time your Mac connects, it sends every task and all history it has. Your Mac doesn't change.")
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
