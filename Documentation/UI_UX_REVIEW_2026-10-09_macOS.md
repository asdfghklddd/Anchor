# Anchor macOS UI / UX / motion review — 2026-10-09

Third review round, macOS only (detail window, Settings, edge boat/anchor panels).
It complements [the 2026-10-02 review](UI_UX_REVIEW_2026-10-02.md) and
[the 2026-10-08 review](UI_UX_REVIEW_2026-10-08.md) and does not repeat their open
candidates (listed at the end). Rules referenced as P1–P6 and D01–D13 come from
[DESIGN.md](https://github.com/asdfghklddd/Anchor/blob/backup/agent-design-docs/DESIGN.md). Nothing in the app was changed by this review.

## Status

| Item | Status |
| --- | --- |
| H1 Switching tasks retrieves or re-throws the edge anchor | **Fixed** 2026-10-09 after the owner chose "one anchor, quiet receipts" (see [VALIDATION.md](VALIDATION.md)) |
| Codex subagent sessions, injected context, per-turn rows; terminal noise and Ctrl-C as failure | **Fixed** 2026-10-09 (found during the follow-up source audit) |
| All other rows | Open; next steps proposed in [the design exploration](MAC_COMPANION_DESIGN_EXPLORATION_2026-10-09.md) |

## Evidence legend

| Mark | Meaning |
| --- | --- |
| 🧪 | Reproduced with a throwaway Swift test against the real models (run in a scratch copy of the package, not committed) |
| 📸 | Seen in a screenshot of the isolated UI-test instance |
| 📄 | Confirmed by reading source; not exercised live |
| ❓ | Hypothesis; needs live interaction or device testing |
| ⚠️ | Touches a layout or rule that `DESIGN.md` records as user-confirmed |

## Method

- Source at `1dcd33b` (HEAD, clean tree). `Anchor macOS` Debug build succeeds
  (`CODE_SIGNING_ALLOWED=NO`); the only warning is the deprecated
  `SecKeychainSetUserInteractionAllowed`.
- `swift test` in a scratch copy: **232 passed** (150 Core, 43 Transport, 21 MacFeatures,
  18 IOSFeatures), 1 optional live-Codex test skipped.
- The app was launched four times with `ANCHOR_UI_TESTING=1` (in-memory pairing, no
  Bonjour server, temporary storage and defaults suite), each tracked by PID and
  terminated; temp data was removed. The window was opened via a normal reopen event.
  Captures (cropped to Anchor only) are in
  `../../Build/Previews/MacReview-20261009/`.
- Not covered: VoiceOver, keyboard-only passes, real iPhone pairing, multi-display,
  full-screen Spaces, frame rate.

## Top findings

### H1 · Switching tasks retrieves or re-throws the edge anchor 🧪

The edge anchor follows the *foreground* task, not "an active phone-confirmed anchor exists".
[`AnchorPhoneAnchorState.activeSessionID(in:)`](../Packages/AnchorKit/Sources/AnchorMacFeatures/AnchorPhoneAnchorState.swift)
returns `nil` whenever the foreground session differs from the last phone-confirmed ID, and
[`AnchorEdgePresentationModel.synchronize`](../Packages/AnchorKit/Sources/AnchorMacFeatures/AnchorEdgePresentationModel.swift)
turns every change into a full retrieval or deployment. Probe results:

| Action | Edge result |
| --- | --- |
| Click task B in the Mac's own task library (local `selectSession`) | Anchor pulled up, **Tink** plays |
| Click task A again | Full 2.1 s drop, splash, **Bottle** plays |
| Switch to task B on the iPhone while the anchor is down | `phase = .deploying`, `anchorTravel = 0` — the sunk anchor snaps back to the boat and is thrown again |

This breaks D09 ("落锚／收锚由真实锚点阶段变化触发 … 不随 … 模型刷新重播") and D10
("可反向过渡并保留连续性，不跳回起点"); with several hosted tasks it adds a sound and a
screen-height animation to every task switch (P2).

**After:** drive the edge from "at least one active hosted task has been confirmed by the
phone" (keep a set of confirmed IDs). Switching focus between confirmed tasks changes
nothing at the edge (or at most a small rope tug); retrieve only when the last confirmed
task ends. `beginDeployment` should not reset `anchorTravel` to 0 when already deployed or
retrieving. Add a regression test next to `AnchorPhoneAnchorStateTests`.

### H2 · No visible way to quit, and no menu-bar entry 📄

`LSUIElement` is `true`, so Anchor has no Dock icon and no visible menu bar, and does not
appear in the Force Quit window. Commit `8bdadf5` removed the `MenuBarExtra` that held the
only Quit action; `L10n.quit` is now unused. The remaining paths are an invisible ⌘Q while
the Anchor window is key (which your launch script relies on) or Activity Monitor.
`DESIGN.md` §2.4 and D09 still describe "菜单栏入口与原生详情窗口并存". Restoring a menu-bar
item therefore matches the confirmed design rather than changing it.

**After:** a minimal `MenuBarExtra` (Open Anchor · Settings… · Quit Anchor). If the edge
boat stays the only entry, also add a context menu with the same three items and a Quit
button at the bottom of Settings.

### H3 · The edge boat sits on other apps' toolbar buttons 📸 📄 ❓

[`AnchorEdgePanelController`](../Apps/AnchorMac/AnchorEdgePanelController.swift) places an
88 × 88 pt `.floating` panel 4 pt below the menu bar at the right edge, on every Space
including full-screen apps (`.canJoinAllSpaces`, `.fullScreenAuxiliary`). That corner is
where maximized and full-screen windows put toolbar controls (Safari tab overview, Xcode
inspectors, Finder search, the ⋮ menu in the capture). The boat's visible pixels (fully
visible when idle, half-visible when tucked; see `edge-boat-idle.png` and `edge-boat-tucked.png`)
take the click and open Anchor instead. D09: edge effects "不能影响其他应用的点击". Whether the
transparent rest of the 88 × 88 area also captures clicks still needs a live test.

**After:** move the resting berth off the toolbar band, for example to the vertical middle of
the right edge (the rope already runs there) or just above the Dock. Alternatively, hide the
boat while a full-screen app is frontmost. Keep the hover reveal and keyboard focus.

### H4 · Mac and iPhone show different progress for the same task 📄

The Mac goal card uses `SessionProjection.overallProgress`, the **mean** of every process
that reports progress (`MacWorkOverviewView.swift:49`, `SessionProjection.swift:111`). The
iPhone pill uses the **earliest-joined** conversation (`HostedTaskCard.swift:51`). If the main
conversation is at 20 % and a second one at 100 %, the phone shows 20 % and the Mac 60 %.
The Mac label is accurate ("已上报进程的平均进度"), but at a glance the user sees two numbers for one
task (P3, D02: "主会话胶囊不暗中平均不同会话").

**After:** show the main conversation's progress on the Mac card with the same unknown/"?"
semantics. The per-process numbers stay in the list below.

### H5 · The retired "decision" concept is still on screen, always 0 📄

The Mac model runs `TaskDashboardPolicy`, which sets `decisions = []`. The UI still renders it:

- Return impact card, third metric **"判断 0"** (`MacReturnMemoryView.swift:245`).
- Away summary **"N 个 · 0 待判断"** (`MacReturnMemoryView.swift:100`).
- History snapshot cards count legacy `openDecisionIDs` as "待判断" (`MacHistoryTrackView.swift:186`).

The away summary says "0 waiting" even when processes have failed, are blocked, or need
input, which reads as a false all-clear (P3, D07 "不出现待决策处理"). The sidebar badge, the
`openDecision` branches of `MacPriorityCard` and `MacSourceDetailView.openDecisions` are dead code.

**After:** count `process.requiresAttention` and reuse the iPhone return vocabulary
(运行中 / 已完成 / 失败 / 需留意). Remove the decision plumbing from Mac views.

## Data, state and copy

| Before | After | Why |
| --- | --- | --- |
| Return impact card always has a green ✓ next to "离开期间总影响", and every change row has a coral dot, even for completions (`MacReturnMemoryView.swift:220, 318`) | Per-kind symbol and tint for each row; header icon reflects the worst change | Completion drawn in failure color; green ✓ over failures misleads (D02) |
| Event-kind symbol/tint `switch` copied into 5 files and already drifting (`.completed` is `seafoam` in `MacEventStrip`, `mintInk` in `MacProcessEventTimeline`/`MacSourceDetailView`) | One `ProcessEventKind` presentation extension | Same event, same color everywhere |
| Connection label/symbol/tint copied into 3 views; for `.disconnected` the header says "设备未连接" while the empty state and Settings say **"Mac 已断开"** inside the Mac app; `.failed` tint differs | One `ConnectionState` presentation that names the iPhone | Consistent status language; the Mac can't be disconnected from itself (D11) |
| `.pairing` shown as **"配对设备"**, an action verb, in the header, empty state and Settings | "正在配对…" | It's a status, not a button |
| "Mac 连接" label inside the Mac app (📸) | "iPhone 连接" | Name the peer the user cares about |
| Settings shows "Mac 连接 · 未知" right above "正在自动连接" (📸); `MacPairingControls` starts with `@State pairingStatus = .automatic` before the controller reports | Neutral "检查中…" until the first status arrives | Don't claim activity without evidence (D07, P4) |
| Settings ▸ 来源 exposes the internal state machine: 执行状态 / 需要关注 / 观测结果 / 任务生命周期 (📸, `MacSourceSetupView.swift:128`), refreshed by a 1 s poll | One plain sentence ("Codex 正在运行 · 1 项需留意"); keep the grid in a disclosure/diagnostics view | D07/D11: technical detail belongs in diagnostics |
| Process list empty state says **"暂无事件"** plus "从一个清晰结果和支持它的工作进程开始。" (📸) | "还没有关联的 Codex 或终端会话" + button to Settings ▸ 来源 | Wrong noun; the Mac can't create processes here (prior M8 still open) |
| Empty workspace always offers primary **"配对设备"**, even when already connected (`MacEmptyWorkView.swift:134`) | Not paired → 配对 iPhone; paired → "在 iPhone 上投锚" (no button) | Anchors are created on the phone (D04 empty-state rule) |
| Vocabulary drift: "当前工作" (goal), "当前任务" (process list), "任务进程库" (anchors) | Pick one word per object and match iOS (任务 = anchor, 会话 = conversation) | Glanceability across devices (P3) |
| Mac History reads only `projection.session?.snapshots`; nothing in `AnchorMacFeatures` reads `archivedSessions` | List completed anchors below the current one | After finishing a task the Mac History shows "当前没有锚点" (D06 history promise) |
| Away card marks the away duration with a green `circle.fill` (`:63`) | Neutral or moon symbol | Green means "running" (D02) |
| Returning header computes `awayDuration(from:)` with `Date.now` outside a timeline (`:177`) | Wrap in `TimelineView(.everyMinute)` | Frozen value on a long-open window |
| Notification-denied warning and "打开系统设置" in Settings, but the Mac never requests or posts notifications | Remove | Nags upgraded users about a retired feature |
| Accessibility section lists 旁白 / 动态字体 / 增强对比度 / 降低透明度 as static rows | One explanatory line plus a link to System Settings ▸ 辅助功能 | They look like settings but do nothing; "Dynamic Type" isn't a macOS term |
| Error banner rewrites one message by English substring match (`MacErrorBanner.swift:52`) | Map typed errors to copy | Breaks silently when the text changes |

## Visual and layout

| Before | After | Why |
| --- | --- | --- |
| Mixed languages (📸): strings are forced to zh-Hans (`AnchorStrings.swift:6`), but formatters and system views follow the system locale → "Oct 9, 2026 at 7:15 AM 开始", "最近更新 6 sec" | `.environment(\.locale, Locale(identifier: "zh-Hans"))` on every Mac hosting root (window, Settings scene, edge panels), or follow the system language (product decision) | One language per screen (D11) |
| The zh-Hans value of `focus.session` is still English; the empty state shows "FOCUS SESSION" (📸) | Translate or drop the kicker | Untranslated string |
| Window chrome moves between sections (📸): History's `.searchable` brings back a toolbar, so traffic lights drop ~10 pt and the sidebar anchor button ~20 pt; the title shows on Empty/History/Settings but not on the overview (`navigationTitle("")`) | Keep geometry constant: either always keep a transparent unified toolbar, or put the History search field in the page; one title policy | The navigation trigger should never move (P6, D09) |
| "最近活动" disclosure contains a second "ACTIVITY LOG / 最近活动" title2 header and another "时间线" button, duplicating the goal card's "查看完整时间线" (`MacEventStrip.swift:17`) | Drop the inner header; keep one timeline entry | Repeated headings and actions |
| Horizontal event strip with hidden scroll indicators: 5 × 250 pt cards ≈ 1,314 pt > the 1,120 pt content max | 2–3 column grid or vertical list | Last card is clipped with no affordance for mouse users |
| History connector draws a dashed line center-to-center beneath an adaptive grid ❓ | Vertical rail in a single column, or drop the line | With ≥ 3 cards it zig-zags diagonally between rows |
| `DESIGN.md` says the process list shows the first 3; code uses `collapsedProcessLimit = 6` | Align doc or code | Doc/implementation drift |

## Motion

| Before | After | Why |
| --- | --- | --- |
| Reduce Motion still animates `anchorTravel` 0↔1 with `easeOut(0.2)` (`AnchorEdgePresentationModel.swift:157, 216`); the anchor glyph slides about the screen height in 200 ms while the non-animatable rope jumps | Set travel without animation; crossfade the anchor layer | Fast large displacement is the worst case for Reduce Motion (D10/D12) |
| Edge Reduce Motion is sampled only when the session model changes (`AnchorEdgePanelController.swift:153`) | Also observe `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` and the app default | Toggling mid-drop doesn't stop the 2.1 s drop |
| `Text(date, style: .relative)` ticks every second in 5 Mac views (Settings, event strip, source card/summary/detail) (📸 "6 sec") | `TimelineView(.everyMinute)` + `.formatted(.relative(presentation: .named))` | Constant motion in a dashboard's periphery (P2/D01) |
| Ad-hoc `.spring(duration: 0.36)` for the changes disclosure (`MacReturnMemoryView.swift:280`) | `AnchorMotion.panel` or `continuity` | D10: reuse shared tokens |
| "已复制" confirmations never clear (pairing code, shell setup) | Fade after ~2 s | Stale feedback reads as current |

## Platform and code hygiene

| Before | After | Why |
| --- | --- | --- |
| `NSApp.activate(ignoringOtherApps: true)` (`AnchorMacDetailWindowController.swift:59`) | `NSApp.activate()` | Deprecated since macOS 14 |
| `isMovableByWindowBackground = true` over SwiftUI content ❓ | Limit dragging to the header area | Drags on cards or selectable text (pairing code) may move the window |
| Dead code: `MacMenuPresenceCard.swift` (175 lines), `HarborCompanion.swift`, `MacCompletionBanner` and `MacWorkPresenceBanner` away/returning branches (unreachable in production), decision plumbing | Delete, or reuse `MacMenuPresenceCard` when restoring the menu bar (H2) | Less to maintain |
| Both the window's Settings section and the `Settings` scene mount `MacSourceSetupView`, each with its own 1 s poll | Share one model refresh loop | Duplicate polling |

## Suggested order

1. H1 edge task-switch bug (small, isolated, testable).
2. H2 menu-bar/Quit entry (restores confirmed design).
3. H5 + the return-card semantics rows (false all-clear).
4. H4 progress parity, mixed-language locale, ticking timestamps.
5. H3 berth position (needs a live click test on maximized and full-screen windows first).
6. Empty-state routing, Settings diagnostics, layout-shift and polish rows.

## Still open from earlier reviews (not repeated)

2026-10-02: M3 connection pill not actionable, M4 fixed four columns, M5 no section
shortcuts, M6 hover tolerance, M8 no-process empty state. 2026-10-08: T5 task tiles
(no color/lights/hover, reversed order) ⚠️, `StatusBadge` loudness, sidebar collapse
stealing focus, rail button not a toggle, `Task.sleep(16 ms)` animation loops, static greeting.

## What works well

- Status banners take real layout space, so they never cover content (D09).
- Process rows keep stable trailing status/progress columns, combine into one VoiceOver
  element, and read the visible metric.
- Unknown progress is never drawn as 0 %.
- The decorative panel ignores mouse and accessibility; sounds never overlap and are
  toggleable.
- The boat's tuck uses a single `AnimatableModifier`, so it reverses mid-flight.
- Liquid Glass surfaces fall back to solid fills with Reduce Transparency and use thicker
  borders with Increase Contrast.
