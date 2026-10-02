#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacProcessDetailView: View {
    let model: AnchorSessionModel
    let processID: UUID
    let onOpenTimeline: () -> Void

    var body: some View {
        Group {
            if let session = model.projection.session,
               let process = session.processes.first(where: { $0.id == processID }) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AnchorSpacing.xLarge) {
                        MacProcessDetailHeader(process: process)
                        Button(L10n.viewFullTimeline, systemImage: "waveform.path.ecg", action: onOpenTimeline)
                            .buttonStyle(.borderless)

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

}
#endif
