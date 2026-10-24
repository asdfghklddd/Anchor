#if os(iOS)
import AnchorCore
import SwiftUI
import UIKit

/// iOS visual tokens derived from the approved Figma homepage (204:573).
public enum AnchorIOSStyle {
    // Every value resolves through AnchorColorTokens, shared with the Mac.
    public static let canvasTop = Color(AnchorColorTokens.canvasTop)
    public static let canvasBottom = Color(AnchorColorTokens.canvasBottom)
    public static let landscapeCanvasLeading = Color(AnchorColorTokens.landscapeCanvasLeading)
    public static let landscapeCanvasTrailing = Color(AnchorColorTokens.landscapeCanvasTrailing)
    public static let surface = Color(AnchorColorTokens.surface)
    public static let heading = Color(AnchorColorTokens.heading)
    public static let cyan = Color(AnchorColorTokens.brand)
    /// Former attention yellow; now the attention fill. Identity no longer uses it.
    public static let yellow = Color(AnchorColorTokens.attentionFill)
    /// Readable attention text and symbols.
    public static let attentionInk = Color(AnchorColorTokens.attentionInk)
    public static let text = Color(AnchorColorTokens.text)
    public static let secondaryText = Color(AnchorColorTokens.textSecondary)
    public static let action = Color(AnchorColorTokens.action)
    public static let onAction = Color(AnchorColorTokens.onAction)
    public static let onAccent = Color(AnchorColorTokens.onBrand)
    public static let success = Color(AnchorColorTokens.doneInk)
    public static let border = Color(AnchorColorTokens.border)
    public static let cardRadius: CGFloat = 16
    public static let heroRadius: CGFloat = 20
    public static let pageInset: CGFloat = 20
    public static let pink = Color(AnchorColorTokens.identity[2])
    public static let violet = Color(AnchorColorTokens.identity[3])
    /// Launch harbor water: the surface tint and the depth it fades into.
    public static let oceanSurface = Color(AnchorColorTokens.oceanSurface)
    public static let oceanDeep = Color(AnchorColorTokens.oceanDeep)

    public static var background: LinearGradient {
        LinearGradient(colors: [canvasTop, canvasBottom], startPoint: .top, endPoint: .bottom)
    }

    /// The landscape desk follows its separately approved, horizontal Figma canvas.
    public static var landscapeBackground: LinearGradient {
        LinearGradient(colors: [landscapeCanvasLeading, landscapeCanvasTrailing], startPoint: .leading, endPoint: .trailing)
    }

    public static func tint(for process: AnchorProcess) -> Color {
        AnchorPalette.source(process.sourceTone)
    }
}
#endif
