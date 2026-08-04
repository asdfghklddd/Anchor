import Foundation

enum DemoL10n {
    static let controls = value("demo.controls", default: "Demo controls")
    static let reset = value("demo.reset", default: "Restore baseline data")
    static let explanation = value(
        "demo.explanation",
        default: "Scenarios inject raw events and signals into the same reducers used by production."
    )

    static func scenario(_ scenario: DemoScenario) -> String {
        switch scenario {
        case .active: value("scenario.active", default: "Active work")
        case .needsDecision: value("scenario.decision", default: "Needs decision")
        case .away18Minutes: value("scenario.away", default: "Away for 18 minutes")
        case .returning: value("scenario.returning", default: "Returning")
        case .completed: value("scenario.completed", default: "Completed")
        case .empty: value("scenario.empty", default: "Empty")
        case .disconnected: value("scenario.disconnected", default: "Mac disconnected")
        case .permissionDenied: value("scenario.permission", default: "Permission denied")
        case .staleData: value("scenario.stale", default: "Stale data")
        case .retryableError: value("scenario.error", default: "Retryable error")
        }
    }

    private static func value(
        _ key: StaticString,
        default defaultValue: String.LocalizationValue
    ) -> String {
        String(localized: key, defaultValue: defaultValue, bundle: .module)
    }
}
