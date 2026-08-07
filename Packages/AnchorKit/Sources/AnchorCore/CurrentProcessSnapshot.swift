import Foundation

/// A small, privacy-conscious snapshot used to seed a new Anchor session.
/// It contains names only; raw application content and prompts never cross the
/// device link as part of the setup flow.
public struct CurrentProcessSnapshot: Codable, Hashable, Sendable {
    public let capturedAt: Date
    public let processNames: [String]

    public init(processNames: [String], capturedAt: Date = .now) {
        self.capturedAt = capturedAt
        self.processNames = Self.normalizedNames(processNames)
    }

    private static func normalizedNames(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.compactMap { rawName in
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, seen.insert(name.lowercased()).inserted else { return nil }
            return name
        }
    }
}

/// Supplies the Mac's current process names when the user opens New Work.
/// Providers may fail or return an empty snapshot; the setup form must remain
/// fully usable with manual entry in either case.
public protocol CurrentProcessProviding: Sendable {
    func currentProcessSnapshot() async throws -> CurrentProcessSnapshot
}
