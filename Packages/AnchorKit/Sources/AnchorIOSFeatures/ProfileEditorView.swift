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
    @State private var showsICloud = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(AnchorStrings.value("profile.name", default: "Name"), text: $name)
                        .textContentType(.nickname)
                        .accessibilityIdentifier("profile.name.field")
                }
                .listRowBackground(AnchorIOSStyle.surface)
                workStyleSection
            }
            .anchorIOSListSurface()
            .navigationTitle(L10n.settings)
            .navigationDestination(for: AnchorRoute.self) { destination($0) }
            .sheet(isPresented: $showsICloud) {
                ProfileInfoSheet(kind: .icloud, projection: projection)
                    .presentationDetents([.large])
            }
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

    private var workStyleSection: some View {
        Section(L10n.workStyle) {
            NavigationLink(value: AnchorRoute.taskManagement) { row(L10n.taskManagement, symbol: "square.grid.2x2") }
            Button { showsICloud = true } label: {
                HStack {
                    row(AnchorStrings.value("settings.icloud", default: "iCloud Sync"), symbol: "icloud")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                }
            }
            NavigationLink(value: AnchorRoute.connections) { row(L10n.connections, symbol: "macbook.and.iphone") }
            NavigationLink(value: AnchorRoute.sources) { row(L10n.sources, symbol: "point.3.connected.trianglepath.dotted") }
            NavigationLink(value: AnchorRoute.notificationSettings) { row(L10n.notificationsSettings, symbol: "bell") }
            NavigationLink(value: AnchorRoute.privacy) { row(L10n.privacy, symbol: "hand.raised") }
            NavigationLink(value: AnchorRoute.accessibility) { row(L10n.accessibility, symbol: "accessibility") }
        }
        .listRowBackground(AnchorIOSStyle.surface)
    }

    private func row(_ title: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(AnchorPalette.interaction)
                .frame(width: 32, height: 32)
                .background(AnchorPalette.softBlue.opacity(0.62), in: .rect(cornerRadius: 9))
            Text(title).font(.subheadline.bold()).foregroundStyle(AnchorPalette.ink)
        }
        .frame(minHeight: 40)
    }
}
#endif
