#if os(macOS)
import Foundation

enum MacWorkRoute: Hashable {
    case process(UUID)
    case timeline
}
#endif
