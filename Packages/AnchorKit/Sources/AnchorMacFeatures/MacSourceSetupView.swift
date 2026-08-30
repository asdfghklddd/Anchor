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
#endif
