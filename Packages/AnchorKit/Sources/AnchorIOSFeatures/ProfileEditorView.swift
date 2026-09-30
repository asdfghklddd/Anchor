#if os(iOS)
import AnchorDesign
import PhotosUI
import SwiftUI
import UIKit

struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("anchor.profile.name", store: ProfilePreferences.store) private var savedName = "ANDY"
    @AppStorage("anchor.profile.avatar", store: ProfilePreferences.store) private var savedAvatar = Data()
    @State private var name = ""
    @State private var avatar = Data()
    @State private var selection: PhotosPickerItem?
    @State private var loadError = false
    @State private var loading = false
    @State private var hasLoaded = false

    var body: some View {
        let avatarData = avatar
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $selection, matching: .images) {
                        HStack(spacing: 16) {
                            Group {
                                if let image = UIImage(data: avatarData) {
                                    Image(uiImage: image).resizable().scaledToFill()
                                } else { Image("DefaultProfileAvatar").resizable().scaledToFill() }
                            }
                            .frame(width: 64, height: 64).clipShape(.circle)
                            Text(AnchorStrings.value("profile.avatar.change", default: "Change avatar"))
                        }
                    }
                    .accessibilityIdentifier("profile.avatar.picker")
                    Button(AnchorStrings.value("profile.avatar.reset", default: "Use default avatar")) {
                        selection = nil
                        loading = false
                        loadError = false
                        avatar = Data()
                    }
                    TextField(AnchorStrings.value("profile.name", default: "Name"), text: $name)
                        .textContentType(.nickname)
                        .accessibilityIdentifier("profile.name.field")
                }
                .listRowBackground(AnchorIOSStyle.surface)
                if loadError { Text(L10n.actionFailed).foregroundStyle(.red) }
            }
            .anchorIOSListSurface()
            .navigationTitle(L10n.profile)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        savedName = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
                        savedAvatar = avatar
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loading)
                    .accessibilityIdentifier("profile.save.button")
                }
            }
            .onAppear {
                guard !hasLoaded else { return }
                name = savedName
                avatar = savedAvatar
                hasLoaded = true
            }
            .task(id: selection) {
                guard let selection else { return }
                loading = true
                defer { if self.selection == selection { loading = false } }
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self),
                          let image = UIImage(data: data),
                          let thumbnail = await image.byPreparingThumbnail(ofSize: CGSize(width: 512, height: 512)),
                          let encoded = thumbnail.jpegData(compressionQuality: 0.85) else {
                        if !Task.isCancelled, self.selection == selection { loadError = true }
                        return
                    }
                    guard !Task.isCancelled, self.selection == selection else { return }
                    avatar = encoded
                    loadError = false
                } catch { if !Task.isCancelled { loadError = true } }
            }
        }
    }
}
#endif
