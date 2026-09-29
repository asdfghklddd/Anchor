#if os(macOS)
import AnchorDesign

enum MacSection: String, CaseIterable, Hashable, Identifiable {
    case current
    case history
    case settings

    var id: String { rawValue }

    init(storedValue: String) {
        // Preserve upgrades from the former five-section sidebar.
        switch storedValue {
        case "timeline": self = .current
        case "sources": self = .settings
        default: self = MacSection(rawValue: storedValue) ?? .current
        }
    }

    var title: String {
        switch self {
        case .current: L10n.currentWork
        case .history: L10n.history
        case .settings: L10n.settings
        }
    }

    var symbol: String {
        switch self {
        case .current: "scope"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape"
        }
    }
}
#endif
