// Role: SwiftUI wrapper exposing `MacSettingsView` to the app target.

#if os(macOS)
import AnchorCore
import SwiftUI

/// What the settings window hosts.
public struct AnchorMacSettingsScene: View {
    private let model: AnchorSessionModel
    private let controller: (any LocalLinkControlling)?
    private let sourceSetupModel: MacSourceSetupModel?
    private let bluetooth: MacBluetoothRadioState?

    public init(
        model: AnchorSessionModel,
        controller: (any LocalLinkControlling)? = nil,
        sourceSetupModel: MacSourceSetupModel? = nil,
        bluetooth: MacBluetoothRadioState? = nil
    ) {
        self.model = model
        self.controller = controller
        self.sourceSetupModel = sourceSetupModel
        self.bluetooth = bluetooth
    }

    public var body: some View {
        MacSettingsView(
            projection: model.projection,
            controller: controller,
            sourceSetupModel: sourceSetupModel,
            bluetooth: bluetooth
        )
        .frame(width: 480)
        .frame(minHeight: 420)
        .task { model.start() }
    }
}
#endif
