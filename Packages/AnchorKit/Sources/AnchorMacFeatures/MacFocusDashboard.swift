#if os(macOS)
import AnchorCore
import SwiftUI

struct MacFocusDashboard: View {
    let model: AnchorSessionModel
    let showsCompletedSessionInCurrentWork: Bool
    let onOpenProcess: (UUID) -> Void
    let onOpenTimeline: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        if let session = model.projection.session,
           MacCurrentTaskPresentation.showsInForeground(
               session.status,
               includingCompleted: showsCompletedSessionInCurrentWork
           ) {
            MacWorkOverviewView(
                model: model,
                session: session,
                onOpenProcess: onOpenProcess,
                onOpenTimeline: onOpenTimeline
            )
        } else {
            MacEmptyWorkView(
                projection: model.projection,
                onOpenTimeline: onOpenTimeline,
                onOpenSettings: onOpenSettings
            )
        }
    }
}

enum MacCurrentTaskPresentation {
    static func showsInForeground(
        _ status: SessionStatus?,
        includingCompleted: Bool
    ) -> Bool {
        switch status {
        case .draft, .active:
            true
        case .completed:
            includingCompleted
        case .archived, nil:
            false
        }
    }
}
#endif
