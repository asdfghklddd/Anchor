#if os(iOS)
import AnchorDesign
import SwiftUI

struct AnchorSetupVoiceButton: View {
    let recording: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: recording ? "stop.fill" : "mic")
                .font(.system(recording ? .body : .title3, weight: .regular))
                .foregroundStyle(recording ? AnchorSetupStyle.accent : .white)
                .frame(width: 48, height: 48)
                .background(recording ? AnchorSetupStyle.card : AnchorSetupStyle.accent, in: .circle)
                .overlay { if recording { Circle().stroke(AnchorSetupStyle.accent, lineWidth: 1.2) } }
                .shadow(color: recording ? AnchorSetupStyle.accent.opacity(0.12) : .clear, radius: 3, y: 2)
        }
        .accessibilityLabel(recording ? L10n.voiceInputStop : L10n.voiceInput)
        .accessibilityValue(recording ? L10n.voiceInputListening : L10n.voiceInputReady)
        .accessibilityIdentifier("setup.voice.input.button")
    }
}
#endif
