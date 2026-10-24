import AnchorCore
import Foundation

/// The writer that needs no model, so names exist offline and before any API
/// is set up: the conversation's own name or the gist of its first request.
public struct LocalSummarizer: AnchorSummarizer {
    public init() {}

    public func conversationName(_ source: ConversationNameSource) async throws -> String {
        source.gist ?? ""
    }
}
