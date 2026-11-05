// Role: iPhone Settings. Every choice applies at once, so the only button is Close.
// Rule: no footers or slogans; show status at the end of a row; follow system settings instead of copying them.

#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI
import UIKit

/// Settings. Every choice applies as it is made, so the only way out is Close.
struct SettingsView<Destination: View>: View {
    let projection: SessionProjection
    @ViewBuilder let destination: (AnchorRoute) -> Destination

    @Environment(\.dismiss) private var dismiss
    @Environment(\.replayTour) private var replayTour
    @AppStorage(DeskPetKind.defaultsKey, store: ProfilePreferences.store) private var petKind = DeskPetKind.crab
    @AppStorage(AnchoringLog.goalKey) private var goalMinutes = AnchoringLog.defaultGoalMinutes
    @State private var editsGoal = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink(value: AnchorRoute.connections) {
                        SettingsRow(title: L10n.connections, symbol: "macbook.and.iphone", value: connectionValue)
                    }
                    .accessibilityIdentifier("settings.connections")
                    // The default build has no iCloud container, and a row that can only say so helps nobody.
                    if projection.durableSyncState != .notConfigured {
                        SettingsRow(title: AnchorStrings.value("settings.icloud", default: "iCloud Sync"), symbol: "icloud",
                                    value: projection.durableSyncState.label)
                            .accessibilityIdentifier("settings.icloud")
                    }
                }
                .listRowBackground(AnchorIOSStyle.surface)

                Section(AnchorStrings.value("settings.deskPet", default: "Desk pet")) {
                    DeskPetPicker(selection: $petKind)
                        .padding(.vertical, 6)
                }
                .listRowBackground(AnchorIOSStyle.surface)

                Section {
                    Button { editsGoal = true } label: {
                        HStack {
                            SettingsRow(title: SettingsCopy.goal, symbol: "target", value: ProfileFormat.time(TimeInterval(goalMinutes * 60)))
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .accessibilityIdentifier("settings.goal")
                    SettingsReminderRow()
                }
                .listRowBackground(AnchorIOSStyle.surface)

                Section {
                    NavigationLink(value: AnchorRoute.localData) {
                        SettingsRow(title: LocalDataCopy.title, symbol: "externaldrive", value: LocalDataCopy.everythingCount(
                            anchors: projection.hostedSessions.count, history: projection.archivedSessions.count))
                    }
                    .accessibilityIdentifier("settings.data")
                    Button {
                        dismiss()
                        // The tour takes over once this sheet is gone.
                        Task {
                            try? await Task.sleep(for: .milliseconds(450))
                            replayTour()
                        }
                    } label: {
                        SettingsRow(title: TourCopy.replay, symbol: "play.circle")
                    }
                    .accessibilityIdentifier("settings.tour.replay")
                    SettingsRow(title: SettingsCopy.version, symbol: "info.circle", value: version)
                        .accessibilityIdentifier("settings.version")
                }
                .listRowBackground(AnchorIOSStyle.surface)
            }
            .anchorIOSListSurface()
            .navigationTitle(L10n.settings)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: AnchorRoute.self) { destination($0) }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                        .accessibilityIdentifier("settings.close")
                }
            }
            .sheet(isPresented: $editsGoal) {
                HomeGoalPicker(minutes: $goalMinutes)
            }
        }
    }

    /// The Mac's name while it is connected; otherwise that it is not.
    private var connectionValue: String {
        guard projection.connection == .connected else { return PeerDeviceCopy.notConnected }
        return PeerDeviceMemory.last()?.displayName ?? PeerDeviceCopy.connected
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}

/// A label with a trailing value.
private struct SettingsRow: View {
    let title: String
    let symbol: String
    var value: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(AnchorPalette.interaction)
                .frame(width: 32, height: 32)
                .background(AnchorPalette.softBlue.opacity(0.62), in: .rect(cornerRadius: 9))
            Text(title).font(.subheadline.bold()).foregroundStyle(AnchorPalette.ink)
            if let value {
                Spacer(minLength: 8)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(AnchorIOSStyle.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(minHeight: 40)
        .accessibilityElement(children: .combine)
    }
}

/// How long after leaving Anchor the reminder comes, or Off. The system's
/// notification setting stays in charge: when it says no, the row leads there.
private struct SettingsReminderRow: View {
    @AppStorage(DeskReminder.enabledKey) private var enabled = true
    @AppStorage(DeskReminder.minutesKey) private var minutes = DeskReminder.defaultMinutes
    @Environment(\.scenePhase) private var scenePhase
    @State private var reminder = DeskReminder()

    var body: some View {
        Group {
            if reminder.authorization == .denied {
                Button(action: openSystemSettings) {
                    SettingsRow(title: SettingsCopy.reminder, symbol: "bell", value: SettingsCopy.reminderDenied)
                }
                .accessibilityIdentifier("settings.reminder.denied")
            } else {
                Picker(selection: choice) {
                    Text(SettingsCopy.reminderOff).tag(0)
                    ForEach(DeskReminder.minuteChoices, id: \.self) { Text(L10n.minuteCount($0)).tag($0) }
                } label: {
                    SettingsRow(title: SettingsCopy.reminder, symbol: "bell")
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.reminder")
            }
        }
        .task(id: scenePhase) { await reminder.refresh() }
    }

    /// Zero is Off. Choosing a time is the moment to ask for notifications.
    private var choice: Binding<Int> {
        Binding {
            enabled ? DeskReminder.minutes : 0
        } set: { value in
            enabled = value > 0
            if value > 0 { minutes = value }
            if value > 0, reminder.authorization == .notDetermined {
                Task { await reminder.requestAuthorization() }
            }
        }
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// Words for this page.
enum SettingsCopy {
    static let goal = AnchorStrings.value("settings.goal", default: "Daily goal")
    static let reminder = AnchorStrings.value("settings.reminder", default: "Reminder when you leave")
    static let reminderOff = AnchorStrings.value("settings.reminder.off", default: "Off")
    static let reminderDenied = AnchorStrings.value("settings.reminder.denied", default: "Notifications off")
    static let version = AnchorStrings.value("settings.version", default: "Version")
}

private extension DurableSyncState {
    var label: String {
        switch self {
        case .notConfigured: AnchorStrings.value("sync.state.notConfigured", default: "Not configured")
        case .idle: AnchorStrings.value("sync.state.idle", default: "Waiting to sync")
        case .syncing: AnchorStrings.value("sync.state.syncing", default: "Syncing")
        case .available: AnchorStrings.value("sync.state.available", default: "Last sync succeeded")
        case .offline: AnchorStrings.value("sync.state.offline", default: "Offline")
        case .failed: AnchorStrings.value("sync.state.failed", default: "Sync failed")
        }
    }
}
#endif
