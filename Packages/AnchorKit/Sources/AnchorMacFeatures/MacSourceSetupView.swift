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

                sourceRow(
                    symbol: "macwindow",
                    title: L10n.sourceSetupMacApps,
                    detail: L10n.sourceSetupMacAppsDetail,
                    status: L10n.sourceSetupReady,
                    isReady: true
                )

                Divider()

                sourceRow(
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

                sourceRow(
                    symbol: "network",
                    title: L10n.sourceSetupWebApps,
                    detail: L10n.sourceSetupWebAppsDetail,
                    status: browserStatus,
                    isReady: !model.installedBrowsers.isEmpty
                ) {
                    Menu(L10n.sourceSetupInstallBrowserBridge, systemImage: "puzzlepiece.extension") {
                        ForEach(MacSourceSetupBrowser.allCases) { browser in
                            Button(browser.displayName) {
                                Task { await model.installBrowserBridge(for: browser) }
                            }
                        }
                    }
                    .disabled(model.isWorking || !model.isBrowserBridgeBundled)
                    .accessibilityIdentifier("mac.sources.setup.browser.install")

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
    }

    private var commandStatus: String {
        if model.isCommandInstalled { return L10n.sourceSetupInstalled }
        return model.isCommandBundled ? L10n.sourceSetupAvailable : L10n.sourceSetupUnavailable
    }

    private var browserStatus: String {
        if !model.installedBrowsers.isEmpty {
            return L10n.sourceSetupBrowserCount(model.installedBrowsers.count)
        }
        return model.isBrowserBridgeBundled ? L10n.sourceSetupAvailable : L10n.sourceSetupUnavailable
    }

    private func sourceRow<Actions: View>(
        symbol: String,
        title: String,
        detail: String,
        status: String,
        isReady: Bool,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            HStack(alignment: .top, spacing: AnchorSpacing.medium) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AnchorPalette.deepSea)
                    .frame(width: 36, height: 36)
                    .background(AnchorPalette.cyan.opacity(0.14), in: .circle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                    Text(title)
                        .font(.headline)
                    Text(detail)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: AnchorSpacing.small)
                Label(
                    status,
                    systemImage: isReady ? "checkmark.circle.fill" : "circle.dashed"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(isReady ? AnchorPalette.mintInk : AnchorPalette.secondaryInk)
            }
            HStack(spacing: AnchorSpacing.small) {
                actions()
            }
            .controlSize(.large)
            .padding(.leading, 52)
        }
    }

    private func sourceRow(
        symbol: String,
        title: String,
        detail: String,
        status: String,
        isReady: Bool
    ) -> some View {
        sourceRow(
            symbol: symbol,
            title: title,
            detail: detail,
            status: status,
            isReady: isReady
        ) {
            EmptyView()
        }
    }
}
#endif
