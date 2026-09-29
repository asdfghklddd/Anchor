#if os(macOS)
import AnchorCore
import SwiftUI

public struct AnchorMacSettingsScene: View {
    private let model: AnchorSessionModel
    private let controller: (any LocalLinkControlling)?
    private let sourceSetupModel: MacSourceSetupModel?

    public init(
        model: AnchorSessionModel,
        controller: (any LocalLinkControlling)? = nil,
        sourceSetupModel: MacSourceSetupModel? = nil
    ) {
        self.model = model
        self.controller = controller
        self.sourceSetupModel = sourceSetupModel
    }

    public var body: some View {
        MacSettingsView(
            projection: model.projection,
            controller: controller,
            sourceSetupModel: sourceSetupModel
        )
        .frame(minWidth: 560, minHeight: 520)
        .task { model.start() }
    }
}
#endif
