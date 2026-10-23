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
            .background { face }
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

    /// At rest it is a small dome, lit from above with a soft shadow under it;
    /// a press sinks it. While listening it stays pressed in, shaded inside.
    @ViewBuilder private var face: some View {
        if active {
            Circle().fill(AnchorSetupStyle.card
                .shadow(.inner(color: AnchorPalette.deepSea.opacity(0.18), radius: 2.5, y: 1.5)))
        } else {
            let sunk = pressed
            Circle()
                .fill(LinearGradient(
                    colors: [
                        AnchorSetupStyle.accent.mix(with: .white, by: 0.2),
                        AnchorSetupStyle.accent.mix(with: AnchorSetupStyle.heading, by: 0.22),
                    ],
                    startPoint: .top, endPoint: .bottom))
                .overlay {
                    Circle().strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0)], startPoint: .top, endPoint: .center),
                        lineWidth: 1)
                }
                .shadow(color: AnchorPalette.deepSea.opacity(0.22), radius: 1, y: 1)
                .shadow(color: AnchorSetupStyle.accent.opacity(sunk ? 0.18 : 0.38), radius: sunk ? 3 : 7, y: sunk ? 1.5 : 4)
        }
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
