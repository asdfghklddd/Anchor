#if os(iOS)
import SwiftUI

public struct HarborLaunchSplash: View {
    let logoIsVisible: Bool
    let wordmarkIsVisible: Bool

    public init(logoIsVisible: Bool, wordmarkIsVisible: Bool) {
        self.logoIsVisible = logoIsVisible
        self.wordmarkIsVisible = wordmarkIsVisible
    }

    public var body: some View {
        VStack(spacing: 4) {
            HarborBrandMark(size: 112)
                .opacity(logoIsVisible ? 1 : 0)
                .scaleEffect(logoIsVisible ? 1 : 0.94)
                .offset(y: logoIsVisible ? 0 : 12)

            Text("ANCHOR")
                .font(.caption.bold())
                .tracking(4)
                .foregroundStyle(AnchorIOSStyle.heading)
                .opacity(wordmarkIsVisible ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { HarborBackground() }
        .accessibilityHidden(true)
    }
}
#endif
