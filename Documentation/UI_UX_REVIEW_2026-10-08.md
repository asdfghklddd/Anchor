# Anchor UI / UX / motion review — 2026-10-08

Second-round review of the iOS and macOS apps, focused on visual design, interaction and
animation. It complements [the 2026-10-02 review](UI_UX_REVIEW_2026-10-02.md) and does not
repeat its open candidates (I4–I8, M3–M6). Design rules referenced as P1–P6 and D01–D13
come from [DESIGN.md](../DESIGN.md).

## Status

| Item | Status |
| --- | --- |
| T1 Dashboard has no data-change animation | **Implemented** 2026-10-08 (see Change log) |
| T2 Task colors 1 and 3 nearly identical | **Implemented** 2026-10-08 |
| T3 Top bar / create button float over scrolling content | Open |
| T4 Most views ignore system Reduce Motion | **Implemented** 2026-10-08 |
| T5 Mac task tiles lack task color, lights and phone order | Open (⚠️ touches the confirmed Mac tile layout) |
| A6 Landscape clock lags by up to 30 s | **Implemented** 2026-10-08 |
| All other rows below | Open candidates; not authorized for implementation |

⚠️ marks a proposal that touches a layout or rule `DESIGN.md` records as user-confirmed.

## Method and evidence boundary

- Source at commit `255224e` plus the changes in the Change log, `DESIGN.md`, the project
  `emil-design-eng` skill, and the 2026-10-02 simulator captures in
  `../../Build/Previews/Readability-20261002/` and `Return-20261002/`.
- The macOS app was built and launched in isolated UI-test mode, but this session had no
  screen-recording permission, so Mac findings come from source plus the older
  `../../Deliverables/VideoReview/live-mac-home.png`.
- The `Return-20261002` capture predates the decision cleanup; its "等待判断" copy is no
  longer rendered by current code and is not reported as a defect.
- No real-device, VoiceOver or frame-rate testing was done in this round.

## Top 5

| # | Finding | Evidence |
| --- | --- | --- |
| T1 | Home cards, chart, status lights and completion seal snap on every data change. P3/P5 and D01/D10 ask for continuous, noticeable change feedback. `ProcessCard` already does this; the home view did not. | `HostedTaskCard.swift`, `HomeAnchorChart.swift`, `PortraitDashboard.swift` |
| T2 | Task color 1 (`cyan #36D1ED`) and task color 3 (`rgb 0.30/0.81/0.94`) are nearly identical; colors ≥ 3 did not adapt to dark mode. Visible in `progress-portrait-light.png` ("任务刚刚开始" vs "验证已经完成"). | `HostedTaskAppearance.swift` |
| T3 | Top bar and create button sit in `.safeAreaInset` with no backing; scrolled content runs under the name/connection text, and the create button covers the last card's progress pill (`progress-accessibility-light.png`). | `PortraitDashboard.swift:55,61` |
| T4 | Only `ReturnView` and the full-screen host read the system Reduce Motion setting. Launch keyframes, press scaling, handoff, connection card and all Mac motion read only the app toggle. D12 requires either setting to reduce motion. | All `@AppStorage(reduceMotionDefaultsKey)` readers |
| T5 | Mac task tiles show title + "进行中" only — no task color, no status lights, no hover state — and list tasks in reverse of the phone's order. Cross-device recognition ("the yellow task") breaks. | `MacWorkOverviewView.swift:107-133` |

## iOS — visual

| Before | After | Why |
| --- | --- | --- |
| Task colors 1 and 3 near-identical; ≥ 3 not adaptive | Distinct tokens with light/dark values | D02 task identity — **done** (T2) |
| Create button: white anchor glyph on bright cyan (`PortraitDashboard.swift:63`) | `AnchorIOSStyle.onAccent` | D03 token table assigns `onAccent` to icons on cyan; white on `#36D1ED` ≈ 1.8:1 |
| Top bar / create button use `.safeAreaInset` with no backing | iOS 26 `.safeAreaBar(edge:)` for the system scroll-edge effect | T3 |
| Status dots (12 pt) and progress ring (13 pt) fixed size | `@ScaledMetric(relativeTo: .caption2)` | Large-text capture shows a tiny ring next to a huge "63%" — **done** with T1 |
| Chart: unknown draws a full-height dashed capsule, known draws only its fill with no track (`HomeAnchorChart.swift` main line) | Faint full-length track always; unknown stays dashed but not visually larger | "Unknown" currently outweighs "63%", and 63% has no visible whole |
| 100% bar extends past the bottom grid line | Position grid lines from the same `lineLength` (0 / 50 / 100%) | "Done" should land on a line |
| Task-count dot always green, even with 0 tasks (`PortraitDashboard.swift:28`) | Remove, or tie to "something is running" | Green means running elsewhere (D02) |
| Return screen forces light mode with page-local colors (`ReturnView.swift` `ink`, background, `.preferredColorScheme(.light)`) | `AnchorIOSStyle` tokens, follow system appearance | D03 single color source; avoids a bright flash at night (P2) |

## iOS — interaction

| Before | After | Why |
| --- | --- | --- |
| Return screen's only action is a grey caption "返回 ▶" | Primary button (`AnchorIOSPrimaryButtonStyle`) with a clear verb, e.g. "继续工作" | Weakest element is the main action; "back ▶" is ambiguous |
| ⚠️ Tall/short card height derived from list position (`index % 4`) | Derive from a stable per-task value (e.g. color index) | Removing task #2 currently re-heights and re-columns every later card |
| Setup Next button: 44 pt `.plain` | Reuse `AnchorIOSPrimaryButtonStyle`, ≥ 52 pt | D03 primary-action rule |
| Setup save error: grey text, no icon, inside scroll area | Red + `exclamationmark.triangle`, placed above the button | D11 — errors sit beside the failed action |
| Landscape clock: `TimelineView(.periodic(from: .now, by: 30))` | `TimelineView(.everyMinute)` | Clock could show the previous minute for up to 30 s — **done** (A6) |
| "Focus" / "min" hard-coded English in landscape | Keep the "Focus" name; localize the unit | Chinese UI shows "22 min" |

## iOS — motion

| Before | After | Why |
| --- | --- | --- |
| Home progress ring / % text snap | Ring `.animation(continuity, value:)`, text `.numericText(value:)` | Mirrors `ProcessCard` — **done** (T1) |
| Chart rope heights snap | Animate height with `continuity` | The rope metaphor reads best when it visibly lowers — **done** (T1) |
| Status light / completion seal change silently | One pulse when a light turns on; seal springs in | D10 one cue per change, then still — **done** (T1) |
| Task insert/remove pops | Membership-only animation, opacity + 0.95 scale | Avoids layout jump — **done** (T1) |
| Setup segments swap instantly; header glyph size jumps | Directional push between segments; animate header | Spatial consistency for forward/back |
| Launch ripple fades in before the landing (`HarborLaunchSplash.swift` ring opacity) | Ring visible only from the 280 ms impact | Ripple should be caused by the landing |
| Per-view `@AppStorage(reduceMotion)` | One shared "system ∨ app" value | **done** (T4) |
| Landscape clock digits swap | `.contentTransition(.numericText())` | Quiet ambient cue — **done** with A6 |

## macOS

| Before | After | Why |
| --- | --- | --- |
| ⚠️ Task tiles: no color, no lights, no hover, reversed order | Task-color stripe/dot, compact three-light row, hover highlight, phone order | T5 |
| `StatusBadge` is the same deep-sea filled pill for every status, differing only by a 2 pt stroke (`AnchorComponents.swift`) | Light tinted pill for running; strong fill only for failed / needs attention | Normal state is the loudest element and failed resembles running (P2) |
| Sidebar collapse always requests focus on the rail, including hover-out (`AnchorMacRootView.swift` `collapseSidebar`) | Return focus only when opened by click or keyboard | Brushing the sidebar steals focus from a text field |
| Rail button only expands (`onToggle: expandSidebar`) | Real toggle with matching accessibility label | Clicking while open does nothing |
| Edge drop and sway run on `Task.sleep(16 ms)` loops mutating `@Observable` state (`AnchorEdgePresentationModel.swift`) | `TimelineView(.animation)` or `keyframeAnimator` | Not display-synced: can judder on 120 Hz; two loops drive ~60 Hz re-renders |
| Greeting computed once (`MacWorkHeaderView.swift`) | `TimelineView(.everyMinute)` | Long-open window keeps "早上好" into the afternoon |

## What already works well

- `AnchorMotion` tokens use a strong ease-out curve; the 0.98 press scale is textbook.
- Launch is a finite keyframe sequence that gates hit testing and VoiceOver and restarts cleanly.
- Return entrance and haptic are claimed once per return; setup drafts survive rotation.
- The edge boat's `AnimatableModifier` reverses mid-flight without jumping; sway is a damped spring.
- Status lights add symbols under Differentiate Without Color.

## Change log — 2026-10-08

Implemented T1, T2, T4 and A6. No confirmed layout, motion parameter or flow was changed.

- **T4** `AnchorDesign/AnchorMotion.swift`: new `@AnchorReducedMotion` property wrapper
  (system Reduce Motion ∨ app toggle). Adopted by every view that only read the app toggle on
  iOS and macOS; the two Settings toggles still bind to the app preference. The Mac edge panel
  controller also reads `NSWorkspace.accessibilityDisplayShouldReduceMotion`.
- **T2** `AnchorIOSStyle.violet` (`#8B7CF6` / `#A197F2`) replaces the near-cyan task color 3;
  colors 4–6 use hand-picked hues clear of the named colors and status green/red; further
  colors keep the golden-ratio hue but adapt to dark mode. Existing tasks with color index ≥ 3
  change color once.
- **T1** `HostedTaskCard`: ring and % animate (`continuity`, `.numericText`); a status light
  pulses once when it turns on (not on first appearance or refresh); the seal springs in;
  dots and ring scale with Dynamic Type. `HomeAnchorChart`: rope heights animate, tasks fade
  in/out. Portrait and landscape grids animate membership changes only. Reduced motion uses
  a 160 ms ease-out with no scale or movement.
- **A6** Landscape clock ticks on minute boundaries with a numeric content transition.
  The Focus minute shares that tick, so it can trail its own minute boundary by under 60 s.

Verification on 2026-10-08: `Anchor iOS` (generic simulator) and `Anchor macOS` Debug builds
succeed; `swift test` passes 150 tests in 18 suites. UI tests were not re-run. Not yet
checked: simulator/on-device feel of the new animations, VoiceOver, and system Reduce Motion
on hardware.
