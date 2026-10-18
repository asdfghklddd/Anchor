#if os(macOS)
import AnchorCore
import AnchorDesign
import AppKit
import SwiftUI

/// The menu bar item (M6): open Anchor, see how many tasks need you, reach
/// settings, and quit — the one way out of an app without a Dock icon.
public struct AnchorMenuBarContent: View {
    let model: AnchorSessionModel
    let onOpen: () -> Void

    public init(model: AnchorSessionModel, onOpen: @escaping () -> Void) {
        self.model = model
        self.onOpen = onOpen
    }

    public var body: some View {
        let needsYou = AnchorMenuBarLabel.needsYou(in: model.projection)
        Button(MenuBarCopy.open, action: onOpen)
            .keyboardShortcut("o")
        if needsYou > 0 {
            Button("\(needsYou) \(PlanText.glanceNeedsYou)", action: onOpen)
        }
        Divider()
        SettingsLink { Text(MenuBarCopy.settings) }
            .keyboardShortcut(",")
        Divider()
        Button(MenuBarCopy.quit) { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

/// The boat in the menu bar, with the count of tasks that need you beside it.
public struct AnchorMenuBarLabel: View {
    let model: AnchorSessionModel

    public init(model: AnchorSessionModel) {
        self.model = model
    }

    public var body: some View {
        let count = Self.needsYou(in: model.projection)
        if count > 0 {
            Label("\(count)", systemImage: "sailboat.fill")
                .labelStyle(.titleAndIcon)
                .accessibilityLabel("\(count) \(PlanText.glanceNeedsYou)")
        } else {
            Image(systemName: "sailboat")
                .accessibilityLabel(L10n.appName)
        }
    }

    static func needsYou(in projection: SessionProjection) -> Int {
        WorkGlance(tasks: projection.hostedSessions).needsYou
    }
}

enum MenuBarCopy {
    static let open = AnchorStrings.value("menu.open", default: "Open Anchor")
    static let settings = AnchorStrings.value("menu.settings", default: "Settings…")
    static let quit = AnchorStrings.value("menu.quit", default: "Quit Anchor")
}
#endif
