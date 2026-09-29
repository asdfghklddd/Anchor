#if os(iOS)
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
#endif
