import Foundation

/// User-authored steps. Image files are stored locally by goal ID, outside sync payloads.
///
/// Only the person marks a step done: agent results are evidence to look at,
/// never proof that a step of their plan is finished. Each step keeps its own
/// identity, so renaming, reordering and deleting never move a checkmark.
public struct AnchorUserPlan: Codable, Hashable, Sendable {
    public struct Step: Codable, Hashable, Sendable, Identifiable {
        public let id: UUID
        public var text: String
        /// When the person marked this step done; `nil` while it is open.
        public var completedAt: Date?

        public var isDone: Bool { completedAt != nil }

        public init(id: UUID = UUID(), text: String, completedAt: Date? = nil) {
            self.id = id
            self.text = text
            self.completedAt = completedAt
        }
    }

    public private(set) var items: [Step]
    public var localImageNames: [String]
    /// When the person last answered whether a step is done. Agent results
    /// after this moment are ones they have not looked at yet.
    public private(set) var reviewedAt: Date?

    public init(items: [Step], localImageNames: [String] = [], reviewedAt: Date? = nil) {
        self.items = Self.normalized(items)
        self.localImageNames = localImageNames
        self.reviewedAt = reviewedAt
    }

    /// New steps from text, as setup writes them; `completedSteps` are positions.
    public init(
        steps: [String],
        localImageNames: [String] = [],
        completedSteps: [Int] = [],
        reviewedAt: Date? = nil
    ) {
        let done = Set(completedSteps)
        self.init(
            items: steps.enumerated().map { index, text in
                Step(text: text, completedAt: done.contains(index) ? (reviewedAt ?? .now) : nil)
            },
            localImageNames: localImageNames,
            reviewedAt: reviewedAt
        )
    }

    // MARK: Reading

    public var steps: [String] { items.map(\.text) }

    /// Positions of the steps marked done, in plan order.
    public var completedSteps: [Int] { items.indices.filter { items[$0].isDone } }

    public func isDone(_ index: Int) -> Bool {
        items.indices.contains(index) && items[index].isDone
    }

    /// The first step not yet marked done, in the person's own order.
    public var nextStepIndex: Int? {
        items.firstIndex { !$0.isDone }
    }

    public var doneCount: Int { items.filter(\.isDone).count }

    public var isFinished: Bool { !items.isEmpty && nextStepIndex == nil }

    public func index(of id: UUID) -> Int? {
        items.firstIndex { $0.id == id }
    }

    // MARK: Changing

    /// Answering for a step is also looking at the results that led to it.
    public func marking(stepID: UUID, done: Bool, at date: Date) -> AnchorUserPlan? {
        guard let index = index(of: stepID) else { return nil }
        var plan = self
        if done != plan.items[index].isDone {
            plan.items[index].completedAt = done ? date : nil
        }
        plan.reviewedAt = date
        return plan
    }

    public func marking(step index: Int, done: Bool, at date: Date) -> AnchorUserPlan? {
        guard items.indices.contains(index) else { return nil }
        return marking(stepID: items[index].id, done: done, at: date)
    }

    /// "Not yet": the results were seen, and the step stays open.
    public func markingReviewed(at date: Date) -> AnchorUserPlan {
        var plan = self
        plan.reviewedAt = date
        return plan
    }

    /// The person's edited list: kept steps keep their identity and done state,
    /// blank lines disappear, and a plan always keeps at least one step.
    public func replacingSteps(with edited: [Step]) -> AnchorUserPlan? {
        let kept = Self.normalized(edited)
        guard !kept.isEmpty else { return nil }
        var plan = self
        plan.items = kept
        return plan
    }

    private static func normalized(_ items: [Step]) -> [Step] {
        var seen = Set<UUID>()
        return items.compactMap { item in
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, seen.insert(item.id).inserted else { return nil }
            return Step(id: item.id, text: text, completedAt: item.completedAt)
        }
    }

    // MARK: Coding

    private enum CodingKeys: String, CodingKey {
        case items, steps, localImageNames, completedSteps, reviewedAt
    }

    /// Plans saved before steps had identity derive the same IDs on every
    /// device from position and text, so a checkmark means the same step everywhere.
    private static let legacyNamespace = UUID(uuidString: "A7C10000-5EED-4C0A-9D1E-000000000001")!

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let images = try values.decodeIfPresent([String].self, forKey: .localImageNames) ?? []
        let reviewed = try values.decodeIfPresent(Date.self, forKey: .reviewedAt)
        if let items = try values.decodeIfPresent([Step].self, forKey: .items) {
            self.init(items: items, localImageNames: images, reviewedAt: reviewed)
            return
        }
        let texts = try values.decode([String].self, forKey: .steps)
        let done = Set(try values.decodeIfPresent([Int].self, forKey: .completedSteps) ?? [])
        self.init(
            items: texts.enumerated().map { index, text in
                Step(
                    id: StableProcessIdentity.id(namespace: "anchor.plan.step", sessionID: Self.legacyNamespace,
                                                 externalID: "\(index)|\(text)"),
                    text: text,
                    completedAt: done.contains(index) ? (reviewed ?? .distantPast) : nil
                )
            },
            localImageNames: images,
            reviewedAt: reviewed
        )
    }

    // Plain texts are written as well, so a build that predates step identity still reads the plan.
    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(items, forKey: .items)
        try values.encode(steps, forKey: .steps)
        try values.encode(localImageNames, forKey: .localImageNames)
        try values.encodeIfPresent(reviewedAt, forKey: .reviewedAt)
    }
}
