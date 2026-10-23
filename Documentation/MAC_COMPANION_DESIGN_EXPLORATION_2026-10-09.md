# Anchor Mac companion — design exploration (2026-10-09)

A proposal, not an implementation. It reads the intent behind Anchor's existing design,
checks whether the Mac side completes the product loop, and suggests what to add,
streamline or leave out. Principles P1–P6 and rules D01–D13 refer to
[DESIGN.md](https://github.com/asdfghklddd/Anchor/blob/backup/agent-design-docs/DESIGN.md); findings H1–H5 refer to
[the 2026-10-09 macOS review](UI_UX_REVIEW_2026-10-09_macOS.md). ⚠️ marks proposals that touch
a user-confirmed layout or rule.

## 1. What I believe Anchor is (including the unspoken parts)

- **An attention tool for the agent era.** You hand work to AI conversations and long
  commands, and your attention splits across them. Anchor holds the thread so you can let go
  of it and come back without reconstructing it: "让思路靠岸".
- **Two devices, two roles.** The iPhone is the logbook and the ritual: commit (投锚), glance,
  leave, return, finish. The Mac is the lighthouse keeper: it watches the work, never asks
  for anything, and has one always-present surface, a boat at the screen edge.
- **Calm technology.** Information lives at the periphery and moves to the centre only when
  it matters, and only by your choice. That is why there are no notifications (D11) and why
  the Mac's main surface is a boat, not a window.
- **A physical metaphor that carries meaning.** Anchor = commitment. Rope = tether.
  Water = the work happening below the surface. An anchor that sinks out of sight =
  "settled, you don't need to watch". Boat sailing aside = "out of your way".
- **Honesty over reassurance.** Unknown is not 0 %. An open app is not a running task. An
  interruption is not a failure. Nothing is animated that didn't happen.
- **Ceremonies happen once, then stillness.** The launch, the throw and the return each say
  one thing, once.
- **A companion, not a widget.** The unused `HarborCompanion` (a calm/happy anchor face)
  suggests the harbor was always meant to feel like company.

**The test I'd apply to every feature:** does it let the person look away with confidence,
and come back without having to reconstruct where they were? (P1, P3)

## 2. Is the loop complete?

| Stage | iPhone | Mac today | Gap |
| --- | --- | --- | --- |
| Commit | Cast an anchor | Edge throw; now multi-task aware (fixed today) | — |
| Watch | — | Reads ChatGPT/Codex and terminal; subagents and short commands filtered (fixed today) | Terminal commands go to whichever task is in front, not the one they belong to |
| Glance | Chart, cards, lights | Window in a different visual language; the edge only says "anchored or not" | Mac doesn't speak the phone's language (H4, T5) |
| **Something needs you** | Lights, if you look | **Nothing at the edge** | **Biggest gap**: the moment an agent finishes or waits is exactly what an attention tool should surface |
| Leave | Away state | Nothing | Minor |
| Return | Four-card summary | Only inside the window, if opened | You resume work at the desk, not on the phone |
| Finish | Confirm and archive | Edge lift | — |
| Look back | History | Current task only (no archived tasks) | Mac history is incomplete |
| Step out of Anchor | — | No visible Quit, no menu bar (H2) | Missing |

## 3. Proposals

### A · Buoys: let the edge say "something needs you" ⚠️ (P3, P2, D01, D02)

When a conversation or command under an anchor reaches a state worth knowing, a small buoy
floats on the water where the rope meets it:

- **Kinds:** finished (green), waiting for input or interrupted (yellow), failed (red).
- **Motion:** static, no blinking. One small bob when it arrives (finite, like the rope tug).
  Under Reduce Motion it simply appears.
- **Clearing:** the buoy stays until you look at that conversation on either device, or its
  state changes. Seen results don't keep shouting (D01: "重要结果持续可查", "不反复强调").
- **Hover:** hovering the boat shows a compact list ("ChatGPT · Anchor — 2 分钟前完成").
  Clicking an entry opens that conversation.

**Why:** Anchor already knows when an agent turn completes or aborts, but today only the
phone shows it, and only if you look. A buoy is peripheral, persistent until seen, honest,
and needs no notification permission.

**Mock first:** buoy size and colour on light and dark wallpapers, and how it reads in a
screen share.

### B · Return at the desk (P1, D08)

When the phone reports you're back, the boat returns from its tucked berth with a small
pennant. The first click opens a Mac "while you were away" view: the existing
`MacReturnMemoryView`, after the H5 fixes. Nothing opens by itself and nothing steals focus
(D09). The phone's four cards stay the canonical return; the Mac offers the same facts where
you actually resume.

### C · One language across devices (P3, P6)

- **Done today:**
  - ChatGPT/Codex conversations are one row, labelled "ChatGPT · <workspace>".
  - Ctrl-C is interrupted, not failed.
- **Next:**
  - Show the main conversation's progress on the Mac goal card (H4).
  - Give Mac task tiles their task colour and three lights (T5 ⚠️).
  - Use one set of nouns: 任务 = anchor, 对话 = AI conversation, 命令 = terminal command.
  - Show human copy instead of internal event names: "回复完成" / "已中断" rather than
    "Codex task_complete" / "Codex turn_aborted" (D11).

### D · Onboarding as a harbor checklist (P4, D07)

Replace the empty state's "配对设备 / 时间线" buttons with three steps, each showing live state:

1. **Pair your iPhone.**
2. **Allow the ChatGPT / Codex sessions folder.** The picker already opens `~/.codex/sessions`.
3. **Optional: terminal commands.** Explain that only commands running 10 s or more appear.

Each step turns ✓ when done, and the checklist disappears once the first anchor is observed.
Move the internal task-state grid into a "诊断" disclosure.

### E · Let each anchor own its workspace (D02, D07)

Today a terminal command belongs to whichever task is in front when it crosses 10 s. A bound
conversation already tells us its workspace folder, so:

- **Route by folder:** commands run in that folder go to that anchor, with the foreground
  task as the fallback only.
- **Surface ambiguous matches:** when an auto-match is ambiguous (left unassigned on purpose),
  show a quiet "1 段对话未归属" chip in the window with one-click assignment. D07 already
  allows manual association; today the user never learns there is something to assign.

### F · Streamline (remove or fold away)

- **Retired decision plumbing** that still renders (判断 0, 待判断, sidebar badge), and the
  notification-permission warning for a feature that no longer posts notifications.
- **Static accessibility rows** that look like settings; replace with one sentence and a link
  to System Settings ▸ 辅助功能.
- **Duplicates:** the timeline button and the "最近活动" heading appear twice; the
  `Settings` scene duplicates the window's Settings section.
- **Dead code:** `MacMenuPresenceCard`, unless reused in G.
- **Copy:** the untranslated "FOCUS SESSION" kicker.

### G · A minimal menu-bar presence (restores D09)

A template-image anchor in the menu bar with Open Anchor · Settings… · Mute edge sounds ·
Quit Anchor. If you want status there too, reuse `MacMenuPresenceCard` for "2 个任务已投锚 ·
1 个浮标". This also gives keyboard and VoiceOver users a reliable entry point that doesn't
depend on finding the boat.

### H · A berth that respects other apps ⚠️ (H3, D09)

The top-right corner is the busiest real estate on macOS: toolbar buttons, notification
banners, Control Center. Two options to try:

- **Mid-right berth:** the boat docks halfway down the right edge; the rope already runs there.
- **Hide in full-screen:** keep the current berth but hide the boat while a full-screen app
  is frontmost.

Verify with a click test on maximized Safari, Xcode and Finder windows. If the rope appears in
screen shares, decide whether that is desirable.

### I · Smaller items

- **Language:** pick one policy. Today Mac UI strings are forced to Chinese while dates and
  AnchorCore strings follow the system language.
- **History:** Mac History should list completed anchors (D06).
- **Turn counts:** history snapshot cards still count turns, not conversations; fold them the
  same way when snapshots are next touched.
- **Earlier mis-bindings:** guardian processes bound by earlier builds stay in existing task
  history. Automatic bindings are pruned from now on; old rows can't be identified afterwards.

## 4. What I would not add

- **No attention-grabbing channels:** no notifications, badges, Dock bouncing or
  auto-opening windows (P2, D09, D11).
- **No guessing:** don't infer "the AI is idle/stuck", don't estimate progress from tokens or
  time, don't treat app activity as work (D02, D07).
- **No acting for the user:** no answer, approve or resume buttons (README, D07).
- **No gamification:** no streaks or scores. Focus time stays elapsed time, not
  "net focus" (D05).

## 5. Decisions for you, in suggested order

1. **A · Buoys:** worth a mock? This is the largest step toward "glance and know".
2. **G + H · Menu bar and berth:** quick wins that restore confirmed intent and stop the edge
   from covering other apps.
3. **F · Streamline:** low risk, removes misleading zeros.
4. **D · Onboarding checklist:** makes the first five minutes self-explanatory.
5. **E · Workspace routing:** matters once you run several anchors at once.
6. **B · Desk return:** builds on A and the H5 fixes.
