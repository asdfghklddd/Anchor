import Foundation

/// Separates user-owned task structure from observed runs and ambient app state.
public enum ProcessPresentationGroup: Hashable, Sendable {
    case planned
    case observedTask
    case environment
}

public extension AnchorProcess {
    var presentationGroup: ProcessPresentationGroup {
        guard let sourceID else { return .planned }
        if sourceID == BuiltInProcessSourceID.macWorkspace {
            return .environment
        }
        return .observedTask
    }
}

public extension AnchorSession {
    var plannedProcesses: [AnchorProcess] {
        processes.filter { $0.presentationGroup == .planned }
    }

    var observedTaskProcesses: [AnchorProcess] {
        processes.filter { $0.presentationGroup == .observedTask }
    }

    var environmentProcesses: [AnchorProcess] {
        processes.filter { $0.presentationGroup == .environment }
    }

    var taskProcesses: [AnchorProcess] {
        processes.filter { $0.presentationGroup != .environment }
    }
}
