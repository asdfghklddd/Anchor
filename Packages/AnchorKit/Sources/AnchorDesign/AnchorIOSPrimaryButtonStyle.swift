#if os(iOS)
import SwiftUI

/// A flat cyan action shared by all iOS primary buttons.
public struct AnchorIOSPrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        AnchorIOSButtonSurface(configuration: configuration)
    }
}
#endif
