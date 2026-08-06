#if os(macOS)
import AnchorCore
import AppKit
import Foundation
import ServiceManagement
import UserNotifications

enum MacLaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

@MainActor
final class MacDecisionNotificationService {
    private var hasObservedInitialProjection = false
    private var observedDecisionIDs = Set<UUID>()

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        )) ?? false
    }

    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    static func removePendingDecisionNotifications() async {
        let center = UNUserNotificationCenter.current()
        let requests = await center.pendingNotificationRequests()
        let identifiers = requests.map(\.identifier).filter { $0.hasPrefix("anchor.decision.") }
        guard !identifiers.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func observe(_ projection: SessionProjection, enabled: Bool) {
        let currentDecisionIDs = Set(projection.openDecisions.map(\.id))
        guard hasObservedInitialProjection else {
            hasObservedInitialProjection = true
            observedDecisionIDs = currentDecisionIDs
            return
        }

        let newlyOpened = projection.openDecisions.filter {
            !observedDecisionIDs.contains($0.id)
        }
        observedDecisionIDs = currentDecisionIDs

        guard enabled else { return }
        for decision in newlyOpened {
            Task {
                await Self.schedule(decision)
            }
        }
    }

    private static func schedule(_ decision: Decision) async {
        let content = UNMutableNotificationContent()
        content.title = decision.title
        content.body = decision.prompt
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "anchor.decision.\(decision.id.uuidString)",
            content: content,
            trigger: nil
        )
        try? await UNUserNotificationCenter.current().add(request)
    }
}
#endif
