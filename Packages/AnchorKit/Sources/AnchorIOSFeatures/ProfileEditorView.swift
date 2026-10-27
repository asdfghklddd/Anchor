#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// Settings: the profile, then the work-style pages, which push inside this sheet.
struct ProfileEditorView<Destination: View>: View {
    let projection: SessionProjection
    @ViewBuilder let destination: (AnchorRoute) -> Destination

    @Environment(\.dismiss) private var dismiss
    @AppStorage("anchor.profile.name", store: ProfilePreferences.store) private var savedName = "Anchor"
    @State private var name = ""
    @State private var hasLoaded = false
    /// Applies at once; Save only stores the name.
    @AppStorage(DeskPetKind.defaultsKey, store: ProfilePreferences.store) private var petKind = DeskPetKind.crab
    @State private var confirmsPetReset = false
    @State private var petResets = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(AnchorStrings.value("profile.name", default: "Name"), text: $name)
                        .textContentType(.nickname)
                        .accessibilityIdentifier("profile.name.field")
                }
                .listRowBackground(AnchorIOSStyle.surface)
                deskPetSection
                workStyleSection
                Section {
                    NavigationLink(value: AnchorRoute.localData) {
                        row(LocalDataCopy.title, symbol: "externaldrive")
                    }
                    .accessibilityIdentifier("settings.data")
                }
                .listRowBackground(AnchorIOSStyle.surface)
            }
            .anchorIOSListSurface()
            .navigationTitle(L10n.settings)
            .navigationDestination(for: AnchorRoute.self) { destination($0) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        savedName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("profile.save.button")
                }
            }
            .onAppear {
                guard !hasLoaded else { return }
                name = savedName
                hasLoaded = true
            }
        }
    }

    private var deskPetSection: some View {
        Section {
            DeskPetPicker(selection: $petKind)
                .padding(.vertical, 6)
            Button(role: .destructive) { confirmsPetReset = true } label: {
                Text(DeskPetCopy.reset)
            }
            .accessibilityIdentifier("settings.deskPet.reset")
            .sensoryFeedback(.success, trigger: petResets)
            .confirmationDialog(DeskPetCopy.resetTitle, isPresented: $confirmsPetReset, titleVisibility: .visible) {
                Button(DeskPetCopy.resetAction, role: .destructive) {
                    DeskPetLife.shared.forgetAll()
                    petResets += 1
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(DeskPetCopy.resetMessage)
            }
        } header: {
            Text(AnchorStrings.value("settings.deskPet", default: "Desk pet"))
                .textCase(.uppercase)
        }
        .listRowBackground(AnchorIOSStyle.surface)
    }

    private var workStyleSection: some View {
        Section(L10n.workStyle) {
            row(AnchorStrings.value("settings.icloud", default: "iCloud Sync"), symbol: "icloud",
                value: projection.durableSyncState.label)
                .accessibilityIdentifier("settings.icloud")
            NavigationLink(value: AnchorRoute.connections) {
                row(L10n.connections, symbol: "macbook.and.iphone", value: connectionValue)
            }
            .accessibilityIdentifier("settings.connections")
            NavigationLink(value: AnchorRoute.sources) {
                row(L10n.sources, symbol: "point.3.connected.trianglepath.dotted", value: sourcesValue)
            }
            .accessibilityIdentifier("settings.sources")
        }
        .listRowBackground(AnchorIOSStyle.surface)
    }

    /// The Mac's name while it is connected; otherwise that it is not.
    private var connectionValue: String {
        guard projection.connection == .connected else { return PeerDeviceCopy.notConnected }
        return PeerDeviceMemory.last()?.displayName ?? PeerDeviceCopy.connected
    }

    /// The agents heard from most recently.
    private var sourcesValue: String? {
        let names = SourceGroup.all(in: projection).prefix(2).map(\.name)
        return names.isEmpty ? nil : names.joined(separator: " · ")
    }

    private func row(_ title: String, symbol: String, value: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(AnchorPalette.interaction)
                .frame(width: 32, height: 32)
                .background(AnchorPalette.softBlue.opacity(0.62), in: .rect(cornerRadius: 9))
            Text(title).font(.subheadline.bold()).foregroundStyle(AnchorPalette.ink)
            if let value {
                Spacer(minLength: 8)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: 40)
        .accessibilityElement(children: .combine)
    }
}

enum DeskPetCopy {
    static let reset = AnchorStrings.value("settings.deskPet.reset", default: "Reset Pet Memory")
    static let resetTitle = AnchorStrings.value("settings.deskPet.reset.title", default: "Reset pet memory?")
    static let resetMessage = AnchorStrings.value(
        "settings.deskPet.reset.message",
        default: "Every pet forgets its time with you: trust, habits, the things it found and the plant all start over. This can't be undone.")
    static let resetAction = AnchorStrings.value("settings.deskPet.reset.action", default: "Reset")
}

private extension DurableSyncState {
    var label: String {
        switch self {
        case .notConfigured: AnchorStrings.value("sync.state.notConfigured", default: "Not configured")
        case .idle: AnchorStrings.value("sync.state.idle", default: "Waiting to sync")
        case .syncing: AnchorStrings.value("sync.state.syncing", default: "Syncing")
        case .available: AnchorStrings.value("sync.state.available", default: "Last sync succeeded")
        case .offline: AnchorStrings.value("sync.state.offline", default: "Offline")
        case .failed: AnchorStrings.value("sync.state.failed", default: "Sync failed")
        }
    }
}
#endif
