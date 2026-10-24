#if os(iOS)
import AnchorDesign
import Foundation
import UIKit

/// iOS reports only "iPhone" as the device name to apps, so the person's
/// Anchor name tells their phone apart on the Mac.
public enum AnchorDeviceName {
    @MainActor
    public static func current() -> String {
        let system = UIDevice.current.name
        let model = UIDevice.current.localizedModel
        let owner = ProfilePreferences.store.string(forKey: "anchor.profile.name")?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard system == model, !owner.isEmpty, owner != "Anchor" else { return system }
        return String.localizedStringWithFormat(
            AnchorStrings.value("device.owner-name", default: "%1$@'s %2$@"), owner, model)
    }
}
#endif
