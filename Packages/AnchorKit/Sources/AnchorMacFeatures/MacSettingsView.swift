#if os(macOS)
import AnchorCore
import AnchorDesign
import AppKit
import SwiftUI

/// Anchor's settings, in one short window: the phone, the agent folders, the
/// recap key and a few switches. Anything that needs explaining waits behind
/// an ⓘ. Switches take the iPhone's green.
struct MacSettingsView: View {
    let projection: SessionProjection
    let controller: (any LocalLinkControlling)?
    let sourceSetupModel: MacSourceSetupModel?
    var bluetooth: MacBluetoothRadioState?

    @State private var launchAtLogin = MacLaunchAtLogin.isEnabled
    @AppStorage(NotchPeek.enabledDefaultsKey) private var notchPeeks = true
    @State private var settingsMessage: String?
    @State private var isLoadingSettings = true
    @State private var isApplyingSettings = false
    @State private var confirmsReset = false
    @State private var pairing = DevicePairingStatus.automatic
    @State private var pairingCode: String?
    @State private var lastDevice = PeerDeviceMemory.last()

    var body: some View {
        Form {
            connection
            if let sourceSetupModel {
                MacSourcesSection(model: sourceSetupModel)
            }
            if let modelKey = sourceSetupModel?.modelKey {
                MacRecapKeySection(access: modelKey)
            }
            general
            footer
        }
        .formStyle(.grouped)
        .tint(AnchorPalette.interaction)
        .navigationTitle(L10n.settings)
        .accessibilityIdentifier("mac.settings.screen")
        .task {
            launchAtLogin = MacLaunchAtLogin.isEnabled
            isLoadingSettings = false
        }
        .task {
            guard let controller else { return }
            for await status in controller.pairingStatusUpdates() {
                pairing = status
                if let device = status.peerDeviceInfo { lastDevice = device }
                if status.phase == .verificationCodeRequired {
                    pairingCode = await controller.currentPairingCode()
                } else if status.phase == .connected {
                    pairingCode = nil
                }
            }
        }
    }

    private var status: AnchorStatusMenu {
        AnchorStatusMenu(
            projection: projection,
            radio: bluetooth?.radio ?? .unknown,
            pairing: pairing,
            codexReady: sourceSetupModel?.codexSessionsFolderName != nil,
            claudeReady: sourceSetupModel?.claudeProjectsFolderName != nil
        )
    }

    // MARK: Phone

    private var connection: some View {
        let status = status
        let device = pairing.peerDeviceInfo ?? lastDevice
        return Section(L10n.connections) {
            LabeledContent {
                Text(StatusMenuCopy.link(status.link))
                    .foregroundStyle(linkTint(status.link))
            } label: {
                Label(device?.displayName ?? "iPhone", systemImage: device?.symbolName ?? "iphone")
            }
            .accessibilityIdentifier("settings.link")

            if let pairingCode {
                LabeledContent {
                    HStack(spacing: AnchorSpacing.small) {
                        Text(pairingCode)
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .tracking(2)
                            .textSelection(.enabled)
                        Button(L10n.copyPairingCode, systemImage: "doc.on.doc") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(pairingCode, forType: .string)
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .help(L10n.copyPairingCode)
                        .accessibilityIdentifier("mac.pairing.copy")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(L10n.pairingCode)
                        MacInfoTip(text: L10n.pairingHint)
                    }
                }
            } else if !status.isConnected, pairing.phase == .automatic, let controller {
                // Nearby pairing found nothing: the code works over the network too.
                Button(L10n.pairingCode, systemImage: "number") {
                    Task { pairingCode = await controller.currentPairingCode() }
                }
                .accessibilityIdentifier("mac.pairing.show.code")
            }

            if let fix = status.fix {
                Button(StatusMenuCopy.fix(fix)) { perform(fix) }
                    .accessibilityIdentifier("settings.link.fix")
            }
        }
    }

    private func linkTint(_ link: AnchorStatusMenu.Link) -> Color {
        switch link {
        // The switches' green is too light for text on a light window.
        case .connected: Color(AnchorColorTokens.doneInk)
        case .bluetoothOff, .bluetoothNotAllowed, .failed: AnchorTaskIdentity.attentionInk
        case .searching, .notPaired: .secondary
        }
    }

    private func perform(_ fix: AnchorStatusMenu.Fix) {
        if let url = fix.settingsURL {
            NSWorkspace.shared.open(url)
        } else if let controller {
            Task { await controller.retryConnection() }
        }
    }

    // MARK: Switches

    private var general: some View {
        Section {
            Toggle(L10n.startAtLogin, isOn: $launchAtLogin)
                .disabled(isLoadingSettings || isApplyingSettings)
                .onChange(of: launchAtLogin) { _, enabled in
                    guard !isLoadingSettings else { return }
                    applyLaunchAtLogin(enabled)
                }
            Toggle(NotchIslandCopy.peeksToggle, isOn: $notchPeeks)
                .accessibilityIdentifier("settings.notchPeeks")
            LabeledContent(NotchIslandCopy.shortcut) {
                Text("⌃⌥A")
                    .font(.body.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Control Option A")
            }
            if let settingsMessage {
                Text(settingsMessage)
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.coral)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .toggleStyle(.switch)
        .tint(Color(AnchorColorTokens.homeLinked))
    }

    private var footer: some View {
        Section {
            HStack(spacing: AnchorSpacing.small) {
                if sourceSetupModel != nil {
                    Button(MacLocalResetCopy.title, role: .destructive) { confirmsReset = true }
                        .accessibilityIdentifier("settings.resetLocalData")
                    MacInfoTip(text: MacLocalResetCopy.detail)
                }
                Spacer()
                Button(EdgeMenuCopy.quit) { NSApp.terminate(nil) }
                    .accessibilityIdentifier("settings.quit")
            }
        }
        .alert(MacLocalResetCopy.confirmTitle, isPresented: $confirmsReset) {
            Button(MacLocalResetCopy.confirm, role: .destructive) { sourceSetupModel?.resetLocalData() }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(MacLocalResetCopy.confirmMessage)
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
}

/// Codex and Claude Code each on one line with where it stands; one button
/// connects both folders. The terminal command sits below.
private struct MacSourcesSection: View {
    @Bindable var model: MacSourceSetupModel

    var body: some View {
        Section {
            LabeledContent(L10n.sourceSetupCodex) {
                state(codexStatus, isReady: model.codexSessionsFolderName != nil)
            }
            LabeledContent(MacClaudeCodeCopy.title) {
                state(model.claudeProjectsFolderName == nil ? L10n.sourceSetupNotConnected : L10n.sourceSetupReady,
                      isReady: model.claudeProjectsFolderName != nil)
            }
            if model.codexSessionsFolderName == nil || model.claudeProjectsFolderName == nil {
                Button(L10n.sourceSetupAgentFoldersConnect, systemImage: "folder.badge.plus") {
                    Task { await model.authorizeAgentSessionFolders() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)
                .accessibilityIdentifier("mac.sources.setup.agents.authorize")
            }
            LabeledContent {
                if model.isCommandInstalled {
                    Button(model.didCopyShellSetup ? L10n.sourceSetupShellCopied : L10n.sourceSetupCopyShell,
                           systemImage: model.didCopyShellSetup ? "checkmark" : "doc.on.doc") {
                        model.copyShellSetup()
                    }
                    .accessibilityIdentifier("mac.sources.setup.shell.copy")
                } else {
                    Button(L10n.sourceSetupInstallCommand, systemImage: "square.and.arrow.down") {
                        Task { await model.installCommand() }
                    }
                    .disabled(model.isWorking || !model.isCommandBundled)
                    .help(model.isCommandBundled ? "" : L10n.sourceSetupUnavailable)
                    .accessibilityIdentifier("mac.sources.setup.command.install")
                }
            } label: {
                HStack(spacing: 4) {
                    Text(L10n.sourceSetupTerminal)
                    MacInfoTip(text: L10n.sourceSetupTerminalDetail)
                }
            }
        } header: {
            HStack(spacing: 4) {
                Text(L10n.sources)
                MacInfoTip(text: NotchIslandCopy.sourcesPrivacy)
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
        .accessibilityIdentifier("mac.sources.setup")
        .task { await model.refresh() }
    }

    private func state(_ text: String, isReady: Bool) -> some View {
        Text(text)
            .foregroundStyle(isReady ? AnyShapeStyle(.secondary) : AnyShapeStyle(AnchorTaskIdentity.attentionInk))
    }

    private var codexStatus: String {
        if !model.trackedCodexSessionIDs.isEmpty {
            return L10n.sourceSetupCodexTrackedCount(model.trackedCodexSessionIDs.count)
        }
        return model.codexSessionsFolderName == nil ? L10n.sourceSetupNotConnected : L10n.sourceSetupCodexFolderReady
    }
}

/// More about a setting: on hover as a tooltip, on click (or with VoiceOver)
/// in full, so the window needs no lines of explanation.
struct MacInfoTip: View {
    let text: String
    @State private var isShown = false

    var body: some View {
        Button { isShown.toggle() } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help(text)
        .accessibilityLabel(text)
        .popover(isPresented: $isShown, arrowEdge: .bottom) {
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 280, alignment: .leading)
                .padding(12)
        }
    }
}
#endif
