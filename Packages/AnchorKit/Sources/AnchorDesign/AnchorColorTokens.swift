import AnchorCore
import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// One light/dark color value. Every Anchor color on iPhone and Mac comes from
/// a token in `AnchorColorTokens`.
public struct AnchorColorToken: Hashable, Sendable {
    public let name: String
    public let light: UInt32
    public let dark: UInt32

    public init(_ name: String, light: UInt32, dark: UInt32) {
        self.name = name
        self.light = light
        self.dark = dark
    }
}

/// The single source of Anchor's colors, shared by iPhone and Mac.
///
/// Three jobs, never mixed:
/// - **Surface, text and brand** build the harbor.
/// - **State** (running, attention, failed, done) is the only
///   color that carries status. Each state has a `fill` for shapes (at least
///   3:1 on `surface`) and an `ink` for text (at least 4.5:1).
/// - **Identity** tells hosted tasks apart. Its hues stay away from every
///   state hue, and a task's color always appears next to its name.
///
/// Contrast rules are enforced by `AnchorColorTokenTests`.
public enum AnchorColorTokens {
    // MARK: Surfaces

    /// Top of the harbor gradient, and the Mac window background.
    public static let canvasTop = AnchorColorToken("canvasTop", light: 0xEAF6F9, dark: 0x101F29)
    /// Bottom of the harbor gradient.
    public static let canvasBottom = AnchorColorToken("canvasBottom", light: 0xD2F7FC, dark: 0x123641)
    /// Leading edge of the iPhone landscape desk, matching the approved Figma reference.
    /// This stays separate from the shared portrait harbor canvas.
    public static let landscapeCanvasLeading = AnchorColorToken("landscapeCanvasLeading", light: 0xFAFDFF, dark: 0x101F29)
    /// Trailing edge of the iPhone landscape desk, matching the approved Figma reference.
    public static let landscapeCanvasTrailing = AnchorColorToken("landscapeCanvasTrailing", light: 0xD4F7FF, dark: 0x123641)
    // MARK: Portrait home (the owner's mockup, 2026-10-27)

    /// The home's water: this color at the top, `homeCanvasDeep` at twice the screen's height.
    public static let homeCanvasTop = AnchorColorToken("homeCanvasTop", light: 0xFAFDFF, dark: 0x0E1C25)
    public static let homeCanvasDeep = AnchorColorToken("homeCanvasDeep", light: 0xADF1FF, dark: 0x16465A)
    /// The crest of the anchoring dome; it fades into the water below.
    public static let homeDome = AnchorColorToken("homeDome", light: 0x99F3FF, dark: 0x1D5B70)
    /// Names, the greeting, the clock and the goal.
    public static let homeInk = AnchorColorToken("homeInk", light: 0x26599D, dark: 0xB5DBFF)
    /// Task names on the home's cards.
    public static let homeCardTitle = AnchorColorToken("homeCardTitle", light: 0x2A4985, dark: 0xDFEFF5)
    /// Discs behind the avatar and the settings button.
    public static let homeDisc = AnchorColorToken("homeDisc", light: 0x97E7F5, dark: 0x24576A)
    /// The greeting's second line.
    public static let homeQuiet = AnchorColorToken("homeQuiet", light: 0xB1B1B1, dark: 0x8A9BA5)
    /// "Synced just now".
    public static let homeSynced = AnchorColorToken("homeSynced", light: 0x949494, dark: 0x8A9BA5)
    /// The Mac link's pill text and icon.
    public static let homeLinked = AnchorColorToken("homeLinked", light: 0x65C466, dark: 0x5FD36A)
    /// Token bars and their hour marks.
    public static let homeTokens = AnchorColorToken("homeTokens", light: 0x63D4FA, dark: 0x4FC6EE)
    /// A half hour already past with no tokens.
    public static let homeSlotPast = AnchorColorToken("homeSlotPast", light: 0xFFFFFF, dark: 0x3A6273)
    /// A half hour still ahead.
    public static let homeSlotAhead = AnchorColorToken("homeSlotAhead", light: 0xCFDDE0, dark: 0x24404C)
    /// The anchor button.
    public static let homeAnchor = AnchorColorToken("homeAnchor", light: 0x10D7FF, dark: 0x1AA9C9)
    /// The clock once today's goal is reached.
    public static let homeDone = AnchorColorToken("homeDone", light: 0x56A66C, dark: 0x6CC487)
    /// The jellyfish's bubbles.
    public static let homeBubble = AnchorColorToken("homeBubble", light: 0x79C8DF, dark: 0x6FC3DC)
    /// The pin around the person's avatar on the task they are on.
    public static let homePin = AnchorColorToken("homePin", light: 0x4597F7, dark: 0x5AA5F8)
    /// The task library: its panel, its title, and the text on its cards.
    public static let homeLibrary = AnchorColorToken("homeLibrary", light: 0xFBFFFE, dark: 0x1A2E38)
    public static let homeLibraryTitle = AnchorColorToken("homeLibraryTitle", light: 0x335898, dark: 0xB5DBFF)
    public static let homeCardText = AnchorColorToken("homeCardText", light: 0x201E20, dark: 0xEAF2F5)
    public static let homeCardNote = AnchorColorToken("homeCardNote", light: 0x9E9B9E, dark: 0x9AA9B1)
    /// Task marks on the home, in the landscape tabs' order (amber, cyan, pink),
    /// each with the pale wash a card takes when the task waits on the person.
    public static let homeTasks: [AnchorColorToken] = [
        AnchorColorToken("homeTaskAmber", light: 0xF2A53A, dark: 0xF2A53A),
        AnchorColorToken("homeTaskCyan", light: 0x6FC5FA, dark: 0x6FC5FA),
        AnchorColorToken("homeTaskPink", light: 0xED72D7, dark: 0xED72D7),
    ]
    public static let homeTaskWashes: [AnchorColorToken] = [
        AnchorColorToken("homeTaskAmberWash", light: 0xFDF6E3, dark: 0x3A3322),
        AnchorColorToken("homeTaskCyanWash", light: 0xEEF8FE, dark: 0x1F3A4A),
        AnchorColorToken("homeTaskPinkWash", light: 0xFCEFFA, dark: 0x3A2436),
    ]

    /// Cards, rows, sheets and form fields.
    public static let surface = AnchorColorToken("surface", light: 0xFFFFFF, dark: 0x20343E)
    /// Selected rows and soft highlights; usually drawn with opacity.
    public static let selection = AnchorColorToken("selection", light: 0xBFEBF6, dark: 0x24505F)
    /// Decorative hairlines and separators.
    public static let border = AnchorColorToken("border", light: 0xDCECF0, dark: 0x3C5662)
    /// Boundaries a person must see to use a control (3:1 on surface).
    public static let borderStrong = AnchorColorToken("borderStrong", light: 0x7F94A1, dark: 0x7E97A4)

    // MARK: Text

    public static let text = AnchorColorToken("text", light: 0x183F52, dark: 0xDFEFF5)
    public static let textSecondary = AnchorColorToken("textSecondary", light: 0x526979, dark: 0xB6CAD5)
    public static let heading = AnchorColorToken("heading", light: 0x315E8B, dark: 0xB5E2F6)
    /// Links, navigation and control tints.
    public static let action = AnchorColorToken("action", light: 0x176E87, dark: 0x87DCEC)
    /// Text and icons on an `action` fill.
    public static let onAction = AnchorColorToken("onAction", light: 0xFFFFFF, dark: 0x123F52)

    // MARK: Brand

    /// Harbor cyan: primary buttons, the anchor button and brand fills.
    public static let brand = AnchorColorToken("brand", light: 0x36D1ED, dark: 0x289CB8)
    /// Text and icons on a `brand` fill.
    public static let onBrand = AnchorColorToken("onBrand", light: 0x123F52, dark: 0x082C38)
    /// Launch harbor water.
    public static let oceanSurface = AnchorColorToken("oceanSurface", light: 0x6FD8EF, dark: 0x1E6F86)
    public static let oceanDeep = AnchorColorToken("oceanDeep", light: 0x2A8FC7, dark: 0x0B2B3A)

    // MARK: State

    public static let runningFill = AnchorColorToken("runningFill", light: 0x1E9A5A, dark: 0x4CC98A)
    public static let runningInk = AnchorColorToken("runningInk", light: 0x16794A, dark: 0x7FDCA7)
    public static let attentionFill = AnchorColorToken("attentionFill", light: 0xC98500, dark: 0xF2C14E)
    public static let attentionInk = AnchorColorToken("attentionInk", light: 0x8A5A00, dark: 0xF2D16B)
    public static let failedFill = AnchorColorToken("failedFill", light: 0xD92D20, dark: 0xFF6B5E)
    public static let failedInk = AnchorColorToken("failedInk", light: 0xB42318, dark: 0xFF9C92)
    public static let doneFill = AnchorColorToken("doneFill", light: 0x26764D, dark: 0x8DDDAD)
    public static let doneInk = AnchorColorToken("doneInk", light: 0x26764D, dark: 0x8DDDAD)

    // MARK: Identity

    /// Hosted-task colors in assignment order. Hues avoid red, amber and green.
    public static let identity: [AnchorColorToken] = [
        AnchorColorToken("identityBlue", light: 0x4F7CF0, dark: 0x7C9DF5),
        AnchorColorToken("identityCyan", light: 0x14ADCF, dark: 0x289CB8),
        AnchorColorToken("identityPink", light: 0xE967D3, dark: 0xD986CB),
        AnchorColorToken("identityViolet", light: 0x8B7CF6, dark: 0xA197F2),
        AnchorColorToken("identityTeal", light: 0x1FB5A5, dark: 0x3CC2B2)
    ]
    /// Generated identities stay inside this hue band (degrees), clear of state hues.
    public static let identityHueBand: ClosedRange<Double> = 180...318

    // MARK: iPhone landscape task tabs

    /// The approved three-color Figma palette for the header tab of a task card
    /// in the iPhone landscape desk. It is intentionally separate from task
    /// identity and state colors used elsewhere in the product.
    public static let landscapeTaskTabs: [AnchorColorToken] = [
        AnchorColorToken("landscapeTaskTabAmber", light: 0xFFB400, dark: 0xFFB400),
        AnchorColorToken("landscapeTaskTabCyan", light: 0x49C8FF, dark: 0x49C8FF),
        AnchorColorToken("landscapeTaskTabPink", light: 0xFF69DC, dark: 0xFF69DC)
    ]
    /// Deep ink that remains readable on every approved landscape task-tab fill.
    public static let onLandscapeTaskTab = AnchorColorToken("onLandscapeTaskTab", light: 0x123B54, dark: 0x123B54)

    /// There are deliberately only three approved landscape tab colors today.
    /// More task cards repeat this sequence until the owner adds and maps another
    /// approved tab color; this avoids inventing an unreviewed fourth hue.
    public static func landscapeTaskTab(index: Int) -> AnchorColorToken {
        landscapeTaskTabs[max(0, index) % landscapeTaskTabs.count]
    }

    // MARK: Decorative

    /// Fixed artwork colors that do not change with appearance.
    public static let seafoam: UInt32 = 0x91DEC4
    public static let deepSea: UInt32 = 0x123B54
    public static let oceanHighlight: UInt32 = 0xA8EDE3

    public static let all: [AnchorColorToken] = [
        canvasTop, canvasBottom, landscapeCanvasLeading, landscapeCanvasTrailing,
        surface, selection, border, borderStrong,
        text, textSecondary, heading, action, onAction,
        brand, onBrand, oceanSurface, oceanDeep,
        runningFill, runningInk, attentionFill, attentionInk, failedFill, failedInk,
        doneFill, doneInk, onLandscapeTaskTab,
        homeCanvasTop, homeCanvasDeep, homeDome, homeInk, homeCardTitle, homeDisc, homeQuiet, homeSynced,
        homeLinked, homeTokens, homeSlotPast, homeSlotAhead, homeAnchor, homeDone, homeBubble,
        homeLibrary, homeLibraryTitle, homeCardText, homeCardNote, homePin
    ] + homeTasks + homeTaskWashes + identity + landscapeTaskTabs
}

/// The state colors as one vocabulary. Shapes use `fill`, words use `ink`.
/// A stop the person made is `attention` (D02) and is told apart by its pause
/// symbol; unknown or not-yet-reported work stays neutral, outside this enum.
public enum AnchorStateTone: Hashable, Sendable {
    case running
    case attention
    case failed
    case done

    public init(_ state: TideState) {
        switch state {
        case .running: self = .running
        case .attention, .interrupted: self = .attention
        case .failed: self = .failed
        case .completed: self = .done
        }
    }

    public var fill: Color {
        switch self {
        case .running: Color(AnchorColorTokens.runningFill)
        case .attention: Color(AnchorColorTokens.attentionFill)
        case .failed: Color(AnchorColorTokens.failedFill)
        case .done: Color(AnchorColorTokens.doneFill)
        }
    }

    public var ink: Color {
        switch self {
        case .running: Color(AnchorColorTokens.runningInk)
        case .attention: Color(AnchorColorTokens.attentionInk)
        case .failed: Color(AnchorColorTokens.failedInk)
        case .done: Color(AnchorColorTokens.doneInk)
        }
    }
}

public extension Color {
    /// An appearance-adaptive color from a token.
    init(_ token: AnchorColorToken) {
#if os(iOS)
        self.init(uiColor: UIColor { traits in
            AnchorColorTokens.uiColor(traits.userInterfaceStyle == .dark ? token.dark : token.light)
        })
#else
        self.init(nsColor: NSColor(name: NSColor.Name(token.name)) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return AnchorColorTokens.nsColor(isDark ? token.dark : token.light)
        })
#endif
    }

    /// A fixed sRGB color for artwork that must not follow appearance.
    init(anchorHex value: UInt32) {
        self.init(
            .sRGB,
            red: Double((value >> 16) & 255) / 255,
            green: Double((value >> 8) & 255) / 255,
            blue: Double(value & 255) / 255
        )
    }
}

extension AnchorColorTokens {
#if os(iOS)
    static func uiColor(_ value: UInt32) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: 1)
    }
#else
    static func nsColor(_ value: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255, alpha: 1)
    }
#endif
}
