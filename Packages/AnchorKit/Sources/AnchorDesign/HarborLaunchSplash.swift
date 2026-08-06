#if os(iOS)
import SwiftUI
import UIKit

public struct HarborLaunchSplash: View {
    private static let logoImage: UIImage? = {
        guard let url = Bundle.module.url(
            forResource: "AnchorSplashLogo",
            withExtension: "png"
        ) else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }()

    let logoIsVisible: Bool
    let wordmarkIsVisible: Bool

    public init(logoIsVisible: Bool, wordmarkIsVisible: Bool) {
        self.logoIsVisible = logoIsVisible
        self.wordmarkIsVisible = wordmarkIsVisible
    }

    public var body: some View {
        VStack(spacing: 4) {
            Color.clear
                .frame(width: 220, height: 190)
                .overlay(alignment: .topLeading) {
                    if let logoImage = Self.logoImage {
                        Image(uiImage: logoImage)
                            .resizable()
                            .frame(width: 270, height: 405)
                            .offset(x: -25, y: -105)
                    }
                }
                .clipped()
                .opacity(logoIsVisible ? 1 : 0)
                .scaleEffect(logoIsVisible ? 1 : 0.94)
                .offset(y: logoIsVisible ? 0 : 12)

            Text("ANCHOR")
                .font(.caption.bold())
                .tracking(4)
                .foregroundStyle(.white.opacity(0.82))
                .opacity(wordmarkIsVisible ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.027, green: 0.106, blue: 0.180))
        .accessibilityHidden(true)
    }
}
#endif
