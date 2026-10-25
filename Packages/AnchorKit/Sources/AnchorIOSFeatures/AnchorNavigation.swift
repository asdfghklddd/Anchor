#if os(iOS)
import AnchorCore
import Foundation

public enum AnchorRoute: Hashable {
    case process(UUID)
    case insights
    case profile
    case history
    case historyDetail(UUID)
    case connections
    case sources
    case localData
}

enum ProfileDetailKind: Hashable {
    case focus
    case contexts
    case anchors
    case session
    case returnMemory
    case contextSnapshot
}

enum AnchorSheet: Hashable, Identifiable {
    case connections
    case hostedTasks
    case setup
    case note
    case goal
    case layout
    case finish
    case recovery(UUID)
    case account
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
