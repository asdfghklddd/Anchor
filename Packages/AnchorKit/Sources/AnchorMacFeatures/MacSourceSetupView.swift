#if os(macOS)
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

                MacSourceSetupRow(
                    symbol: "macwindow",
                    title: L10n.sourceSetupMacApps,
                    detail: L10n.sourceSetupMacAppsDetail,
                    status: L10n.sourceSetupReady,
                    isReady: true
                )

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
                    symbol: "network",
                    title: L10n.sourceSetupWebApps,
                    detail: L10n.sourceSetupWebAppsDetail,
                    status: browserStatus,
                    isReady: model.lastBrowserConnectionAt != nil
                ) {
                    if let preferredBrowser = model.preferredBrowser {
                        Button(
                            L10n.sourceSetupConnectBrowser(preferredBrowser.displayName),
                            systemImage: "puzzlepiece.extension"
                        ) {
                            Task { await model.connectBrowser(preferredBrowser) }
                        }
                        .disabled(model.isWorking || !model.isBrowserBridgeBundled)
                        .accessibilityIdentifier("mac.sources.setup.browser.connect")
                    }

                    if model.browsersAvailableForConnection.count > 1 {
                        Menu(L10n.sourceSetupOtherBrowser, systemImage: "ellipsis.circle") {
                            ForEach(model.browsersAvailableForConnection) { browser in
                                Button(browser.displayName) {
                                    Task { await model.connectBrowser(browser) }
                                }
                            }
                        }
                        .disabled(model.isWorking || !model.isBrowserBridgeBundled)
                        .accessibilityIdentifier("mac.sources.setup.browser.other")
                    }

                    Button(L10n.sourceSetupShowExtension, systemImage: "folder") {
                        model.revealBrowserExtension()
                    }
                    .disabled(!model.isBrowserExtensionBundled)
                    .accessibilityIdentifier("mac.sources.setup.extension.reveal")
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
        }
        .task(id: model.awaitingConfirmationBrowser) {
            guard model.awaitingConfirmationBrowser != nil else { return }
            for _ in 0..<60 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await model.refresh()
                if model.awaitingConfirmationBrowser == nil { return }
            }
        }
    }

    private var commandStatus: String {
        if model.isCommandInstalled { return L10n.sourceSetupInstalled }
        return model.isCommandBundled ? L10n.sourceSetupAvailable : L10n.sourceSetupUnavailable
    }

    private var browserStatus: String {
        if model.awaitingConfirmationBrowser != nil {
            return L10n.sourceSetupAwaitingBrowserConfirmation
        }
        if model.lastBrowserConnectionAt != nil {
            return L10n.sourceSetupBrowserConnected
        }
        if !model.configuredBrowsers.isEmpty {
            return L10n.sourceSetupBrowserPrepared
        }
        return model.isBrowserBridgeBundled ? L10n.sourceSetupAvailable : L10n.sourceSetupUnavailable
    }
}
#endif
