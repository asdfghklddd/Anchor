#if os(iOS)
import AnchorCore
import AnchorDesign
import SwiftUI

/// A compact presentation of the existing local-link controller, without owning transport state.
struct ConnectionSettingsView: View {
    let projection: SessionProjection
    let controller: (any LocalLinkControlling)?
    @AppStorage(AnchorMotion.reduceMotionDefaultsKey) private var reduceMotion = false
    @State private var logoRevealed = false
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let layout = verticalSizeClass == .compact
            ? AnyLayout(HStackLayout(spacing: 20)) : AnyLayout(VStackLayout(spacing: 12))
        ScrollView {
            VStack(spacing: 12) {
                Text("Anchor")
                    .font(.title2.bold()).foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(alignment: .trailing) {
                        Button(action: dismiss.callAsFunction) {
                            Image(systemName: "xmark").font(.caption.bold())
                                .frame(width: 28, height: 28)
                                .background(AnchorIOSStyle.border.opacity(0.5), in: .circle)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(L10n.close)
                        .accessibilityIdentifier("connections.close")
                    }
                layout {
                    ConnectionBrandGlyph()
                        .fill(LinearGradient(colors: [Color(red: 0, green: 0.82, blue: 0.94), Color(red: 0, green: 0.60, blue: 0.98)], startPoint: .top, endPoint: .bottom), style: FillStyle(eoFill: true))
                        .frame(width: verticalSizeClass == .compact ? 110 : 158, height: verticalSizeClass == .compact ? 110 : 158)
                        .accessibilityHidden(true)
                        .scaleEffect(reduceMotion || logoRevealed ? 1 : 0.96)
                        .opacity(reduceMotion || logoRevealed ? 1 : 0)
                        .padding(.vertical, 4)
                    if let controller {
                        ConnectionPairingSection(controller: controller, connection: projection.connection, proximity: projection.proximity)
                    } else {
                        Label(L10n.disconnected, systemImage: "wifi.slash")
                            .font(.subheadline).foregroundStyle(AnchorIOSStyle.secondaryText)
                        Text(L10n.connectionUnknownDetail).font(.caption)
                    }
                }
            }
            .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 16)
            .frame(maxWidth: 500).frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(AnchorIOSStyle.surface)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("connections.screen")
        .task(id: reduceMotion) {
            guard !reduceMotion else {
                logoRevealed = true
                return
            }
            guard !logoRevealed else { return }
            // Let the native sheet start moving before revealing its decorative mark.
            // Cancellation prevents a dismissed card from finishing a delayed entrance.
            do { try await Task.sleep(for: .milliseconds(80)) }
            catch { return }
            guard !Task.isCancelled else { return }
            withAnimation(AnchorMotion.panel) { logoRevealed = true }
        }
    }
}
#endif
