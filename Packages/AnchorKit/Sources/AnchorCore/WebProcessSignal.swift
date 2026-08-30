import Foundation

public enum WebActivityState: String, Codable, CaseIterable, Sendable {
    case active
    case background
    case running
    case completed
    case failed
    case closed
}

/// A session-independent web activity signal produced by an explicit browser
/// extension. The generic contract stores a hostname, never a full URL or page
/// title; site-specific adapters may add a short, consented display name.
public struct WebProcessSignal: Identifiable, Codable, Hashable, Sendable {
    public static let schemaIdentifier = "anchor.web.activity.v1"
    private static let maximumDisplayLength = 120
    private static let maximumMetricLength = 80

    public let id: UUID
    public let schema: String
    public let activityID: UUID
    public let sequence: UInt64
    public let state: WebActivityState
    public let occurredAt: Date
    public let siteHost: String
    public let siteName: String?
    public let browserName: String?
    public let progress: Double?
    public let metric: String?
    public let metricLabel: String?

    public init(
        id: UUID = UUID(),
        activityID: UUID,
        sequence: UInt64,
        state: WebActivityState,
        occurredAt: Date = .now,
        siteHost: String,
        siteName: String? = nil,
        browserName: String? = nil,
        progress: Double? = nil,
        metric: String? = nil,
        metricLabel: String? = nil
    ) throws {
        self.id = id
        schema = Self.schemaIdentifier
        self.activityID = activityID
        self.sequence = sequence
        self.state = state
        self.occurredAt = occurredAt
        self.siteHost = try Self.sanitizedHost(siteHost)
        self.siteName = Self.optionalTrimmed(siteName, limit: Self.maximumDisplayLength)
        self.browserName = Self.optionalTrimmed(browserName, limit: Self.maximumDisplayLength)
        self.progress = progress
        self.metric = Self.optionalTrimmed(metric, limit: Self.maximumMetricLength)
        self.metricLabel = Self.optionalTrimmed(metricLabel, limit: Self.maximumMetricLength)
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        schema = try values.decode(String.self, forKey: .schema)
        activityID = try values.decode(UUID.self, forKey: .activityID)
        sequence = try values.decode(UInt64.self, forKey: .sequence)
        state = try values.decode(WebActivityState.self, forKey: .state)
        occurredAt = try values.decode(Date.self, forKey: .occurredAt)
        siteHost = try Self.sanitizedHost(
            values.decode(String.self, forKey: .siteHost)
        )
        siteName = Self.optionalTrimmed(
            try values.decodeIfPresent(String.self, forKey: .siteName),
            limit: Self.maximumDisplayLength
        )
        browserName = Self.optionalTrimmed(
            try values.decodeIfPresent(String.self, forKey: .browserName),
            limit: Self.maximumDisplayLength
        )
        progress = try values.decodeIfPresent(Double.self, forKey: .progress)
        metric = Self.optionalTrimmed(
            try values.decodeIfPresent(String.self, forKey: .metric),
            limit: Self.maximumMetricLength
        )
        metricLabel = Self.optionalTrimmed(
            try values.decodeIfPresent(String.self, forKey: .metricLabel),
            limit: Self.maximumMetricLength
        )
    }

    public func externalEvent(sessionID: UUID, sourceID: UUID) throws -> ExternalProcessEvent {
        try validate()

        let processID = StableProcessIdentity.id(
            namespace: "web.activity",
            sessionID: sessionID,
            externalID: activityID.uuidString
        )
        let processStatus: ProcessStatus
        let normalizedProgress: Double?
        let eventKind: ProcessEventKind?

        switch state {
        case .active, .background:
            processStatus = .running
            normalizedProgress = progress
            eventKind = nil
        case .running:
            processStatus = .running
            normalizedProgress = progress
            eventKind = progress == nil ? nil : .progress
        case .completed:
            processStatus = .completed
            normalizedProgress = 1
            eventKind = .completed
        case .failed:
            processStatus = .failed
            normalizedProgress = nil
            eventKind = .failed
        case .closed:
            processStatus = .disconnected
            normalizedProgress = nil
            eventKind = nil
        }

        let title = siteName ?? siteHost
        let sourceName = browserName ?? WebProcessStrings.sourceName
        let visibleMetric: String
        let visibleMetricLabel: String
        if let metric {
            visibleMetric = metric
            visibleMetricLabel = metricLabel ?? WebProcessStrings.activityState
        } else if let normalizedProgress {
            visibleMetric = "\(Int((normalizedProgress * 100).rounded()))%"
            visibleMetricLabel = WebProcessStrings.progress
        } else {
            visibleMetric = WebProcessStrings.state(state)
            visibleMetricLabel = WebProcessStrings.activityState
        }
        let detail = WebProcessStrings.detail(title, state: state)

        let processEvent = eventKind.map { kind in
            ProcessEvent(
                sessionID: sessionID,
                processID: processID,
                sourceID: sourceID,
                externalID: activityID.uuidString,
                deduplicationKey: "web:\(id.uuidString.lowercased())",
                occurredAt: occurredAt,
                kind: kind,
                title: WebProcessStrings.eventTitle(title, state: state),
                detail: detail,
                progress: normalizedProgress,
                metric: visibleMetric,
                metricLabel: visibleMetricLabel
            )
        }

        return ExternalProcessEvent(
            id: id,
            sessionID: sessionID,
            sourceID: sourceID,
            sequence: sequence,
            occurredAt: occurredAt,
            process: AnchorProcess(
                id: processID,
                sessionID: sessionID,
                sourceID: sourceID,
                externalID: activityID.uuidString,
                sourceName: sourceName,
                sourceSymbol: "W",
                sourceTone: "periwinkle",
                title: title,
                status: processStatus,
                progress: normalizedProgress,
                metric: visibleMetric,
                metricLabel: visibleMetricLabel,
                detail: detail,
                updatedAt: occurredAt
            ),
            event: processEvent,
            deduplicationKey: "web:\(id.uuidString.lowercased())"
        )
    }

    public func validate() throws {
        guard schema == Self.schemaIdentifier else {
            throw WebProcessSignalError.unsupportedSchema(schema)
        }
        if let progress, !(0 ... 1).contains(progress) {
            throw WebProcessSignalError.invalidProgress
        }
    }

    private static func sanitizedHost(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let components: URLComponents?
        if trimmed.contains("://") {
            components = URLComponents(string: trimmed)
        } else {
            components = URLComponents(string: "https://\(trimmed)")
        }
        guard let host = components?.host?.lowercased(),
              !host.isEmpty,
              host.count <= 253 else {
            throw WebProcessSignalError.invalidSiteHost
        }
        return host
    }

    private static func optionalTrimmed(_ value: String?, limit: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(limit))
    }
}

public enum WebProcessSignalError: LocalizedError, Hashable, Sendable {
    case invalidProgress
    case invalidSiteHost
    case unsupportedSchema(String)

    public var errorDescription: String? {
        switch self {
        case .invalidProgress:
            "Web activity progress must be between 0 and 1."
        case .invalidSiteHost:
            "A web activity signal requires a valid site hostname."
        case let .unsupportedSchema(schema):
            "Unsupported web activity signal schema: \(schema)."
        }
    }
}

private enum WebProcessStrings {
    static let sourceName = value("web.source.name", default: "Web Apps")
    static let activityState = value("web.metric.activity-state", default: "Activity state")
    static let progress = value("web.metric.progress", default: "Progress")

    static func state(_ state: WebActivityState) -> String {
        value("web.state.\(state.rawValue)", default: stateDefault(state))
    }

    static func detail(_ title: String, state: WebActivityState) -> String {
        format(
            "web.detail.\(state.rawValue)",
            default: detailDefault(state),
            title
        )
    }

    static func eventTitle(_ title: String, state: WebActivityState) -> String {
        format(
            "web.event.\(state.rawValue)",
            default: eventDefault(state),
            title
        )
    }

    private static func detailDefault(_ state: WebActivityState) -> String {
        switch state {
        case .active: "%@ is the active web app."
        case .background: "%@ moved to the background."
        case .running: "%@ is running."
        case .completed: "%@ completed its current activity."
        case .failed: "%@ reported a failure."
        case .closed: "%@ was closed."
        }
    }

    private static func eventDefault(_ state: WebActivityState) -> String {
        switch state {
        case .active: "%@ became active"
        case .background: "%@ moved to the background"
        case .running: "%@ progress updated"
        case .completed: "%@ completed"
        case .failed: "%@ failed"
        case .closed: "%@ closed"
        }
    }

    private static func stateDefault(_ state: WebActivityState) -> String {
        switch state {
        case .active: "Active"
        case .background: "Background"
        case .running: "Running"
        case .completed: "Completed"
        case .failed: "Failed"
        case .closed: "Closed"
        }
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
