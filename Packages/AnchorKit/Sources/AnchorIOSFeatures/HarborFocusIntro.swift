#if os(iOS)
import AnchorCore
import AnchorDesign
import Foundation
import SwiftUI

struct HarborFocusIntro: View {
    let session: AnchorSession?
    let availability: ProjectionAvailability
    let now: Date

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
                .font(.caption.bold())
                .foregroundStyle(AnchorPalette.interaction)
                .accessibilityIdentifier("workspace.focus.kicker")
            Text(L10n.focusHeadline)
                .font(.title.scaled(by: 0.9).bold())
                .foregroundStyle(AnchorPalette.brandDeep)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(0.84)
                .accessibilityIdentifier("workspace.screen")
            Text(focusSummary)
                .font(.caption)
                .foregroundStyle(AnchorPalette.secondaryText)
                .accessibilityIdentifier("workspace.focus.summary")
        }
    }

    private var durationPill: some View {
        Label(durationText, systemImage: durationSymbol)
            .font(.caption.bold().monospacedDigit())
            .foregroundStyle(AnchorPalette.interaction)
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(AnchorPalette.softBlue.opacity(0.52), in: .capsule)
            .accessibilityIdentifier("workspace.focus.duration")
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: now)
        if hour < 11 { return L10n.greetingMorning }
        if hour < 18 { return L10n.greetingAfternoon }
        return L10n.greetingEvening
    }

    private var runningCount: Int {
        session?.processes.lazy.filter { $0.status == .running }.count ?? 0
    }

    private var attentionCount: Int {
        session?.processes.lazy.filter { $0.status == .needsDecision }.count ?? 0
    }

    private var focusMinutes: Int {
        guard let session else { return 0 }
        return max(1, Int(now.timeIntervalSince(session.startedAt) / 60))
    }

    private var focusSummary: String {
        switch availability {
        case .syncing:
            L10n.remoteSyncing
        case .lastKnown:
            L10n.stale
        case .empty, .live:
            L10n.focusSummary(running: runningCount, attention: attentionCount)
        }
    }

    private var durationText: String {
        guard !availability.isLive, let lastObservedAt = availability.lastObservedAt else {
            return L10n.focusDuration(focusMinutes)
        }
        return "\(L10n.lastUpdated): \(lastObservedAt.formatted(date: .abbreviated, time: .shortened))"
    }

    private var durationSymbol: String {
        availability.isLive ? "circle.fill" : "clock.badge.exclamationmark"
    }
}
#endif
