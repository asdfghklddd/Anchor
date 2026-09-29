import Foundation

/// User-authored steps. Image files are stored locally by goal ID, outside sync payloads.
public struct AnchorUserPlan: Codable, Hashable, Sendable {
    public var steps: [String]
    public var localImageNames: [String]

    public init(steps: [String], localImageNames: [String] = []) {
        self.steps = steps
        self.localImageNames = localImageNames
    }
}
