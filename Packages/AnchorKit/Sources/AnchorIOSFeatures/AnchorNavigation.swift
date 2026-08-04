#if os(iOS)
import AnchorCore
import Foundation

public enum AnchorRoute: Hashable {
    case process(UUID)
    case insights
    case profile
    case history
    case historyDetail(UUID)
    case taskManagement
    case connections
    case sources
    case notificationSettings
    case privacy
    case accessibility
}

enum AnchorSheet: Hashable, Identifiable {
    case note
    case goal
    case notifications
    case decision(UUID)
    case layout
    case finish

    var id: Self { self }
}

enum AnchorFullScreen: Hashable, Identifiable {
    case handingOff
    case away
    case returning

    var id: Self { self }
}
#endif
