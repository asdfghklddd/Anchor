#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacProcessDetailView: View {
    let model: AnchorSessionModel
    let processID: UUID
    let onOpenTimeline: () -> Void

    @State private var selectedOptionID: UUID?

    var body: some View {
        Group {
            if let session = model.projection.session,
               let process = session.processes.first(where: { $0.id == processID }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AnchorSpacing.xLarge) {
                        MacProcessDetailHeader(process: process)
                        Button(L10n.viewFullTimeline, systemImage: "waveform.path.ecg", action: onOpenTimeline)
                            .buttonStyle(.borderless)

                        if let decision = session.decisions.first(where: {
                            $0.processID == process.id && $0.status == .open
                        }) {
                            MacDecisionPanel(
                                decision: decision,
                                selectedOptionID: $selectedOptionID,
                                onResolve: resolve
                            )
                            .padding(AnchorSpacing.large)
                            .fluoriteSurface(
                                fill: AnchorPalette.sand.opacity(0.11),
                                border: AnchorPalette.sand.opacity(0.36),
                                cornerRadius: 18
                            )
                        }

                        MacProcessEventTimeline(events: process.events)
                    }
                    .frame(maxWidth: 880, alignment: .leading)
                    .padding(.horizontal, AnchorSpacing.xLarge)
                    .padding(.vertical, AnchorSpacing.large)
                }
                .background(.clear)
                .navigationTitle(L10n.processDetails)
                .accessibilityIdentifier("mac.process.detail")
            } else {
                ContentUnavailableView(
                    L10n.processDetails,
                    systemImage: "questionmark.square.dashed",
                    description: Text(L10n.noEvents)
                )
                .navigationTitle(L10n.processDetails)
            }
        }
    }

    private func resolve(_ decision: Decision, option: DecisionOption) {
        selectedOptionID = nil
        Task { await model.resolve(decision: decision, option: option) }
    }
}
#endif
