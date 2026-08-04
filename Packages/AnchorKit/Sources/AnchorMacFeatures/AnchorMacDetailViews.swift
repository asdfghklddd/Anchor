#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacCurrentWorkView: View {
    let model: AnchorSessionModel
    @State private var selectedProcessID: UUID?
    @State private var selectedOptionID: UUID?

    var body: some View {
        if let session = model.projection.session {
            ScrollView {
                VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                    AnchorCard(tint: AnchorPalette.seafoam) {
                        HStack(alignment: .top, spacing: AnchorSpacing.large) {
                            VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                                Text(L10n.currentGoal).font(.caption.bold())
                                Text(session.goal.title)
                                    .font(.largeTitle.bold())
                                    .accessibilityIdentifier("mac.current.goal")
                                Text(session.goal.completionCriteria)
                                    .font(.title3)
                                    .foregroundStyle(AnchorPalette.secondaryInk)
                            }
                            Spacer(minLength: AnchorSpacing.large)
                            if let progress = model.projection.overallProgress {
                                VStack(alignment: .trailing) {
                                    Text(progress, format: .percent.precision(.fractionLength(0)))
                                        .font(.largeTitle.bold().monospacedDigit())
                                    Text(L10n.overallProgress).font(.caption)
                                }
                            }
                        }
                    }

                    HStack(alignment: .top, spacing: AnchorSpacing.large) {
                        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                            Text(L10n.processes).font(.title2.bold())
                            ForEach(session.processes) { process in
                                Button {
                                    selectedProcessID = process.id
                                    selectedOptionID = nil
                                } label: {
                                    MacProcessRow(process: process, isSelected: selectedProcessID == process.id)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(selectedProcessID == process.id ? .isSelected : [])
                            }
                        }
                        .frame(maxWidth: .infinity)

                        processInspector(session)
                            .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
                    }
                }
                .padding(AnchorSpacing.large)
            }
            .navigationTitle(L10n.currentWork)
            .accessibilityIdentifier("mac.current.screen")
            .onAppear {
                selectedProcessID = session.decisions.first(where: { $0.status == .open })?.processID
                    ?? session.processes.first?.id
            }
        } else {
            ContentUnavailableView(L10n.emptyTitle, systemImage: "scope", description: Text(L10n.emptyDetail))
        }
    }

    @ViewBuilder
    private func processInspector(_ session: AnchorSession) -> some View {
        if let process = session.processes.first(where: { $0.id == selectedProcessID }) {
            AnchorCard(tint: AnchorPalette.source(process.sourceTone)) {
                VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                    HStack {
                        Text(process.sourceName).font(.headline)
                        Spacer()
                        StatusBadge(status: process.status, text: L10n.status(process.status))
                    }
                    Text(process.title).font(.title.bold())
                    Text(process.detail).foregroundStyle(AnchorPalette.secondaryInk)
                    if let progress = process.progress {
                        AnchorProgress(value: progress, tint: AnchorPalette.source(process.sourceTone))
                    }
                    if let decision = session.decisions.first(where: {
                        $0.processID == process.id && $0.status == .open
                    }) {
                        Divider()
                        Text(decision.prompt).font(.headline)
                        ForEach(decision.options) { option in
                            Button {
                                selectedOptionID = option.id
                            } label: {
                                HStack {
                                    Image(systemName: selectedOptionID == option.id ? "checkmark.circle.fill" : "circle")
                                        .accessibilityHidden(true)
                                    Text(option.title)
                                    Spacer()
                                }
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selectedOptionID == option.id ? .isSelected : [])
                        }
                        Button(L10n.confirmChoice) {
                            guard let selectedOptionID,
                                  let option = decision.options.first(where: { $0.id == selectedOptionID }) else { return }
                            Task { await model.resolve(decision: decision, option: option) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(selectedOptionID == nil)
                        .keyboardShortcut(.defaultAction)
                    }
                }
            }
        } else {
            ContentUnavailableView(L10n.emptyTitle, systemImage: "square.dashed")
        }
    }
}

private struct MacProcessRow: View {
    let process: AnchorProcess
    let isSelected: Bool

    var body: some View {
        HStack(spacing: AnchorSpacing.medium) {
            Text(process.sourceSymbol)
                .font(.headline.bold())
                .frame(width: 40, height: 40)
                .background(AnchorPalette.source(process.sourceTone).opacity(0.55), in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(process.title).font(.headline)
                Text(process.detail)
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .lineLimit(1)
            }
            Spacer()
            StatusBadge(status: process.status, text: L10n.status(process.status))
        }
        .padding(AnchorSpacing.small)
        .background(
            isSelected ? AnchorPalette.source(process.sourceTone).opacity(0.22) : AnchorPalette.surface,
            in: .rect(cornerRadius: 16)
        )
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 16).stroke(AnchorPalette.source(process.sourceTone), lineWidth: 2)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct MacTimelineView: View {
    let projection: SessionProjection
    var body: some View {
        List(projection.session?.timeline ?? []) { event in
            HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                Image(systemName: macEventSymbol(event.kind))
                    .frame(width: 32, height: 32)
                    .background(AnchorPalette.cyan.opacity(0.22), in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text(event.title).font(.headline)
                    Text(event.detail).foregroundStyle(.secondary)
                    Text(event.occurredAt, format: .dateTime.hour().minute())
                        .font(.caption.monospacedDigit())
                }
            }
            .padding(.vertical, 5)
            .accessibilityElement(children: .combine)
        }
        .overlay {
            if projection.session?.timeline.isEmpty != false {
                ContentUnavailableView(L10n.noEvents, systemImage: "waveform.path.ecg")
            }
        }
        .navigationTitle(L10n.timeline)
    }
}

struct MacHistoryView: View {
    let projection: SessionProjection
    var body: some View {
        List {
            if let session = projection.session {
                Section(L10n.currentWork) {
                    LabeledContent(session.goal.title) {
                        Text(session.startedAt, format: .dateTime.month().day().hour().minute())
                    }
                }
                Section(L10n.history) {
                    ForEach(session.snapshots) { snapshot in
                        LabeledContent(snapshot.goalTitle) {
                            Text(snapshot.createdAt, format: .dateTime.month().day().hour().minute())
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.history)
    }
}

struct MacSourcesView: View {
    let projection: SessionProjection
    var body: some View {
        List(projection.session?.processes ?? []) { process in
            HStack {
                Text(process.sourceSymbol)
                    .font(.headline.bold())
                    .frame(width: 38, height: 38)
                    .background(AnchorPalette.source(process.sourceTone).opacity(0.5), in: .rect(cornerRadius: 11))
                    .accessibilityHidden(true)
                VStack(alignment: .leading) {
                    Text(process.sourceName).font(.headline)
                    Text(process.updatedAt, style: .relative).font(.caption)
                }
                Spacer()
                StatusBadge(status: process.status, text: L10n.status(process.status))
            }
            .padding(.vertical, 5)
        }
        .navigationTitle(L10n.sourceHealth)
    }
}

struct MacSettingsView: View {
    let projection: SessionProjection
    let controller: (any LocalLinkControlling)?
    @State private var launchAtLogin = false
    @State private var decisionAlerts = true
    @State private var pairingCode: String?

    var body: some View {
        Form {
            Section(L10n.connections) {
                LabeledContent(L10n.macConnection) {
                    Label(
                        projection.connection == .connected ? L10n.connected : L10n.disconnected,
                        systemImage: projection.connection == .connected ? "checkmark.circle.fill" : "wifi.slash"
                    )
                }
                Button(L10n.pairDevice) {
                    Task { pairingCode = await controller?.currentPairingCode() }
                }
                if let pairingCode {
                    LabeledContent(L10n.pairingCode) {
                        Text(pairingCode)
                            .font(.title2.bold().monospacedDigit())
                            .textSelection(.enabled)
                    }
                }
            }
            Section(L10n.settings) {
                Toggle(L10n.startAtLogin, isOn: $launchAtLogin)
                Toggle(L10n.notificationDecisions, isOn: $decisionAlerts)
            }
            Section(L10n.privacy) {
                Label(L10n.localOnly, systemImage: "lock.shield.fill")
                Text(L10n.localOnlyDetail).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(AnchorSpacing.large)
        .navigationTitle(L10n.settings)
        .task { pairingCode = await controller?.currentPairingCode() }
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
