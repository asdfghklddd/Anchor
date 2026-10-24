import AnchorDesign
import Foundation
import Testing

/// Enforces the color rules on the shared tokens.
/// Set ANCHOR_COLOR_TABLE_EXPORT to a file path to write the contrast table.
@Suite("Color tokens")
struct AnchorColorTokenTests {
    private typealias T = AnchorColorTokens
    private enum Mode: String, CaseIterable { case light, dark }

    private static func value(_ token: AnchorColorToken, _ mode: Mode) -> UInt32 {
        mode == .light ? token.light : token.dark
    }

    private static func luminance(_ value: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let c = Double((value >> shift) & 255) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    private static func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let (high, low) = (max(luminance(a), luminance(b)), min(luminance(a), luminance(b)))
        return (high + 0.05) / (low + 0.05)
    }

    private static func hue(_ value: UInt32) -> Double {
        let r = Double((value >> 16) & 255) / 255, g = Double((value >> 8) & 255) / 255, b = Double(value & 255) / 255
        let maxC = max(r, g, b), minC = min(r, g, b), delta = maxC - minC
        guard delta > 0 else { return 0 }
        var h: Double
        if maxC == r { h = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
        else if maxC == g { h = (b - r) / delta + 2 }
        else { h = (r - g) / delta + 4 }
        h *= 60
        return h < 0 ? h + 360 : h
    }

    private static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }

    static let textTokens = [T.text, T.textSecondary, T.heading, T.action,
                             T.runningInk, T.attentionInk, T.failedInk, T.doneInk]
    static let fillTokens = [T.runningFill, T.attentionFill, T.failedFill, T.doneFill, T.borderStrong]
    static let backgrounds = [T.surface, T.canvasTop, T.canvasBottom,
                              T.landscapeCanvasLeading, T.landscapeCanvasTrailing]

    @Test("Text reads at 4.5:1 on every surface in both appearances")
    func textContrast() {
        for token in Self.textTokens {
            for background in Self.backgrounds {
                for mode in Mode.allCases {
                    let ratio = Self.contrast(Self.value(token, mode), Self.value(background, mode))
                    #expect(ratio >= 4.5, "\(token.name) on \(background.name) (\(mode)): \(ratio)")
                }
            }
        }
    }

    @Test("State fills and control borders reach 3:1 on cards")
    func fillContrast() {
        for token in Self.fillTokens {
            for mode in Mode.allCases {
                let ratio = Self.contrast(Self.value(token, mode), Self.value(T.surface, mode))
                #expect(ratio >= 3, "\(token.name) on surface (\(mode)): \(ratio)")
            }
        }
    }

    @Test("Content on brand and action fills reads at 4.5:1")
    func onFillContrast() {
        for mode in Mode.allCases {
            #expect(Self.contrast(Self.value(T.onBrand, mode), Self.value(T.brand, mode)) >= 4.5)
            #expect(Self.contrast(Self.value(T.onAction, mode), Self.value(T.action, mode)) >= 4.5)
        }
    }

    @Test("Identity colors stay visible and never look like a state")
    func identitySeparation() {
        let stateHues = [T.runningFill, T.attentionFill, T.failedFill].map { Self.hue($0.light) }
        for token in T.identity {
            for mode in Mode.allCases {
                let ratio = Self.contrast(Self.value(token, mode), Self.value(T.surface, mode))
                #expect(ratio >= 2.5, "\(token.name) on surface (\(mode)): \(ratio)")
            }
            for stateHue in stateHues {
                #expect(Self.hueDistance(Self.hue(token.light), stateHue) >= 20, "\(token.name) is near a state hue")
            }
        }
        for index in T.identity.count..<64 {
            let degrees = AnchorTaskIdentity.generatedHue(index: index) * 360
            #expect(T.identityHueBand.contains(degrees), "generated identity \(index) at \(degrees)")
        }
    }

    @Test("Landscape desk tokens match the approved Figma canvas and task tabs")
    func landscapeDeskTokens() {
        #expect(T.landscapeCanvasLeading.light == 0xFAFDFF)
        #expect(T.landscapeCanvasTrailing.light == 0xD4F7FF)
        #expect(T.landscapeCanvasLeading.dark == T.canvasTop.dark)
        #expect(T.landscapeCanvasTrailing.dark == T.canvasBottom.dark)

        let expected: [UInt32] = [0xFFB400, 0x3DD4FE, 0xFF64DB]
        #expect(T.landscapeTaskTabs.count == expected.count)
        #expect(T.landscapeTaskTabs.map(\.light) == expected)
        #expect(T.landscapeTaskTabs.map(\.dark) == expected)
        for index in 0..<12 {
            #expect(T.landscapeTaskTab(index: index).name == T.landscapeTaskTabs[index % expected.count].name)
        }
        for tab in T.landscapeTaskTabs {
            for mode in Mode.allCases {
                #expect(Self.contrast(Self.value(T.onLandscapeTaskTab, mode), Self.value(tab, mode)) >= 4.5,
                        "\(T.onLandscapeTaskTab.name) on \(tab.name) (\(mode))")
            }
        }
    }

    @Test("Every token is listed once")
    func uniqueNames() {
        #expect(Set(T.all.map(\.name)).count == T.all.count)
    }

    @Test("Contrast table export")
    func exportTable() throws {
        guard let path = ProcessInfo.processInfo.environment["ANCHOR_COLOR_TABLE_EXPORT"] else { return }
        func hex(_ v: UInt32) -> String { String(format: "`#%06X`", v) }
        func ratio(_ a: UInt32, _ b: UInt32) -> String { String(format: "%.2f", Self.contrast(a, b)) }
        var lines = ["| Token | Light | Dark | On surface (light / dark) |", "|---|---|---|---|"]
        for token in T.all {
            lines.append("| `\(token.name)` | \(hex(token.light)) | \(hex(token.dark)) | "
                + "\(ratio(token.light, T.surface.light)) / \(ratio(token.dark, T.surface.dark)) |")
        }
        try (lines.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }
}
