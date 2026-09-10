#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacSourceSetupView: View {
    @Bindable var model: MacSourceSetupModel

    var body: some View {
        AnchorCard(tint: AnchorPalette.cyan) {
            VStack(alignment: .leading, spacing: AnchorSpacing.large) {
                VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                    Text(L10n.sourceSetupTitle)
                        .font(.title2.bold())
                        .foregroundStyle(AnchorPalette.ink)
                    Text(L10n.sourceSetupDetail)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let taskState = model.taskState {
                    MacTaskObservationView(state: taskState)
                    Divider()
                }

                MacSourceSetupRow(
                    symbol: "macwindow",
                    title: L10n.sourceSetupMacApps,
                    detail: L10n.sourceSetupMacAppsDetail,
                    status: L10n.sourceSetupReady,
                    isReady: true
                )

                Divider()

                MacSourceSetupRow(
                    symbol: "bubble.left.and.text.bubble.right",
                    title: L10n.sourceSetupCodex,
                    detail: L10n.sourceSetupCodexDetail,
                    status: model.codexSessionFileName ?? L10n.sourceSetupNotConnected,
                    isReady: model.codexSessionFileName != nil
                ) {
                    Button(L10n.sourceSetupChooseCodexSession, systemImage: "doc.badge.plus") {
                        Task { await model.selectCodexSession() }
                    }
                    .disabled(model.isWorking)
                    .accessibilityIdentifier("mac.sources.setup.codex.choose-session")
                }

                Divider()

                MacSourceSetupRow(
                    symbol: "terminal",
                    title: L10n.sourceSetupTerminal,
                    detail: L10n.sourceSetupTerminalDetail,
                    status: commandStatus,
                    isReady: model.isCommandInstalled
                ) {
                    Button(L10n.sourceSetupInstallCommand, systemImage: "square.and.arrow.down") {
                        Task { await model.installCommand() }
                    }
                    .disabled(model.isWorking || !model.isCommandBundled)
                    .accessibilityIdentifier("mac.sources.setup.command.install")

                    Button(L10n.sourceSetupCopyShell, systemImage: "doc.on.doc") {
                        model.copyShellSetup()
                    }
                    .disabled(!model.isCommandInstalled)
                    .accessibilityIdentifier("mac.sources.setup.shell.copy")
                }

                if model.didCopyShellSetup {
                    Label(L10n.sourceSetupShellCopied, systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AnchorPalette.mintInk)
                        .accessibilityIdentifier("mac.sources.setup.shell.copied")
                }

                Divider()

                MacSourceSetupRow(
                    symbol: "safari",
                    title: L10n.sourceSetupWebApps,
                    detail: L10n.sourceSetupWebAppsDetail,
                    status: safariStatus,
                    isReady: model.isSafariExtensionEnabled
                ) {
                    Button(
                        model.isSafariExtensionEnabled
                            ? L10n.sourceSetupOpenSafariSettings
                            : L10n.sourceSetupEnableSafari,
                        systemImage: "puzzlepiece.extension"
                    ) {
                        Task { await model.openSafariExtensionSettings() }
                    }
                    .disabled(model.isWorking || !model.isSafariExtensionBundled)
                    .accessibilityIdentifier("mac.sources.setup.safari.open-settings")
                }

                Text(L10n.sourceSetupWebDistributionDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .alert(
            L10n.actionFailed,
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.clearError() } }
            )
        ) {
            Button(L10n.close) { model.clearError() }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task {
            await model.refresh()
            await model.restoreCodexSession()
        }
        .task(id: model.isAwaitingSafariConfirmation) {
            guard model.isAwaitingSafariConfirmation else { return }
            for _ in 0..<60 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await model.refresh()
                if !model.isAwaitingSafariConfirmation { return }
            }
        }
        .task {
            while !Task.isCancelled {
                await model.refreshTaskState()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private var commandStatus: String {
        if model.isCommandInstalled { return L10n.sourceSetupInstalled }
        return model.isCommandBundled ? L10n.sourceSetupAvailable : L10n.sourceSetupUnavailable
    }

    private var safariStatus: String {
        if model.isSafariExtensionEnabled { return L10n.sourceSetupSafariEnabled }
        if model.isAwaitingSafariConfirmation {
            return L10n.sourceSetupAwaitingSafariConfirmation
        }
        return model.isSafariExtensionBundled
            ? L10n.sourceSetupAvailable
            : L10n.sourceSetupUnavailable
    }
}

private struct MacTaskObservationView: View {
    let state: AnchorTaskState

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Label(L10n.sourceSetupTaskObservation, systemImage: "waveform.path.ecg")
                    .font(.headline)
                    .foregroundStyle(AnchorPalette.ink)
                Spacer()
                Text(L10n.sourceSetupTaskCounts(workItems: state.workItemCount, runs: state.runCount))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }

            Text(L10n.sourceSetupTaskObservationDetail)
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)

            HStack(spacing: AnchorSpacing.medium) {
                metric(
                    label: L10n.sourceSetupTaskExecution,
                    value: executionLabel,
                    identifier: "mac.sources.task-state.execution"
                )
                metric(
                    label: L10n.sourceSetupTaskAttention,
                    value: attentionLabel,
                    identifier: "mac.sources.task-state.attention"
                )
                metric(
                    label: L10n.sourceSetupTaskOutcome,
                    value: outcomeLabel,
                    identifier: "mac.sources.task-state.outcome"
                )
                metric(
                    label: L10n.sourceSetupTaskLifecycle,
                    value: lifecycleLabel,
                    identifier: "mac.sources.task-state.lifecycle"
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.sources.task-state")
    }

    private func metric(label: String, value: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AnchorPalette.secondaryInk)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var executionLabel: String {
        switch state.execution {
        case .queued: L10n.sourceSetupTaskQueued
        case .running: L10n.sourceSetupTaskRunning
        case .waitingBackground: L10n.sourceSetupTaskWaiting
        case .idle: L10n.sourceSetupTaskIdle
        }
    }

    private var attentionLabel: String {
        let labels = state.attention.sorted { $0.rawValue < $1.rawValue }.map { attention in
            switch attention {
            case .needsInput: L10n.sourceSetupTaskNeedsInput
            case .hasFailure: L10n.sourceSetupTaskHasFailure
            case .stale: L10n.sourceSetupTaskStale
            }
        }
        return labels.isEmpty ? L10n.sourceSetupTaskNoAttention : ListFormatter.localizedString(byJoining: labels)
    }

    private var outcomeLabel: String {
        switch state.outcome {
        case .none: L10n.sourceSetupTaskNoOutcome
        case .completed: L10n.sourceSetupTaskCompleted
        case .failed: L10n.sourceSetupTaskFailed
        case .interrupted: L10n.sourceSetupTaskInterrupted
        }
    }

    private var lifecycleLabel: String {
        switch state.lifecycle {
        case .active: L10n.sourceSetupTaskActive
        case .awaitingUserConfirmation: L10n.sourceSetupTaskAwaitingConfirmation
        case .archived: L10n.sourceSetupTaskArchived
        }
    }
}
#endif
