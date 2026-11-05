// Role: every route, sheet and full-screen cover in the iPhone app. Start here to find how a page is reached.

#if os(iOS)
import AnchorCore
import Foundation

/// Pushed pages in the navigation stack.
public enum AnchorRoute: Hashable {
    case process(UUID)
    case insights
    case profile
    case history
    case historyDetail(UUID)
    case connections
    case source(String)
    case localData
}

/// What `ProfileDetailSheet` can show.
enum ProfileDetailKind: Hashable {
    case session
    case returnMemory
    case contextSnapshot
}

/// Sheets over the workspace.
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

/// Full-screen covers. The return page is the only one.
enum AnchorFullScreen: Hashable, Identifiable {
    case returning

    var id: Self { self }
}
#endif
