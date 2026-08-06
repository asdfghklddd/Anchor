#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacSessionSummaryView: View {
    let model: AnchorSessionModel

    @Environment(\.dismiss) private var dismiss
    @State private var showingCompletionConfirmation = false

    private var session: AnchorSession? { model.projection.session }

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.large) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AnchorSpacing.xSmall) {
                    Text(L10n.sessionSummary)
                        .font(.title.bold())
                    Text(session?.goal.title ?? L10n.emptyTitle)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(L10n.close, action: dismiss.callAsFunction)
                    .buttonStyle(.borderless)
            }

            if let session {
                AnchorCard(tint: AnchorPalette.seafoam) {
                    VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                        Label(
                            session.status == .completed ? L10n.completed : L10n.currentWork,
                            systemImage: session.status == .completed
                                ? "checkmark.seal.fill"
                                : "scope"
                        )
                        .font(.headline)
                        .foregroundStyle(session.status == .completed ? AnchorPalette.mintInk : AnchorPalette.deepSea)

                        Divider()

                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.processes.count, format: .number)
                                    .font(.title3.bold().monospacedDigit())
                                Text(L10n.processes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Divider()
                                .frame(height: 34)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.notes.count, format: .number)
                                    .font(.title3.bold().monospacedDigit())
                                Text(L10n.notes)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Divider()
                                .frame(height: 34)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.decisions.filter { $0.status == .resolved }.count, format: .number)
                                    .font(.title3.bold().monospacedDigit())
                                Text(L10n.decisions)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                if session.status == .completed {
                    Button(L10n.resume, action: resumeSession)
                        .buttonStyle(.borderedProminent)
                        .tint(AnchorPalette.deepSea)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("mac.session.summary.action")
                } else {
                    Button(L10n.completeSession) {
                        showingCompletionConfirmation = true
                    }
                        .buttonStyle(.borderedProminent)
                        .tint(AnchorPalette.deepSea)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("mac.session.summary.action")
                }
            } else {
                ContentUnavailableView(L10n.emptyTitle, systemImage: "scope")
            }
        }
        .padding(AnchorSpacing.xLarge)
        .frame(minWidth: 520, idealWidth: 520, maxWidth: 520, minHeight: 360)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.session.summary")
        .confirmationDialog(
            L10n.finishConfirmTitle,
            isPresented: $showingCompletionConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.completeSession, action: completeSession)
                .keyboardShortcut(.defaultAction)
            Button(L10n.cancel, role: .cancel) { }
        } message: {
            Text(L10n.finishConfirmDetail)
        }
    }

    private func completeSession() {
        Task {
            guard await model.send(.completeSession) else { return }
            dismiss()
        }
    }

    private func resumeSession() {
        Task {
            guard await model.send(.resumeSession) else { return }
            dismiss()
        }
    }
}
#endif
