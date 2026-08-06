#if os(macOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct MacProcessManagementView: View {
    let model: AnchorSessionModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var processes: [AnchorProcess]
    @State private var saveError: String?
    @State private var isReordering = false

    init(model: AnchorSessionModel) {
        self.model = model
        _processes = State(initialValue: model.projection.session?.processes ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
            ScrollView {
                VStack(alignment: .leading, spacing: AnchorSpacing.medium) {
                    Text(L10n.moveHint)
                        .font(.callout)
                        .foregroundStyle(AnchorPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(L10n.processes)
                        .font(.headline.bold())
                        .foregroundStyle(AnchorPalette.ink)

                    LazyVStack(spacing: AnchorSpacing.small) {
                        ForEach(Array(processes.enumerated()), id: \.element.id) { index, process in
                            processRow(process, index: index)
                        }
                    }

                    if let saveError {
                        Label(saveError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(AnchorPalette.coral)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AnchorSpacing.large)
            }
            .accessibilityIdentifier("mac.process.management.list")

            HStack {
                Text(L10n.localOnly)
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
                Spacer()
                Button {
                    isReordering.toggle()
                } label: {
                    Label(
                        isReordering ? L10n.done : L10n.reorderProcesses,
                        systemImage: isReordering ? "checkmark" : "arrow.up.arrow.down"
                    )
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("mac.process.management.reorder")
                Button(L10n.done, action: dismiss.callAsFunction)
                    .buttonStyle(.borderedProminent)
                    .tint(AnchorPalette.deepSea)
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("mac.process.management.done")
            }
            .padding(.horizontal, AnchorSpacing.large)
            .padding(.bottom, AnchorSpacing.large)
        }
        .navigationTitle(L10n.taskManagement)
        .frame(minWidth: 620, idealWidth: 720, minHeight: 480)
    }

    private func processRow(_ process: AnchorProcess, index: Int) -> some View {
        HStack(alignment: .center, spacing: AnchorSpacing.small) {
            SourceMark(symbol: process.sourceSymbol, tone: process.sourceTone, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(process.sourceName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AnchorPalette.sourceInk(process.sourceTone))
                Text(process.title)
                    .font(.headline)
                    .foregroundStyle(AnchorPalette.ink)
                    .lineLimit(2)
                Text(L10n.status(process.status))
                    .font(.caption)
                    .foregroundStyle(AnchorPalette.secondaryInk)
            }

            Spacer(minLength: AnchorSpacing.small)

            if isReordering {
                HStack(spacing: AnchorSpacing.xSmall) {
                    Button(L10n.moveUp, systemImage: "chevron.up") {
                        moveProcess(processID: process.id, by: -1)
                    }
                    .disabled(index == 0)

                    Button(L10n.moveDown, systemImage: "chevron.down") {
                        moveProcess(processID: process.id, by: 1)
                    }
                    .disabled(index == processes.count - 1)
                }
                .buttonStyle(.borderless)
            }

            Menu {
                ForEach(ProcessTileSize.allCases, id: \.self) { size in
                    Button {
                        updateSize(processID: process.id, size: size)
                    } label: {
                        if process.tileSize == size {
                            Label(L10n.tileSize(size), systemImage: "checkmark")
                        } else {
                            Text(L10n.tileSize(size))
                        }
                    }
                }
            } label: {
                Label(L10n.tileSize(process.tileSize), systemImage: "rectangle.resize")
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel(L10n.layout)
            .accessibilityValue(L10n.tileSize(process.tileSize))
            .accessibilityIdentifier("mac.process.management.layout")
        }
        .padding(AnchorSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AnchorPalette.surface, in: .rect(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AnchorPalette.ink.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.process.management.row")
    }

    private func moveProcess(processID: UUID, by offset: Int) {
        guard let sourceIndex = processes.firstIndex(where: { $0.id == processID }) else { return }
        let destinationIndex = sourceIndex + offset
        guard processes.indices.contains(destinationIndex) else { return }

        withAnimation(reduceMotion ? nil : .snappy) {
            processes.swapAt(sourceIndex, destinationIndex)
        }
        persistOrder()
    }

    private func persistOrder() {
        let orderedIDs = processes.map(\.id)
        Task {
            guard await model.send(.reorderProcesses(orderedIDs)) else {
                saveError = model.lastError ?? L10n.actionFailed
                return
            }
                saveError = nil
        }
    }

    private func updateSize(processID: UUID, size: ProcessTileSize) {
        guard let index = processes.firstIndex(where: { $0.id == processID }) else { return }
        let previousSize = processes[index].tileSize
        processes[index].tileSize = size

        Task {
            guard await model.send(.updateTileSize(processID: processID, size: size)) else {
                if let currentIndex = processes.firstIndex(where: { $0.id == processID }) {
                    processes[currentIndex].tileSize = previousSize
                }
                saveError = model.lastError ?? L10n.actionFailed
                return
            }
            saveError = nil
        }
    }
}
#endif
