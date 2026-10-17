import Foundation

/// User-authored steps. Image files are stored locally by goal ID, outside sync payloads.
///
/// Only the person marks a step done: agent results are evidence to look at,
/// never proof that a step of their plan is finished.
public struct AnchorUserPlan: Codable, Hashable, Sendable {
    public var steps: [String]
    public var localImageNames: [String]
    /// Indices of the steps the person marked done, ascending and unique.
    public private(set) var completedSteps: [Int]
    /// When the person last answered whether a step is done. Agent results
    /// after this moment are ones they have not looked at yet.
    public private(set) var reviewedAt: Date?

    public init(
        steps: [String],
        localImageNames: [String] = [],
        completedSteps: [Int] = [],
        reviewedAt: Date? = nil
    ) {
        self.steps = steps
        self.localImageNames = localImageNames
        self.completedSteps = Array(Set(completedSteps)).sorted()
        self.reviewedAt = reviewedAt
    }

    private enum CodingKeys: String, CodingKey {
        case steps, localImageNames, completedSteps, reviewedAt
    }

    // Plans saved before steps could be checked off decode as nothing done yet.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            steps: try values.decode([String].self, forKey: .steps),
            localImageNames: try values.decodeIfPresent([String].self, forKey: .localImageNames) ?? [],
            completedSteps: try values.decodeIfPresent([Int].self, forKey: .completedSteps) ?? [],
            reviewedAt: try values.decodeIfPresent(Date.self, forKey: .reviewedAt)
        )
    }

    public func isDone(_ index: Int) -> Bool {
        completedSteps.contains(index)
    }

    /// The first step not yet marked done, in the person's own order.
    public var nextStepIndex: Int? {
        steps.indices.first { !isDone($0) }
    }

    public var doneCount: Int {
        completedSteps.filter(steps.indices.contains).count
    }

    public var isFinished: Bool {
        !steps.isEmpty && nextStepIndex == nil
    }

    /// Answering for a step is also looking at the results that led to it.
    public func marking(step index: Int, done: Bool, at date: Date) -> AnchorUserPlan? {
        guard steps.indices.contains(index) else { return nil }
        var plan = self
        if done {
            plan.completedSteps = Array(Set(completedSteps + [index])).sorted()
        } else {
            plan.completedSteps.removeAll { $0 == index }
        }
        plan.reviewedAt = date
        return plan
    }

    /// "Not yet": the results were seen, and the step stays open.
    public func markingReviewed(at date: Date) -> AnchorUserPlan {
        var plan = self
        plan.reviewedAt = date
        return plan
    }
}
