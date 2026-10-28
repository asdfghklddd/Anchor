#if os(macOS)
import AppKit
import SwiftUI

/// Deep frosted glass. Closed, it is nearly black so it joins the housing
/// without a seam; open, the tint thins and the blur and grain show through.
/// Reduce Transparency turns it solid; Increase Contrast darkens it and
/// brightens its edge.
struct NotchIslandSurface: View {
    let flare: CGFloat
    let radius: CGFloat
    let isOpen: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let shape = NotchIslandShape(flare: flare, radius: radius)
        ZStack {
            if reduceTransparency {
                Color(white: 0.086)
            } else {
                NotchBackdropBlur()
                Color.black.opacity(tint)
                Image(decorative: NotchGrain.image, scale: 2)
                    .resizable(resizingMode: .tile)
                    .blendMode(.plusLighter)
                    .opacity(isOpen ? 0.06 : 0.02)
            }
        }
        .clipShape(shape)
        .overlay {
            NotchIslandShape(flare: flare, radius: radius, isOutline: true)
                .stroke(.white.opacity(edgeOpacity), lineWidth: contrast == .increased ? 1 : 0.5)
        }
    }

    private var tint: Double {
        if contrast == .increased { return 0.96 }
        return isOpen ? 0.74 : 0.94
    }

    private var edgeOpacity: Double {
        if contrast == .increased { return 0.32 }
        return isOpen ? 0.12 : 0.06
    }
}

/// The desktop behind the island, blurred. Always active, since the island
/// never takes focus from the person's app.
private struct NotchBackdropBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// A fixed tile of fine noise, the frost on the glass.
enum NotchGrain {
    static let image: CGImage = {
        let side = 128
        var bytes = [UInt8](repeating: 0, count: side * side)
        // A fixed seed keeps the grain identical between launches.
        var seed: UInt32 = 0x9E37_79B9
        for index in bytes.indices {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            bytes[index] = UInt8(truncatingIfNeeded: seed >> 24)
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: side,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }()
}
#endif
