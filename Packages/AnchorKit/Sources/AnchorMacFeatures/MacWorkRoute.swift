#if os(macOS)
import Foundation

enum MacWorkRoute: Hashable {
    case process(UUID)
    case timeline
    /// The selected task's full record.
    case task
}
#endif
