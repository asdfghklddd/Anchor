#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

public struct AnchorMacMenuView: View {
    private let model: AnchorSessionModel
    private let onOpenDetails: () -> Void
    private let onOpenTimeline: () -> Void
    private let onOpenSources: () -> Void
    private let onOpenSettings: () -> Void
    private let onContinueWorking: () -> Void
    private let onQuit: () -> Void

    @State private var note = ""

    public init(
        model: AnchorSessionModel,
        onOpenDetails: @escaping () -> Void,
        onOpenTimeline: @escaping () -> Void,
        onOpenSources: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onContinueWorking: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.model = model
        self.onOpenDetails = onOpenDetails
        self.onOpenTimeline = onOpenTimeline
        self.onOpenSources = onOpenSources
        self.onOpenSettings = onOpenSettings
        self.onContinueWorking = onContinueWorking
        self.onQuit = onQuit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            menuHeader
            Divider()

            if let session = model.projection.session {
                sessionSummary(session)
                if session.presence != .atDesk {
                    MacMenuPresenceCard(
                        session: session
                    )
                }
                if let decision = model.projection.openDecisions.first {
                    decisionNotice(decision)
                }
                noteCapture
            } else {
                emptySummary
            }

            Divider()
            Button(action: primaryAction) {
                Label(primaryActionTitle, systemImage: primaryActionSymbol)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AnchorPalette.deepSea)
            .controlSize(.large)
            .keyboardShortcut("o")
            .accessibilityIdentifier("mac.menu.primary")

            HStack(spacing: AnchorSpacing.small) {
                Button(L10n.timeline, systemImage: "waveform.path.ecg", action: onOpenTimeline)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("mac.menu.timeline")
                Button(L10n.sources, systemImage: "point.3.filled.connected.trianglepath.dotted", action: onOpenSources)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("mac.menu.sources")
                Button(L10n.settings, systemImage: "gearshape", action: onOpenSettings)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("mac.menu.settings")
            }
            .buttonStyle(.bordered)

            Divider()
            HStack {
                Label(L10n.localOnly, systemImage: "lock.shield")
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                Spacer(minLength: AnchorSpacing.small)
                Button(L10n.quit, action: onQuit)
                    .buttonStyle(.plain)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .keyboardShortcut("q")
            }
        }
        .padding(AnchorSpacing.medium)
        .frame(width: 370)
        .background(AnchorPalette.paper)
        .task { model.start() }
    }

    private var menuHeader: some View {
        HStack(spacing: AnchorSpacing.small) {
            AnchorMark(size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.appName)
                    .font(.headline.bold())
                Label(connectionLabel, systemImage: connectionSymbol)
                    .font(.caption)
                    .foregroundStyle(connectionTint)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("mac.menu.header")
    }

    private func sessionSummary(_ session: AnchorSession) -> some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            Text(L10n.currentWork)
                .font(.caption.bold())
                .foregroundStyle(AnchorPalette.deepSea)
                .textCase(.uppercase)
            Text(session.goal.title)
                .font(.title3.bold())
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(2)
            HStack {
                Label(L10n.processCount(session.processes.count), systemImage: "square.grid.2x2")
                Spacer()
                Label("\(model.projection.openDecisions.count)", systemImage: "exclamationmark.bubble")
                    .accessibilityLabel(L10n.decisionCount(model.projection.openDecisions.count))
            }
            .font(.subheadline.weight(.semibold))
            if let progress = model.projection.overallProgress {
                AnchorProgress(value: progress, tint: AnchorPalette.seafoam)
            }
        }
    }

    private var emptySummary: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                Text(L10n.emptyTitle)
                    .font(.title3.bold())
                    .foregroundStyle(AnchorPalette.ink)
                Text(L10n.emptyDetail)
                    .font(.callout)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 0) {
                menuMetric(value: "0", label: L10n.processes, symbol: "square.grid.2x2")
                Divider().padding(.vertical, AnchorSpacing.xSmall)
                menuMetric(value: "0", label: L10n.decisions, symbol: "exclamationmark.bubble")
                Divider().padding(.vertical, AnchorSpacing.xSmall)
                menuMetric(value: "0", label: L10n.notes, symbol: "bookmark")
            }
            .padding(.vertical, AnchorSpacing.xSmall)
            .background(AnchorPalette.surface, in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AnchorPalette.ink.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private func menuMetric(value: String, label: String, symbol: String) -> some View {
        VStack(spacing: 3) {
            Label(value, systemImage: symbol)
                .font(.headline.monospacedDigit())
                .foregroundStyle(AnchorPalette.ink)
            Text(label)
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 52)
        .accessibilityElement(children: .combine)
    }

    private func decisionNotice(_ decision: Decision) -> some View {
        Button(action: onOpenDetails) {
            HStack(alignment: .top, spacing: AnchorSpacing.small) {
                Image(systemName: "exclamationmark.bubble.fill")
                    .foregroundStyle(AnchorPalette.deepSea)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.attentionNeeded).font(.caption.bold())
                    Text(decision.title).font(.subheadline.weight(.semibold))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .accessibilityHidden(true)
            }
            .foregroundStyle(AnchorPalette.ink)
            .padding(AnchorSpacing.small)
            .background(AnchorPalette.sand.opacity(0.28), in: .rect(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mac.menu.decision")
    }

    private var noteCapture: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.small) {
            TextField(L10n.anchorNotePrompt, text: $note)
                .textFieldStyle(.roundedBorder)
                .onSubmit { saveNote() }
                .accessibilityIdentifier("mac.menu.note.input")
            Button(action: saveNote) {
                Label(L10n.anchorNote, systemImage: "scope")
                    .frame(maxWidth: .infinity)
            }
            .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("mac.menu.note")
        }
    }

    private var connectionLabel: String {
        switch model.projection.connection {
        case .connected: L10n.connected
        case .pairing: L10n.pairDevice
        case .disconnected: L10n.disconnected
        case .unavailable: L10n.unknown
        case .permissionDenied: L10n.permissionDenied
        case .failed: L10n.actionFailed
        }
    }
    private var connectionSymbol: String {
        switch model.projection.connection {
        case .connected: "checkmark.circle.fill"
        case .pairing: "arrow.triangle.2.circlepath"
        case .disconnected: "wifi.slash"
        case .unavailable: "questionmark.circle"
        case .permissionDenied: "lock.slash"
        case .failed: "exclamationmark.triangle.fill"
        }
    }
    private var connectionTint: Color {
        switch model.projection.connection {
        case .connected: AnchorPalette.mintInk
        case .pairing: AnchorPalette.sourceInk("sand")
        case .disconnected, .permissionDenied, .failed: AnchorPalette.coral
        case .unavailable: AnchorPalette.secondaryInk
        }
    }
    private func saveNote() {
        let captured = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !captured.isEmpty else { return }
        note = ""
        Task { await model.addNote(captured) }
    }

    private var primaryActionTitle: String {
        guard let presence = model.projection.session?.presence else { return L10n.openDetails }
        return presence == .away || presence == .returning
            ? L10n.continueWorking
            : L10n.openDetails
    }

    private var primaryActionSymbol: String {
        guard let presence = model.projection.session?.presence else { return "macwindow" }
        return presence == .away || presence == .returning ? "play.fill" : "macwindow"
    }

    private func primaryAction() {
        if let presence = model.projection.session?.presence,
           presence == .away || presence == .returning {
            onContinueWorking()
        } else {
            onOpenDetails()
        }
    }
}
#endif
