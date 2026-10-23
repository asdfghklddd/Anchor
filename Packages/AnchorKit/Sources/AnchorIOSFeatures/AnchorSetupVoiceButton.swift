#if os(iOS)
import AnchorDesign
import SwiftUI

/// Hold to talk, or tap to start and tap again to stop. A press that lasts past
/// a short beat is a hold, and letting go ends it; a quick tap keeps listening.
struct AnchorSetupVoiceButton: View {
    let recording: Bool
    let requesting: Bool
    let level: Double
    /// True while a hold is recording; the caption then says "release to finish".
    @Binding var holding: Bool
    let begin: () -> Void
    let end: () -> Void

    @GestureState private var pressed = false
    @State private var press: Press?
    @AnchorReducedMotion private var reduceMotion

    private enum Press: Equatable {
        /// This press started the listening: a tap keeps it, a hold ends it on release.
        case starting(Date)
        /// Listening was already on: this press is the tap that stops it.
        case stopping
        /// Permission is still being asked: the press does nothing.
        case ignored
    }

    private var active: Bool { recording || requesting }

    var body: some View {
        Image(systemName: holding ? "mic.fill" : (active ? "stop.fill" : "mic"))
            .font(.system(active ? .body : .title3, weight: .regular))
            .foregroundStyle(active ? AnchorSetupStyle.accent : .white)
            .frame(width: 48, height: 48)
            .background(active ? AnchorSetupStyle.card : AnchorSetupStyle.accent, in: .circle)
            .overlay { if active { Circle().stroke(AnchorSetupStyle.accent, lineWidth: 1.2) } }
            // A ring that breathes with the voice while it is heard.
            .background {
                if recording {
                    Circle()
                        .fill(AnchorSetupStyle.accent.opacity(0.18))
                        .scaleEffect(1 + (reduceMotion ? 0.12 : 0.15 + 0.35 * min(1, level)))
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.08), value: level)
                }
            }
            .shadow(color: active ? AnchorSetupStyle.accent.opacity(0.12) : .clear, radius: 3, y: 2)
            .scaleEffect(holding ? 1.12 : (pressed ? 0.94 : 1))
            .animation(AnchorMotion.micro, value: holding)
            .animation(AnchorMotion.micro, value: pressed)
            .contentShape(.circle)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($pressed) { _, state, _ in state = true }
                    .onChanged { _ in if press == nil { pressBegan() } }
            )
            // Ended and cancelled presses both come back through here.
            .onChange(of: pressed) { _, now in if !now { pressEnded() } }
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(active ? L10n.voiceInputStop : L10n.voiceInput)
            .accessibilityValue(recording ? L10n.voiceInputListening : L10n.voiceInputReady)
            .accessibilityHint(SetupCopy.voiceHoldHint)
            .accessibilityAction { active ? end() : begin() }
            .accessibilityIdentifier("setup.voice.input.button")
    }

    private func pressBegan() {
        if requesting {
            press = .ignored
        } else if recording {
            press = .stopping
        } else {
            let started = Date.now
            press = .starting(started)
            begin()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.35))
                if press == .starting(started) { holding = true }
            }
        }
    }

    private func pressEnded() {
        switch press {
        case .stopping:
            end()
        // A hold ends on release, unless permission is still being asked:
        // then the listening that follows behaves as a tap.
        case .starting where holding && recording:
            end()
        default:
            break
        }
        holding = false
        press = nil
    }
}
#endif
