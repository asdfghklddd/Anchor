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
                        .background(AnchorPalette.fluoriteSurface, in: .rect(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(AnchorPalette.fluoriteBorder, lineWidth: 1)
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
        .background(.clear)
        .navigationTitle(L10n.timeline)
        .accessibilityIdentifier("mac.timeline.screen")
    }

    private func timelineRow(_ event: ProcessEvent, process: AnchorProcess?) -> some View {
        HStack(alignment: .top, spacing: AnchorSpacing.medium) {
            Image(systemName: macEventSymbol(event.kind))
                .font(.body.weight(.semibold))
                .foregroundStyle(process.map { AnchorPalette.sourceInk($0.sourceTone) } ?? AnchorPalette.deepSeaInk)
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
                        .foregroundStyle(AnchorPalette.brandDeep)
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
                    .tint(AnchorPalette.interaction)
                    .controlSize(.large)
                    .accessibilityIdentifier("mac.timeline.pair.button")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 360)
        .padding(.horizontal, AnchorSpacing.large)
        .background(AnchorPalette.fluoriteSurface.opacity(0.72), in: .rect(cornerRadius: 20, style: .continuous))
        .accessibilityIdentifier("mac.timeline.empty")
    }
}

struct MacSettingsView: View {
    @AppStorage(AnchorMotion.reduceMotionDefaultsKey) private var reduceMotion = false
    let projection: SessionProjection
    let controller: (any LocalLinkControlling)?
    let sourceSetupModel: MacSourceSetupModel?
    @State private var launchAtLogin = MacLaunchAtLogin.isEnabled
    @AppStorage(AnchorEdgeSoundCue.enabledDefaultsKey) private var edgeSoundEffects = true
    @State private var notificationAuthorization: UNAuthorizationStatus = .notDetermined
    @State private var settingsMessage: String?
    @State private var isLoadingSettings = true
    @State private var isApplyingSettings = false
    @State private var selectedSource: MacSourceGroup?

    private var sourceGroups: [MacSourceGroup] {
        MacSourceGroup.groups(from: projection.session?.processes ?? [])
    }

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
                        if projection.connection == .failed, let controller {
                            Button(L10n.retry, systemImage: "arrow.clockwise") {
                                Task { await controller.retryConnection() }
                            }
                            .controlSize(.small)
                        }
                    }
                }
                MacPairingControls(controller: controller)
            }
            Section(L10n.sources) {
                if let sourceSetupModel {
                    MacSourceSetupView(model: sourceSetupModel)
                        .accessibilityIdentifier("mac.sources.setup")
                }

                MacSourceHealthSummary(projection: projection)

                if sourceGroups.isEmpty {
                    ContentUnavailableView(
                        L10n.connectedSources,
                        systemImage: "point.3.filled.connected.trianglepath.dotted",
                        description: Text(L10n.noEvents)
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 280), spacing: AnchorSpacing.medium)],
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
            Section(L10n.settings) {
                Toggle(L10n.startAtLogin, isOn: $launchAtLogin)
                    .disabled(isLoadingSettings || isApplyingSettings)
                    .onChange(of: launchAtLogin) { _, enabled in
                        guard !isLoadingSettings else { return }
                        applyLaunchAtLogin(enabled)
                    }
                Toggle(L10n.edgeSoundEffects, isOn: $edgeSoundEffects)
                if notificationAuthorization == .denied {
                    VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                        Label(
                            L10n.notificationPermissionDetail,
                            systemImage: "bell.slash"
                        )
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.coral)
                        Button(L10n.openSystemSettings, systemImage: "gearshape") {
                            MacNotificationSettings.openSystemSettings()
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
                Toggle(L10n.reduceMotion, isOn: $reduceMotion)
                    .accessibilityIdentifier("settings.reduceMotion")
                Label(L10n.increaseContrast, systemImage: "circle.lefthalf.filled")
                Label(L10n.reduceTransparency, systemImage: "square.on.square")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(.clear)
        .padding(AnchorSpacing.large)
        .navigationTitle(L10n.settings)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.settings.screen")
        .sheet(item: $selectedSource) { source in
            MacSourceDetailView(
                source: source,
                connection: projection.connection,
                dataObservedAt: projection.dataObservedAt,
                openDecisions: openDecisions(for: source)
            )
        }
        .task {
            notificationAuthorization = await MacNotificationSettings.authorizationStatus()
            launchAtLogin = MacLaunchAtLogin.isEnabled
            isLoadingSettings = false
        }
    }

    private func openDecisions(for source: MacSourceGroup) -> [Decision] {
        let processIDs = Set(source.processes.map(\.id))
        return projection.openDecisions.filter { processIDs.contains($0.processID) }
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
        case .permissionDenied, .failed: AnchorPalette.coral
        case .disconnected, .unavailable: AnchorPalette.secondaryInk
        }
    }

    private var connectionDetail: String? {
        switch projection.connection {
        case .permissionDenied: L10n.permissionDeniedDetail
        case .failed: L10n.connectionFailedDetail
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
