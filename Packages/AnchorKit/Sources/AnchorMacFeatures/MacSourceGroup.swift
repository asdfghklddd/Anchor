#if os(macOS)
import AnchorCore
import AnchorDesign
import Foundation

struct MacSourceGroup: Identifiable, Hashable {
    let sourceName: String
    let sourceSymbol: String
    let sourceTone: String
    let processes: [AnchorProcess]

    var id: String { sourceName }

    var status: ProcessStatus {
        guard !processes.isEmpty else { return .disconnected }

        for candidate in Self.statusPriority {
            if processes.contains(where: { $0.status == candidate }) {
                return candidate
            }
        }
        return processes[0].status
    }

    var progress: Double? {
        let values = processes.compactMap(\.progress)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var runningCount: Int {
        processes.filter { $0.status == .running }.count
    }

    var completedCount: Int {
        processes.filter { $0.status == .completed }.count
    }

    var attentionCount: Int {
        processes.filter { $0.status == .needsDecision }.count
    }

    var eventCount: Int {
        processes.reduce(0) { $0 + $1.events.count }
    }

    var latestEvent: ProcessEvent? {
        processes
            .flatMap(\.events)
            .max { lhs, rhs in lhs.occurredAt < rhs.occurredAt }
    }

    var lastUpdated: Date {
        processes.map(\.updatedAt).max() ?? .distantPast
    }

    var estimatedCompletion: String? {
        processes
            .sorted { Self.statusRank($0.status) < Self.statusRank($1.status) }
            .first(where: { !$0.estimatedCompletion.isEmpty })?
            .estimatedCompletion
    }

    var accessibilityValue: String {
        var values = [
            L10n.status(status),
            L10n.processCount(processes.count),
        ]
        if let progress {
            values.append(progress.formatted(.percent.precision(.fractionLength(0))))
        }
        if let latestEvent {
            values.append(latestEvent.title)
        }
        return values.joined(separator: ", ")
    }

    init(processes: [AnchorProcess]) {
        self.processes = processes
        sourceName = processes.first?.sourceName ?? L10n.unknown
        sourceSymbol = processes.first?.sourceSymbol ?? "?"
        sourceTone = processes.first?.sourceTone ?? "ink"
    }

    static func groups(from processes: [AnchorProcess]) -> [MacSourceGroup] {
        var sourceOrder: [String] = []
        var buckets: [String: [AnchorProcess]] = [:]

        for process in processes {
            if buckets[process.sourceName] == nil {
                sourceOrder.append(process.sourceName)
            }
            buckets[process.sourceName, default: []].append(process)
        }

        return sourceOrder.compactMap { sourceName in
            guard let processes = buckets[sourceName], !processes.isEmpty else { return nil }
            return MacSourceGroup(processes: processes)
        }
    }

    private static let statusPriority: [ProcessStatus] = [
        .needsDecision,
        .failed,
        .blocked,
        .disconnected,
        .running,
        .queued,
        .completed,
    ]

    private static func statusRank(_ status: ProcessStatus) -> Int {
        statusPriority.firstIndex(of: status) ?? statusPriority.count
    }
}
#endif
