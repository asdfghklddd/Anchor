#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

struct SourceSettingsView: View {
    let projection: SessionProjection

    var body: some View {
        List {
            Section(L10n.sourceHealth) {
                ForEach(projection.session?.processes ?? []) { process in
                    HStack {
                        Text(process.sourceSymbol)
                            .font(.headline.bold())
                            .frame(width: 38, height: 38)
                            .background(
                                AnchorPalette.source(process.sourceTone).opacity(0.55),
                                in: .rect(cornerRadius: 11)
                            )
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(process.sourceName).font(.headline)
                            Text(process.updatedAt, style: .relative).font(.caption)
                        }
                        Spacer()
                        Label(L10n.status(process.status), systemImage: process.status == .disconnected ? "wifi.slash" : "checkmark.circle")
                            .labelStyle(.iconOnly)
                            .accessibilityLabel(L10n.status(process.status))
                    }
                    .frame(minHeight: 52)
                }
            }
            .listRowBackground(AnchorIOSStyle.surface)
        }
        .anchorIOSListSurface()
        .navigationTitle(L10n.sources)
    }
}

struct NotificationSettingsView: View {
    @AppStorage(DeskReminder.enabledKey) private var reminderEnabled = true
    @AppStorage(DeskReminder.minutesKey) private var reminderMinutes = DeskReminder.defaultMinutes
    @State private var reminder = DeskReminder()

    var body: some View {
        Form {
            Section {
                Toggle(DeskText.settingsToggle, isOn: $reminderEnabled)
                    .accessibilityIdentifier("settings.desk-reminder")
                if reminderEnabled {
                    Picker(DeskText.settingsDelay, selection: $reminderMinutes) {
                        ForEach(DeskReminder.minuteChoices, id: \.self) { minutes in
                            Text(L10n.minutesShort(minutes)).tag(minutes)
                        }
                    }
                    switch reminder.authorization {
                    case .notDetermined:
                        Button(DeskText.settingsAllow) { Task { await reminder.requestAuthorization() } }
                    case .denied:
                        Text(DeskText.settingsDenied).foregroundStyle(AnchorIOSStyle.secondaryText)
                        Button(DeskText.settingsOpen) { DeskReminder.openSystemSettings() }
                    default:
                        EmptyView()
                    }
                }
            } header: {
                Text(DeskText.settingsSection)
            } footer: {
                Text(DeskText.settingsFooter)
            }
            .listRowBackground(AnchorIOSStyle.surface)
            Section(L10n.notificationsSettings) {
                Text(AnchorStrings.value("notifications.availability", default: "Results from your agents show in Anchor. An alert on this iPhone when an agent finishes is not available yet."))
            }
            .listRowBackground(AnchorIOSStyle.surface)
        }
        .anchorIOSListSurface()
        .navigationTitle(L10n.notificationsSettings)
        .task { await reminder.refresh() }
    }
}

struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section {
                Label(L10n.localOnly, systemImage: "lock.shield.fill")
                    .font(.headline)
                Text(L10n.localOnlyDetail)
            }
            .listRowBackground(AnchorIOSStyle.surface)
            Section(L10n.sources) {
                Label(L10n.connections, systemImage: "network")
                Label(L10n.bluetoothProximity, systemImage: "dot.radiowaves.left.and.right")
            }
            .listRowBackground(AnchorIOSStyle.surface)
        }
        .anchorIOSListSurface()
        .navigationTitle(L10n.privacy)
    }
}

struct AccessibilitySettingsView: View {
    @AppStorage(AnchorMotion.reduceMotionDefaultsKey) private var reduceMotion = false

    var body: some View {
        Form {
            Section {
                Label(L10n.displaySupport, systemImage: "accessibility")
                    .font(.headline)
                Text(L10n.displaySupportDetail)
            }
            .listRowBackground(AnchorIOSStyle.surface)
            Section {
                Label(L10n.voiceOver, systemImage: "speaker.wave.3")
                Label(L10n.dynamicType, systemImage: "textformat.size")
                Toggle(L10n.reduceMotion, isOn: $reduceMotion)
                    .accessibilityIdentifier("settings.reduceMotion")
                Label(L10n.increaseContrast, systemImage: "circle.lefthalf.filled")
                Label(L10n.reduceTransparency, systemImage: "square.on.square")
            }
            .listRowBackground(AnchorIOSStyle.surface)
        }
        .anchorIOSListSurface()
        .navigationTitle(L10n.accessibility)
    }
}

#endif
