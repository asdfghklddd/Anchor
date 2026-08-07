import AnchorCore
import Foundation

public enum DemoScenario: String, Codable, CaseIterable, Identifiable, Sendable {
    case active
    case needsDecision
    case away18Minutes
    case returning
    case completed
    case empty
    case disconnected
    case permissionDenied
    case staleData
    case retryableError

    public var id: String { rawValue }
}

public protocol DemoControlling: Sendable, CurrentProcessProviding {
    func activeScenario() async -> DemoScenario
    func switchScenario(to scenario: DemoScenario) async
    func playScenario(to scenario: DemoScenario) async
    func reset() async
}
