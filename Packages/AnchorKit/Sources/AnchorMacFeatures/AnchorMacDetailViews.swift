#if os(macOS)
import AnchorCore
import AnchorDesign
import AppKit
import SwiftUI
import UserNotifications

struct MacTimelineView: View {
    let projection: SessionProjection
    let onOpenSettings: () -> Void

    private var processesByID: [UUID: AnchorProcess] {
        Dictionary(
            uniqueKeysWithValues: (projection.session?.processes ?? []).map { ($0.id, $0) }
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AnchorSpacing.small) {
                if let events = projection.session?.timeline, !events.isEmpty {
                    ForEach(events) { event in
                        let process = process(for: event)
                        timelineRow(event, process: process)
                        .padding(AnchorSpacing.medium)
                        .background(AnchorPalette.surface, in: .rect(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AnchorPalette.ink.opacity(0.08), lineWidth: 1)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(eventAccessibilityLabel(event, process: process))
                    }
                } else {
                    timelineEmptyState
                }
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(AnchorSpacing.xLarge)
        }
        .background(HarborBackground())
        .navigationTitle(L10n.timeline)
        .accessibilityIdentifier("mac.timeline.screen")
    }

    private func timelineRow(_ event: ProcessEvent, process: AnchorProcess?) -> some View {
        HStack(alignment: .top, spacing: AnchorSpacing.medium) {
            Image(systemName: macEventSymbol(event.kind))
                .font(.body.weight(.semibold))
                .foregroundStyle(process.map { AnchorPalette.sourceInk($0.sourceTone) } ?? AnchorPalette.deepSea)
                .frame(width: 36, height: 36)
                .background(
                    (process.map { AnchorPalette.source($0.sourceTone) } ?? AnchorPalette.cyan).opacity(0.20),
                    in: .circle
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                if let process {
                    HStack(spacing: AnchorSpacing.xSmall) {
                        SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 22)
                        Text(process.sourceName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                    }
                } else {
                    Text(L10n.appName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AnchorPalette.deepSea)
                }

                Text(event.title)
                    .font(.headline)
                if !event.detail.isEmpty {
                    Text(event.detail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text(event.occurredAt, format: .dateTime.hour().minute())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }
            Spacer(minLength: 0)
        }
    }

    private func process(for event: ProcessEvent) -> AnchorProcess? {
        guard let processID = event.processID else { return nil }
        return processesByID[processID]
    }

    private func eventAccessibilityLabel(_ event: ProcessEvent, process: AnchorProcess?) -> String {
        let sourceName = process?.sourceName ?? L10n.appName
        let time = event.occurredAt.formatted(date: .omitted, time: .shortened)
        let parts = [sourceName, event.title, event.detail, time]
            .filter { !$0.isEmpty }
        return parts.joined(separator: ", ")
    }

    private var timelineEmptyState: some View {
        VStack(spacing: AnchorSpacing.medium) {
            ContentUnavailableView(
                projection.session == nil ? L10n.emptyTitle : L10n.noEvents,
                systemImage: "waveform.path.ecg",
                description: Text(
                    projection.session == nil
                        ? L10n.emptyDetail
                        : L10n.timelineEmptyDetail
                )
            )

            if projection.session == nil {
                Button(L10n.pairDevice, systemImage: "link", action: onOpenSettings)
                    .buttonStyle(.borderedProminent)
                    .tint(AnchorPalette.deepSea)
                    .controlSize(.large)
                    .accessibilityIdentifier("mac.timeline.pair.button")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .padding(.horizontal, AnchorSpacing.large)
        .background(AnchorPalette.surface.opacity(0.72), in: .rect(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier("mac.timeline.empty")
    }
}

struct MacHistoryView: View {
    let projection: SessionProjection
    let onOpenCurrentWork: () -> Void

    @State private var selectedSnapshot: ContextSnapshot?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                if let session = projection.session {
                    AnchorCard(tint: AnchorPalette.seafoam) {
                        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                            Text(L10n.currentWork)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AnchorPalette.deepSea)
                                .textCase(.uppercase)
                            Text(session.goal.title)
                                .font(.title2.bold())
                            LabeledContent(
                                L10n.startedAt(
                                    session.startedAt.formatted(date: .abbreviated, time: .shortened)
                                )
                            ) {
                                Text(L10n.processCount(session.processes.count))
                            }
                            .foregroundStyle(AnchorPalette.secondaryInk)
                        }
                    }

                    VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                        Text(L10n.history)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AnchorPalette.deepSea)
                            .textCase(.uppercase)
                        if session.snapshots.isEmpty {
                            historyEmptyState
                        } else {
                            ForEach(session.snapshots) { snapshot in
                                Button {
                                    selectedSnapshot = snapshot
                                } label: {
                                    AnchorCard {
                                        HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                                            Image(systemName: "arrow.counterclockwise")
                                                .foregroundStyle(AnchorPalette.cyan)
                                                .frame(width: 32, height: 32)
                                                .background(AnchorPalette.cyan.opacity(0.14), in: .circle)
                                                .accessibilityHidden(true)
                                            VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                                                Text(snapshot.goalTitle)
                                                    .font(.headline)
                                                    .foregroundStyle(AnchorPalette.ink)
                                                Text(snapshot.createdAt, format: .dateTime.month().day().hour().minute())
                                                    .font(.caption.monospacedDigit())
                                                    .foregroundStyle(.secondary)
                                                if let latestNote = snapshot.latestNote, !latestNote.isEmpty {
                                                    Text(latestNote)
                                                        .font(.callout)
                                                        .foregroundStyle(AnchorPalette.secondaryInk)
                                                        .lineLimit(2)
                                                }
                                                Label(
                                                    L10n.processAttentionSummary(
                                                        processes: snapshot.processes.count,
                                                        attention: snapshot.openDecisionIDs.count
                                                    ),
                                                    systemImage: "arrow.up.right"
                                                )
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(AnchorPalette.deepSea)
                                            }
                                            Spacer(minLength: 0)
                                            Image(systemName: "chevron.right")
                                                .font(.callout.weight(.bold))
                                                .foregroundStyle(AnchorPalette.secondaryInk)
                                                .accessibilityHidden(true)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityHint(L10n.openDetails)
                                .accessibilityIdentifier("mac.history.snapshot")
                            }
                        }
                    }
                } else {
                    VStack(spacing: AnchorSpacing.medium) {
                        ContentUnavailableView(
                            L10n.emptyTitle,
                            systemImage: "clock.arrow.circlepath",
                            description: Text(L10n.historyEmptyDetail)
                        )
                        .accessibilityIdentifier("mac.history.empty.content")
                        Button(L10n.currentWork, systemImage: "arrow.left", action: onOpenCurrentWork)
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier("mac.history.current.button")
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                    .background(AnchorPalette.surface.opacity(0.72), in: .rect(cornerRadius: 18))
                }
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(AnchorSpacing.xLarge)
        }
        .background(HarborBackground())
        .navigationTitle(L10n.history)
        .accessibilityIdentifier("mac.history.screen")
        .sheet(item: $selectedSnapshot) { snapshot in
            MacSnapshotDetailView(snapshot: snapshot)
        }
    }

    private var historyEmptyState: some View {
        VStack(spacing: AnchorSpacing.medium) {
            ContentUnavailableView(
                L10n.historyNoSnapshots,
                systemImage: "clock.arrow.circlepath",
                description: Text(L10n.historyNoSnapshotsDetail)
            )
            .accessibilityIdentifier("mac.history.no-snapshots.content")
            Button(L10n.currentWork, systemImage: "arrow.left", action: onOpenCurrentWork)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("mac.history.current.button")
        }
        .frame(maxWidth: .infinity, minHeight: 210)
        .background(AnchorPalette.surface.opacity(0.72), in: .rect(cornerRadius: 18))
    }
}

struct MacSourcesView: View {
    let projection: SessionProjection
    let onOpenSettings: () -> Void

    @State private var selectedSource: MacSourceGroup?

    private var sourceGroups: [MacSourceGroup] {
        MacSourceGroup.groups(from: projection.session?.processes ?? [])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                MacSourceHealthSummary(projection: projection)

                Text(L10n.connectedSources)
                    .font(.title2.bold())
                    .foregroundStyle(AnchorPalette.ink)

                if sourceGroups.isEmpty {
                    VStack(spacing: AnchorSpacing.medium) {
                        ContentUnavailableView(
                            projection.session == nil ? L10n.emptyTitle : L10n.connectedSources,
                            systemImage: "point.3.filled.connected.trianglepath.dotted",
                            description: Text(
                                projection.session == nil
                                    ? L10n.emptyDetail
                                    : L10n.noEvents
                            )
                        )
                        if projection.session == nil {
                            Button(L10n.pairDevice, systemImage: "link", action: onOpenSettings)
                                .buttonStyle(.borderedProminent)
                                .tint(AnchorPalette.deepSea)
                                .controlSize(.large)
                                .accessibilityIdentifier("mac.sources.pair.button")
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .background(AnchorPalette.surface.opacity(0.72), in: .rect(cornerRadius: 20, style: .continuous))
                    .accessibilityIdentifier("mac.sources.empty")
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 290), spacing: AnchorSpacing.medium)],
                        alignment: .leading,
                        spacing: AnchorSpacing.medium
                    ) {
                        ForEach(sourceGroups) { source in
                            MacSourceCard(source: source) {
                                selectedSource = source
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(AnchorSpacing.xLarge)
        }
        .background(HarborBackground())
        .navigationTitle(L10n.sourceHealth)
        .accessibilityIdentifier("mac.sources.screen")
        .sheet(item: $selectedSource) { source in
            MacSourceDetailView(
                source: source,
                connection: projection.connection,
                dataObservedAt: projection.dataObservedAt,
                openDecisions: openDecisions(for: source)
            )
        }
    }

    private func openDecisions(for source: MacSourceGroup) -> [Decision] {
        let processIDs = Set(source.processes.map(\.id))
        return projection.openDecisions.filter { processIDs.contains($0.processID) }
    }
}

struct MacSettingsView: View {
    let projection: SessionProjection
    let controller: (any LocalLinkControlling)?
    @State private var launchAtLogin = MacLaunchAtLogin.isEnabled
    @AppStorage("anchor.mac.notifications.decisions") private var decisionAlerts = false
    @State private var pairingCode: String?
    @State private var pairingCodeCopied = false
    @State private var notificationAuthorization: UNAuthorizationStatus = .notDetermined
    @State private var settingsMessage: String?
    @State private var isLoadingSettings = true
    @State private var isApplyingSettings = false

    var body: some View {
        Form {
            Section(L10n.connections) {
                LabeledContent(L10n.macConnection) {
                    Label(
                        connectionLabel,
                        systemImage: connectionSymbol
                    )
                    .foregroundStyle(connectionTint)
                }
                LabeledContent(L10n.bluetoothProximity) {
                    Label(
                        proximityLabel,
                        systemImage: proximitySymbol
                    )
                    .foregroundStyle(proximityTint)
                }
                if let dataObservedAt = projection.dataObservedAt {
                    LabeledContent(L10n.lastUpdated) {
                        Text(dataObservedAt, style: .relative)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(AnchorPalette.secondaryInk)
                    }
                }
                if let connectionDetail {
                    VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                        Text(connectionDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let controller {
                            Button(L10n.retry, systemImage: "arrow.clockwise") {
                                Task { await controller.retryConnection() }
                            }
                            .controlSize(.small)
                        }
                    }
                }
                Button(L10n.pairDevice, systemImage: "link") {
                    Task { pairingCode = await controller?.currentPairingCode() }
                }
                .disabled(controller == nil)
                .accessibilityIdentifier("mac.settings.pair")
                if controller == nil {
                    Text(L10n.pairingUnavailable)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let pairingCode {
                    VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                        HStack(alignment: .center, spacing: AnchorSpacing.small) {
                            Label(L10n.pairingCode, systemImage: "number")
                                .font(.callout.weight(.semibold))
                            Spacer(minLength: AnchorSpacing.small)
                            Text(pairingCode)
                                .font(.title2.bold().monospacedDigit())
                                .textSelection(.enabled)
                                .accessibilityLabel(L10n.pairingCode)
                                .accessibilityValue(Text(pairingCode))
                            Button(L10n.copyPairingCode, systemImage: "doc.on.doc") {
                                copyPairingCode(pairingCode)
                            }
                            .controlSize(.small)
                            .accessibilityIdentifier("mac.pairing.copy")
                        }
                        .accessibilityElement(children: .contain)
                        Text(L10n.pairingHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if pairingCodeCopied {
                            Label(L10n.pairingCodeCopied, systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(AnchorPalette.mintInk)
                                .accessibilityIdentifier("mac.pairing.copied")
                        }
                    }
                }
            }
            Section(L10n.settings) {
                Toggle(L10n.startAtLogin, isOn: $launchAtLogin)
                    .disabled(isLoadingSettings || isApplyingSettings)
                    .onChange(of: launchAtLogin) { _, enabled in
                        guard !isLoadingSettings else { return }
                        applyLaunchAtLogin(enabled)
                    }
                Toggle(L10n.notificationDecisions, isOn: $decisionAlerts)
                    .disabled(isLoadingSettings || isApplyingSettings)
                    .onChange(of: decisionAlerts) { _, enabled in
                        guard !isLoadingSettings else { return }
                        Task { await applyDecisionAlerts(enabled) }
                    }
                if notificationAuthorization == .denied {
                    VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                        Label(
                            L10n.notificationPermissionDetail,
                            systemImage: "bell.slash"
                        )
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.coral)
                        Button(L10n.openSystemSettings, systemImage: "gearshape") {
                            MacDecisionNotificationService.openSystemSettings()
                        }
                        .controlSize(.small)
                    }
                }
                if let settingsMessage {
                    Text(settingsMessage)
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.coral)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Section(L10n.privacy) {
                Label(L10n.localOnly, systemImage: "lock.shield.fill")
                Text(L10n.localOnlyDetail).foregroundStyle(.secondary)
            }
            Section(L10n.accessibility) {
                VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                    Label(L10n.displaySupport, systemImage: "accessibility")
                        .font(.headline)
                    Text(L10n.displaySupportDetail)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Label(L10n.voiceOver, systemImage: "speaker.wave.3")
                Label(L10n.dynamicType, systemImage: "textformat.size")
                Label(L10n.reduceMotion, systemImage: "figure.walk.motion")
                Label(L10n.increaseContrast, systemImage: "circle.lefthalf.filled")
                Label(L10n.reduceTransparency, systemImage: "square.on.square")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(HarborBackground())
        .padding(AnchorSpacing.large)
        .navigationTitle(L10n.settings)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.settings.screen")
        .task {
            pairingCode = await controller?.currentPairingCode()
            notificationAuthorization = await MacDecisionNotificationService.authorizationStatus()
            launchAtLogin = MacLaunchAtLogin.isEnabled
            isLoadingSettings = false
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        isApplyingSettings = true
        defer { isApplyingSettings = false }

        do {
            try MacLaunchAtLogin.setEnabled(enabled)
            settingsMessage = nil
        } catch {
            launchAtLogin = MacLaunchAtLogin.isEnabled
            settingsMessage = error.localizedDescription
        }
    }

    private func copyPairingCode(_ code: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        pairingCodeCopied = true
    }

    private func applyDecisionAlerts(_ enabled: Bool) async {
        isApplyingSettings = true
        defer { isApplyingSettings = false }

        if enabled {
            let granted = await MacDecisionNotificationService.requestAuthorization()
            notificationAuthorization = await MacDecisionNotificationService.authorizationStatus()
            guard granted else {
                decisionAlerts = false
                settingsMessage = L10n.notificationPermissionDetail
                return
            }
            settingsMessage = nil
        } else {
            await MacDecisionNotificationService.removePendingDecisionNotifications()
            settingsMessage = nil
        }
    }

    private var connectionLabel: String {
        switch projection.connection {
        case .connected: L10n.connected
        case .pairing: L10n.pairDevice
        case .disconnected: L10n.disconnected
        case .unavailable: L10n.unknown
        case .permissionDenied: L10n.permissionDenied
        case .failed: L10n.actionFailed
        }
    }

    private var connectionSymbol: String {
        switch projection.connection {
        case .connected: "checkmark.circle.fill"
        case .pairing: "arrow.triangle.2.circlepath"
        case .disconnected: "wifi.slash"
        case .unavailable: "questionmark.circle"
        case .permissionDenied: "lock.slash"
        case .failed: "exclamationmark.triangle.fill"
        }
    }

    private var connectionTint: Color {
        switch projection.connection {
        case .connected: AnchorPalette.mintInk
        case .pairing: AnchorPalette.sourceInk("sand")
        case .disconnected, .permissionDenied, .failed: AnchorPalette.coral
        case .unavailable: AnchorPalette.secondaryInk
        }
    }

    private var connectionDetail: String? {
        switch projection.connection {
        case .permissionDenied: L10n.permissionDeniedDetail
        case .failed: L10n.connectionFailedDetail
        case .disconnected: L10n.disconnectedDetail
        default: nil
        }
    }

    private var proximityLabel: String {
        switch projection.proximity {
        case .near: L10n.nearby
        case .far: L10n.outOfRange
        case .unknown, .unavailable: L10n.unknown
        case .permissionDenied: L10n.permissionDenied
        }
    }

    private var proximitySymbol: String {
        switch projection.proximity {
        case .near: "dot.radiowaves.left.and.right"
        case .far: "wifi.slash"
        case .unknown, .unavailable: "questionmark.circle"
        case .permissionDenied: "lock.slash"
        }
    }

    private var proximityTint: Color {
        switch projection.proximity {
        case .near: AnchorPalette.mintInk
        case .far: AnchorPalette.sourceInk("sand")
        case .unknown, .unavailable: AnchorPalette.secondaryInk
        case .permissionDenied: AnchorPalette.sourceInk("coral")
        }
    }
}

private func macEventSymbol(_ kind: ProcessEventKind) -> String {
    switch kind {
    case .created: "plus"
    case .progress: "arrow.up.right"
    case .outputReady: "sparkles"
    case .decisionRequired: "exclamationmark.bubble.fill"
    case .decisionResolved: "checkmark.bubble.fill"
    case .completed: "checkmark.circle.fill"
    case .failed: "xmark.octagon.fill"
    case .note: "bookmark.fill"
    case .presence: "person.wave.2.fill"
    case .connection: "network"
    }
}
#endif
