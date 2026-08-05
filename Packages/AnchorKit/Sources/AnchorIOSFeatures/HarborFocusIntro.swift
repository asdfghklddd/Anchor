#if os(iOS)
import AnchorCore
import AnchorDesign
import Foundation
import SwiftUI

struct HarborFocusIntro: View {
    let session: AnchorSession

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AnchorSpacing.small) {
                    focusCopy
                    durationPill
                }
            } else {
                HStack(alignment: .bottom, spacing: AnchorSpacing.small) {
                    focusCopy
                    Spacer(minLength: AnchorSpacing.small)
                    durationPill
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var focusCopy: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(greeting) · \(L10n.focusSession)")
                .font(.caption2.bold())
                .foregroundStyle(AnchorPalette.link)
                .accessibilityIdentifier("workspace.focus.kicker")
            Text(L10n.focusHeadline)
                .font(.title.scaled(by: 0.9).bold())
                .foregroundStyle(AnchorPalette.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(0.84)
                .accessibilityIdentifier("workspace.screen")
            Text(L10n.focusSummary(running: runningCount, attention: attentionCount))
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryInk)
                .accessibilityIdentifier("workspace.focus.summary")
        }
    }

    private var durationPill: some View {
        Label(L10n.focusDuration(focusMinutes), systemImage: "circle.fill")
            .font(.caption.bold().monospacedDigit())
            .foregroundStyle(AnchorPalette.mintInk)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(AnchorPalette.seafoam.opacity(0.24), in: .capsule)
            .accessibilityIdentifier("workspace.focus.duration")
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 11 { return L10n.greetingMorning }
        if hour < 18 { return L10n.greetingAfternoon }
        return L10n.greetingEvening
    }

    private var runningCount: Int {
        session.processes.lazy.filter { $0.status == .running }.count
    }

    private var attentionCount: Int {
        session.processes.lazy.filter { $0.status == .needsDecision }.count
    }

    private var focusMinutes: Int {
        max(1, Int(Date.now.timeIntervalSince(session.startedAt) / 60))
    }
}
#endif
