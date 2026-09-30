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

    var body: some View {
        Form {
            Section(L10n.notificationsSettings) {
                Text(AnchorStrings.value("notifications.availability", default: "Review decisions and process changes in Anchor. Background notifications are not available in this version."))
            }
            .listRowBackground(AnchorIOSStyle.surface)
        }
        .anchorIOSListSurface()
        .navigationTitle(L10n.notificationsSettings)
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
