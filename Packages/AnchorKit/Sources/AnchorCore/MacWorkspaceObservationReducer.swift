#if os(macOS)
import Foundation

actor MacWorkspaceObservationReducer {
    private let sourceID: UUID
    private var currentSessionID: UUID?
    private var knownApplications: [String: MacApplicationSnapshot] = [:]
    private var hasReconciled = false
    private var sequence: UInt64 = 0

    init(sourceID: UUID) {
        self.sourceID = sourceID
    }

    func reconcile(
        _ snapshots: [MacApplicationSnapshot],
        sessionID: UUID,
        observedAt: Date
    ) -> [ExternalProcessEvent] {
        if currentSessionID != sessionID {
            currentSessionID = sessionID
            knownApplications.removeAll()
            hasReconciled = false
            sequence = 0
        }

        let current = Self.preferredSnapshots(snapshots)
        let isInitialSnapshot = !hasReconciled
        var observations: [ExternalProcessEvent] = []

        for identifier in current.keys.sorted() {
            guard let application = current[identifier] else { continue }
            let previous = knownApplications[identifier]

            if previous == nil {
                observations.append(
                    makeObservation(
                        application: application,
                        sessionID: sessionID,
                        observedAt: observedAt,
                        transition: isInitialSnapshot ? .initial : .launched
                    )
                )
            } else if previous?.processIdentifier != application.processIdentifier {
                observations.append(
                    makeObservation(
                        application: application,
                        sessionID: sessionID,
                        observedAt: observedAt,
                        transition: .restarted
                    )
                )
            } else if previous?.isActive != application.isActive {
                observations.append(
                    makeObservation(
                        application: application,
                        sessionID: sessionID,
                        observedAt: observedAt,
                        transition: application.isActive ? .foreground : .background
                    )
                )
            }
        }

        for identifier in knownApplications.keys.sorted() where current[identifier] == nil {
            guard let application = knownApplications[identifier] else { continue }
            observations.append(
                makeObservation(
                    application: application,
                    sessionID: sessionID,
                    observedAt: observedAt,
                    transition: .terminated
                )
            )
        }

        knownApplications = current
        hasReconciled = true
        return observations
    }

    private func makeObservation(
        application: MacApplicationSnapshot,
        sessionID: UUID,
        observedAt: Date,
        transition: MacApplicationTransition
    ) -> ExternalProcessEvent {
        sequence &+= 1
        let processID = StableProcessIdentity.id(
            namespace: "mac.workspace",
            sessionID: sessionID,
            externalID: application.identifier
        )
        let state = transition == .terminated
            ? MacWorkspaceStrings.closed
            : application.isActive
                ? MacWorkspaceStrings.foreground
                : MacWorkspaceStrings.background
        let detail = transition == .terminated
            ? MacWorkspaceStrings.closedDetail(application.localizedName)
            : application.isActive
                ? MacWorkspaceStrings.foregroundDetail(application.localizedName)
                : MacWorkspaceStrings.backgroundDetail(application.localizedName)

        let event: ProcessEvent?
        if transition == .initial {
            event = nil
        } else {
            event = ProcessEvent(
                sessionID: sessionID,
                processID: processID,
                sourceID: sourceID,
                externalID: application.identifier,
                occurredAt: observedAt,
                kind: transition == .launched || transition == .restarted ? .created : .note,
                title: transition.title(for: application.localizedName),
                detail: detail
            )
        }

        return ExternalProcessEvent(
            sessionID: sessionID,
            sourceID: sourceID,
            sequence: sequence,
            occurredAt: observedAt,
            process: AnchorProcess(
                id: processID,
                sessionID: sessionID,
                sourceID: sourceID,
                externalID: application.identifier,
                sourceName: application.localizedName,
                sourceSymbol: Self.monogram(for: application.localizedName),
                sourceTone: "cyan",
                title: application.localizedName,
                status: transition == .terminated ? .disconnected : .running,
                metric: state,
                metricLabel: MacWorkspaceStrings.applicationState,
                detail: detail,
                updatedAt: observedAt
            ),
            event: event
        )
    }

    private static func preferredSnapshots(
        _ snapshots: [MacApplicationSnapshot]
    ) -> [String: MacApplicationSnapshot] {
        var applications: [String: MacApplicationSnapshot] = [:]
        for snapshot in snapshots {
            if let existing = applications[snapshot.identifier], existing.isActive {
                continue
            }
            applications[snapshot.identifier] = snapshot
        }
        return applications
    }

    private static func monogram(for applicationName: String) -> String {
        let trimmed = applicationName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "?"
    }
}

private enum MacApplicationTransition: Sendable {
    case initial
    case launched
    case restarted
    case foreground
    case background
    case terminated

    func title(for applicationName: String) -> String {
        switch self {
        case .initial:
            MacWorkspaceStrings.detected(applicationName)
        case .launched:
            MacWorkspaceStrings.launched(applicationName)
        case .restarted:
            MacWorkspaceStrings.restarted(applicationName)
        case .foreground:
            MacWorkspaceStrings.movedToForeground(applicationName)
        case .background:
            MacWorkspaceStrings.movedToBackground(applicationName)
        case .terminated:
            MacWorkspaceStrings.closedEvent(applicationName)
        }
    }
}

enum MacWorkspaceStrings {
    static let sourceName = value("mac.workspace.source.name", default: "Mac Applications")
    static let foreground = value("mac.workspace.state.foreground", default: "Foreground")
    static let background = value("mac.workspace.state.background", default: "Background")
    static let closed = value("mac.workspace.state.closed", default: "Closed")
    static let applicationState = value(
        "mac.workspace.metric.application-state",
        default: "Application state"
    )

    static func detected(_ applicationName: String) -> String {
        format("mac.workspace.event.detected", default: "%@ detected", applicationName)
    }

    static func launched(_ applicationName: String) -> String {
        format("mac.workspace.event.launched", default: "%@ launched", applicationName)
    }

    static func restarted(_ applicationName: String) -> String {
        format("mac.workspace.event.restarted", default: "%@ restarted", applicationName)
    }

    static func movedToForeground(_ applicationName: String) -> String {
        format(
            "mac.workspace.event.foreground",
            default: "%@ moved to the foreground",
            applicationName
        )
    }

    static func movedToBackground(_ applicationName: String) -> String {
        format(
            "mac.workspace.event.background",
            default: "%@ moved to the background",
            applicationName
        )
    }

    static func closedEvent(_ applicationName: String) -> String {
        format("mac.workspace.event.closed", default: "%@ closed", applicationName)
    }

    static func foregroundDetail(_ applicationName: String) -> String {
        format(
            "mac.workspace.detail.foreground",
            default: "%@ is in the foreground.",
            applicationName
        )
    }

    static func backgroundDetail(_ applicationName: String) -> String {
        format(
            "mac.workspace.detail.background",
            default: "%@ is running in the background.",
            applicationName
        )
    }

    static func closedDetail(_ applicationName: String) -> String {
        format(
            "mac.workspace.detail.closed",
            default: "%@ is no longer running.",
            applicationName
        )
    }

    private static func format(
        _ key: String,
        default defaultValue: String,
        _ argument: String
    ) -> String {
        String.localizedStringWithFormat(value(key, default: defaultValue), argument)
    }

    private static func value(_ key: String, default defaultValue: String) -> String {
        let localized = String(
            localized: String.LocalizationValue(key),
            bundle: .module
        )
        return localized == key ? defaultValue : localized
    }
}
#endif
