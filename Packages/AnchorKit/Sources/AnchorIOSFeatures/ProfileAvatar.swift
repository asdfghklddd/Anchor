#if os(iOS)
import AnchorDesign
import PhotosUI
import SwiftUI
import UIKit

/// Shared local profile; user-selected photos never enter task synchronization.
struct ProfileAvatar: View {
    var size: CGFloat = 48
    @AppStorage("anchor.profile.avatar", store: ProfilePreferences.store) private var avatarData = Data()

    var body: some View {
        Group {
            if let image = UIImage(data: avatarData) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image("DefaultProfileAvatar").resizable().scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }
}

/// Tappable avatar on the Me page: picks a photo and saves it immediately.
/// Long-press offers going back to the default avatar.
struct ProfileAvatarButton: View {
    var size: CGFloat = 56
    @AppStorage("anchor.profile.avatar", store: ProfilePreferences.store) private var avatarData = Data()
    @State private var selection: PhotosPickerItem?
    @State private var loading = false
    @State private var loadError = false

    var body: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            ProfileAvatar(size: size)
                .overlay {
                    Circle().stroke(.white.opacity(0.9), lineWidth: 2)
                }
                .overlay {
                    if loading {
                        Circle().fill(.black.opacity(0.28))
                        ProgressView().tint(.white)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: size * 0.18, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: size * 0.38, height: size * 0.38)
                        .background(AnchorPalette.interaction, in: .circle)
                        .overlay { Circle().stroke(.white, lineWidth: 2) }
                        .offset(x: 2, y: 2)
                }
                .shadow(color: AnchorPalette.brandDeep.opacity(0.18), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(loading)
        .contextMenu {
            if !avatarData.isEmpty {
                Button(AnchorStrings.value("profile.avatar.reset", default: "Use default avatar"), systemImage: "arrow.uturn.backward") {
                    selection = nil
                    avatarData = Data()
                }
            }
        }
        .accessibilityLabel(AnchorStrings.value("profile.avatar.change", default: "Change avatar"))
        .accessibilityIdentifier("profile.avatar.picker")
        .alert(L10n.actionFailed, isPresented: $loadError) {}
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
                avatarData = encoded
            } catch { if !Task.isCancelled { loadError = true } }
        }
    }
}
#endif
