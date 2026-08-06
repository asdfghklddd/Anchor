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

enum ProfileDetailKind: Hashable {
    case focus
    case contexts
    case anchors
    case session
    case returnMemory
    case decisionTrace
    case contextSnapshot
}

enum AnchorSheet: Hashable, Identifiable {
    case setup
    case note
    case goal
    case notifications
    case decision(UUID)
    case layout
    case finish
    case account
    case icloud
    case profileDetail(ProfileDetailKind)

    var id: Self { self }
}

enum AnchorFullScreen: Hashable, Identifiable {
    case handingOff
    case away
    case returning

    var id: Self { self }
}
#endif
