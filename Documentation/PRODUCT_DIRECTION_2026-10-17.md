# Anchor product definition: the keeper of your next action

**Date:** 2026-10-17
**Status:** Proposal for the owner's approval. It redefines the target experience and the work needed to reach it. It does not change Part I of DESIGN.md; the Part II/III rules it touches are listed in section 7.
**Baseline:** branch `feat/auto-show` at `20d3683`, plus the uncommitted Phase 1 "live plan" work on the iPhone.

---

## 1. What you are trying to achieve

Reverse-extracted from your design, your feedback, and your Codex usage.

**In one sentence:** Anchor keeps your intentions and your agents' work tied together, so that at any moment (at the desk, after an interruption, or when switching projects) you know what you are trying to do, where each task stands, what your agents did, and **what to do next**, without holding it in your head.

It does six jobs:

| Job | In your words | What Anchor must do |
|---|---|---|
| **Plan** | "finish setting up the tasks on the phone in advance before starting work" | Capture each task's goal and steps quickly on the iPhone. Your plan sets the agenda. |
| **Focus** | "put the phone next to the computer as a display board to prevent getting distracted" | The phone on its stand shows the task you're on and its current step, calmly, all session long. |
| **Observe** | "take the recent hot processes and assign them to the corresponding tasks" | The Mac sees every agent conversation and command, attaches it to the right task (and step) by itself, and reports facts. |
| **Recover** | "when I'm interrupted… I lose why I started, what I need to do, what they are doing" | After a call or a break, the device you look at first tells you what changed and what to do first. |
| **Decide** | "first is deciding what is next" | Every task always shows your next action from your own plan, and the tasks that need you come first. |
| **Finish** | (the original design) | Only you mark steps and tasks done, and you can see what got finished. |

**Evidence from your last 30 days of Codex logs** (aggregate numbers only):
- Agents worked about 25 h; their finished results then waited about 36 h for your next message. The bottleneck is the gap between "agent finished" and "your next good instruction", not the agent.
- On a typical active day you work on 2 projects (up to 5). When you return to a project after a break, you were away for a median of about 9 h.
- 1 in 4 of your messages is typed while a *different* project's agent is running.
- Only 30 of 88 long runs built the app or ran tests.

**Constraints:** no paid Apple Developer account, so no CloudKit and no push. Phone and Mac talk only over Bluetooth or the local network, so the Mac stores updates and sends them when the phone reconnects. Goals are set on the iPhone.

---

## 2. The product, defined

### Roles

| | Role | Owns |
|---|---|---|
| **iPhone** | Where your intentions live | Creating tasks, editing plans, the desk board, the return page, finishing |
| **Mac** | Where the work happens | Watching sources, attaching work to tasks, showing results, acting on them at the desk |
| **Local link** | Store and forward | The Mac keeps every update; the phone gets them on the next connection; nothing goes to a cloud |

### Building blocks

- **Task** (the anchor): goal, optional completion criteria, steps. Created on the iPhone; appears on the Mac.
- **Step**: a line of your plan, with its own identity and a done state. Only you check it.
- **Work**: an agent conversation (Codex, Claude Code) or a long terminal command, attached to one task and, when clear, to one step.
- **Result**: facts a source reported: running for 6 min, finished, failed with an error, stopped by you, waiting for your reply, tests passed / failed / not run, the start of the reply.
- **Next action** (derived, never stored): fix, check, wait, start step N, or finish. It is the same on every screen.

### A day with Anchor

1. **Before work (iPhone, 1 minute).** Tap the anchor and say: "数据结构作业，周五前交；先实现插入，再实现删除，补边界测试，写报告". The goal and four steps appear. Save. The task shows up on the Mac.
2. **Start (phone on its stand).** The desk board shows, large: **数据结构作业 · 第 1 步：实现插入**. It stays on while charging.
3. **Delegate.** In Codex you ask "帮我实现红黑树插入". The Mac matches it to step 1 of 数据结构作业 and attaches it with no pop-up. The board says **Codex 正在做第 1 步 · 3 分钟** ("Codex is on step 1, 3 min").
4. **Switch.** You tap 个人网站 on the phone (or simply start working in its folder). New work goes there. The homework task shrinks to a small "running" chip on the board.
5. **A result arrives.** The Mac pings you unless you're already looking at Codex. The homework chip turns to **需要你** ("needs you"): "完成第 1 步：已实现插入，测试通过 ✓" ("step 1 finished: insertion implemented, tests pass").
6. **A phone call (25 min).** Back at the Mac, a small card next to the boat: "离开 25 分钟 · 你在做：个人网站 第 2 步 · 期间：数据结构作业 第 1 步完成（测试通过）· 先做：查看数据结构作业" (away 25 min, what you were on, what changed, what to do first). If you took the phone with you, its return page says the same for every task that changed when it reconnects.
7. **Decide.** Tap **这一步完成了** ("this step is done"). Step 2 becomes current. Tap **复制为提示词** ("copy as prompt") and paste it into Codex.
8. **End of day.** "今天" ("today"): steps checked, tasks touched, what is waiting for tomorrow. You finish the homework task yourself when it really is done.
9. **Out on campus.** The phone shows the last synced state and says how old it is ("上次同步 2 小时前", last synced 2 h ago). At home everything syncs.

### Rules

These are derived from P1–P6 and don't change them.

1. **Your plan sets the agenda.** An agent's suggested next step becomes a step only when you accept it.
2. **Only you mark steps and tasks done.** A finished run never makes a task look complete.
3. **Facts, not guesses.** Say "not tested", "no activity for 12 min", "waiting for your reply". Never invent progress or call silence a failure.
4. **Attach when it's clear; otherwise ask quietly.** Unclear work waits in 未归类 ("unsorted"). Nothing steals focus.
5. **One "needs you" signal everywhere.** The desk board, the Mac buoy, pings, and the return pages follow the same rules, and the same event never pings twice.
6. **Always show how fresh the data is.**
7. **Local only.** Conversation text stays on your two devices.

---

## 3. iPhone changes

**Today:** create an anchor (goal, criteria, and steps, all required), home cards, task details, landscape desk board with status rows, a single-task return page, notes, finish, and history. Phase 1 added checkable steps, next actions, and the step question on return.

| # | Change | Job | Now | Size |
|---|---|---|---|---|
| I1 | **Live plan.** Check steps, see the next action per task, answer "is this step done?" on return, copy the step as a prompt | Decide | Built (Phase 1, uncommitted) | — |
| I2 | **Edit the plan anytime.** Add, rename, delete, and reorder steps in task details; a quick "add step" field | Plan | Steps are fixed after creation | M |
| I3 | **Lighter setup.** One screen: goal and at least one step required, criteria optional. Dictation splits into steps at line breaks or words like "然后" | Plan | Three required screens plus a review | M |
| I4 | **"The task I'm on."** Tapping a task makes it current, with a clear 当前 ("current") marker on its card and the board. The Mac uses this to place new work | Observe | Selection exists, but isn't shown as "current" | S |
| I5 | **Desk board for focus** (landscape). Large: the current task, its current step, and the agent's state on it. Small: the other tasks as chips with needs-you badges, and data freshness. The screen stays awake while landscape and charging | Focus | Rows of task status; the screen can sleep (audit F10) | M–L |
| I6 | **Results on the phone.** Each piece of work shows its state, duration, tests passed / failed / not run, and the start of the reply | Observe | Lifecycle words only | M |
| I7 | **Return page for every changed task.** Header: time away and what to do first across tasks. One card per task: goal, current step, what agents did, done / not yet, next step, copy prompt. Tasks needing you come first | Recover | Covers the selected task only | M |
| I8 | **Accept agent suggestions as steps.** When a reply ends with suggested next steps, "加为步骤" ("add as step") | Plan | — | M |
| I9 | **Sync freshness everywhere.** "已同步 · 刚刚" (synced just now) or "上次同步 2 小时前 · 3 条变更待发送" (last synced 2 h ago, 3 changes waiting to send) | Trust | Partial ("Mac 已断开", "已保存的记录") | S |
| I10 | **Today recap.** Steps done today, tasks touched, what's waiting | Finish | — | S–M |
| I11 | **Glance wording.** "此刻" ("now") counts tasks by your plan ("2 个需要你 · 1 个在运行", 2 need you, 1 running), not finished runs ("N 项已完成") | Decide | Counts finished runs | S |

---

## 4. Mac changes

**Today:** the edge boat and buoy with sounds; a main window with header, glance, a "Codex 对话" (Codex conversations) card, one task's overview, history snapshots, and settings; Codex folder access with keyword suggestions and confirmation pop-ups; terminal commands; finish pings. The Mac never shows your plan.

| # | Change | Job | Now | Size |
|---|---|---|---|---|
| M1 | **Task-centric main page "任务"** ("tasks"). Every phone task with its goal, step progress, current step, and next action. Beneath each task, its attached work: state, time, start of the reply, tested. Tasks needing you come first. This replaces today's separate glance, conversation card, and single-task overview | Observe, Decide | No plan on the Mac; conversations and tasks shown apart | L |
| M2 | **未归类 ("unsorted") list.** Work Anchor couldn't place: "归到…" ("file under…") with one click; "移到…" ("move to…") for attached work; "不属于任务" ("not part of a task") to ignore it. The suggestion pop-ups and window activation go away (fixes audit F08) | Observe | Pop-up confirmation for every suggestion | M |
| M3 | **Act on results at the desk.** Next to a finished result: "这一步完成了 / 还没有" (done / not yet) and "复制下一步为提示词" (copy the next step as a prompt) | Decide | — (the commands already exist) | S–M |
| M4 | **Welcome back on the Mac.** After 10+ min with no keyboard or mouse, or after a lock or sleep, a small card near the boat when you return: time away, what you were on, what changed, what to do first. One click opens the task; Esc dismisses it. Not a window | Recover | — | M |
| M5 | **One needs-you signal.** The buoy shows how many tasks need you. Pings only for finished, failed, or waiting-for-reply work. Never while you're looking at the Codex app, and never twice for the same event | Focus | Pings for every Codex conversation; the buoy covers anchored events only | S–M |
| M6 | **Small menu bar item with Quit.** Open, needs-you count, quit | Trust | Missing (audit F07; D09 requires it) | S |
| M7 | **Sources settings.** Codex ✓, terminal ✓, Claude Code (new), with plain "what Anchor reads" text | Trust | Codex and terminal only | S |

---

## 5. Changes underneath: acquisition, matching, sync, reliability

| # | Change | Now | Size |
|---|---|---|---|
| B1 | **Matching v2 on the Mac**, in this order: (1) your corrections, remembered; (2) folder memory: a folder used by exactly one active task; (3) keyword score against the title, criteria, **and each step**, using Apple's NaturalLanguage word segmentation for Chinese instead of two-character pairs, and recording *which step* matched; (4) the task you're on breaks ties; (5) anything else goes to unsorted. Auto-attach only with a clear margin. Text is read transiently on the Mac, never stored | Title-centric keyword overlap; steps count only 15% and only after the title matches; pop-ups | M–L |
| B2 | **Stable step identity.** Each step gets an ID; done state is stored per ID; Phase 1 data migrates from step positions. Needed before reordering (I2) and step matching (B1) | Done state stored by position | M |
| B3 | **Richer facts from the logs:** start of the reply, duration, and error (parsed on the Mac today, not synced); **waiting for your reply** (Codex `request_user_input` calls, seen 27× in your logs; check what they mean first); **tests passed / failed / not run** (test and build commands in the run plus their exit codes); optionally the current activity ("running a command", "editing files") | Only start, finish, and stop are synced | M |
| B4 | **Claude Code as a source.** Read `~/.claude/projects/**/*.jsonl` (23 sessions in your last 30 days): your request, end of turn, final reply, folder; skip sub-agent sessions. Same pipeline as Codex; needs one folder grant | — | M |
| B5 | **Sync payload v2.** Work events carry title, state, start of the reply (≤ 360 characters), tested, matched step, and duration, with backward-safe decoding. **Privacy change:** reply text is stored on both devices and sent only over your local link | Message text is never stored or synced | M |
| B6 | **Return summary across tasks.** Changes since "away since" for every hosted task, not only the selected one | Selected task only (audit F05) | M |
| B7 | **Presence v2.** Keep the phone's link-based "away" (5 min) and manual leave. Add Mac idle time (system idle seconds, lock and sleep notices) for M4. Each device shows its own catch-up once; your answers sync | Phone link only | M |
| B8 | **Reliability (parallel track, start now).** (a) Stable signing for your daily Mac build so pairing survives rebuilds; likely possible with your free Apple ID's Personal Team, to verify. (b) Reconnect after Mac sleep and phone lock. (c) Find why links drop. (d) Freshness data: last sync time and queued count | Ad-hoc Debug builds can lose pairing keys; drops not investigated | M–L |
| B9 | **Performance and battery.** Keep scans incremental (they are), keep the screen awake only while charging, and pause animation while hidden | Mostly fine | S |
| B10 | **Tests and measurement.** Multi-task matching fixtures in Chinese and English, sanitized real-log replay, and the 30-day usage script re-run against the baseline | Lifecycle fixtures only | S–M |

---

## 6. Things you didn't mention that this experience needs

- **Plans change.** A live plan you can't edit breaks within a day, hence I2 and B2.
- **The board only works if the link works.** Reliability is first-class (B8), and the board must say how fresh it is (I9).
- **The screen sleeping kills the desk board** (I5, audit F10).
- **"Waiting for your reply" is the most valuable agent signal.** An agent idling on a question wastes the most time (B3).
- **You also use Claude Code** across several projects (B4).
- **Agents suggest the next step.** Following them blindly is how projects drift; accepting them into your plan keeps you in charge (I8).
- **Anchor can tell you when the agent didn't test.** 58 of your 88 long runs didn't build or test (B3).
- **Noise needs one rule set,** or the Mac, phone, and buoy will compete (M5).
- **The day needs an ending** (I10).
- **The privacy boundary moves** for reply text (B5). It should be written down, not drift.

---

## 7. What changes in DESIGN.md (needs your approval)

Part I (P1–P6) is unchanged. These Part II/III rules change:

| Rule | Change |
|---|---|
| D04 Portrait dashboard | Cards show your next action and step progress; "complete" follows your plan |
| D05 Landscape desk board | Re-centered on the current task and step; keep-awake while charging |
| D06 Creation through completion | Criteria optional; steps editable with stable identity; only you check steps |
| D07 Connections and sources | No suggestion pop-ups; auto-attach when clear; unsorted list; Claude Code source |
| D08 Departure and return | Return covers every changed task; Mac welcome-back from idle time |
| D09 Mac console and edge | Task-centric main page; one needs-you buoy; menu bar with Quit restored |
| D11 Feedback and recovery | Notification rules (M5) replace "no new notification channels" |
| §2.2 privacy text | Start of reply stored on both devices and sent over the local link only |

---

## 8. Order of work

After each phase, use Anchor for a day before starting the next.

**Status, 2026-10-18:** phases 1–7 are built and committed on `feat/auto-show` (not pushed), one commit per phase; evidence and open device checks are in [VALIDATION.md](VALIDATION.md). Each phase's "done when" below is met only by your own day of use. Track R covers only sync freshness so far; stable signing and reconnect-after-sleep still need your Apple ID's Personal Team.

| Phase | Contents | Done when |
|---|---|---|
| **1. Live plan** | I1 | You check steps and follow next actions for a day |
| **2. Plans you can change** | B2, I2 | You add, rename, and reorder steps without losing what's checked |
| **3. Mac knows your tasks** | M1, M2, M3, B1 | About 4 in 5 new conversations land on the right task without you touching anything, with zero pop-ups |
| **4. Results reach the phone** | B5, B6, I6, I7, I9, I11 | After 30 min away from the desk, the phone tells you each task's state and next step |
| **5. Focus and recover at the desk** | I5, M4, B7, M5 | The phone on its stand stays on and shows your current step; after a call, the Mac catches you up |
| **6. More facts and sources** | B3, B4 | "Waiting for your reply" and "not tested" appear; Claude Code work attaches |
| **7. Comfort** | I3, I8, I10, M6, M7 | Creating a task takes under a minute; the day has a recap |
| **R. Reliability** (parallel, from now) | B8, B9 | Pairing survives rebuilds; the link comes back after sleep without you doing anything |

---

## 9. How we'll know it works

Baseline from your logs (2026-10-17), to re-measure with the same aggregate-only script:

| Measure | Baseline | Target |
|---|---|---|
| Finished results waiting for your next message | median 3.2 min, 75th percentile 17.5 min, 90th 64 min | 75th percentile clearly lower after 2 weeks |
| New conversations attached to the right task without help | — (no matching yet) | ≥ 80%, with < 5% corrected |
| Long runs that built or tested | 34% | Shown on every result; your call whether to push for more |
| Knowing your next action after an interruption | — | Within 5 seconds of looking (weekly self-check) |
| **The real test** | You didn't enjoy using it | You open Anchor every working day for a week without forcing yourself |

---

## 10. Decisions for you

Each comes with my recommendation.

1. **Check steps on the Mac too?** Yes. You review results at the Mac, so answering there saves a trip to the phone.
2. **Completion criteria optional at setup?** Yes. Keep goal and at least one step required.
3. **Matching: precision first?** Yes. Fewer wrong attachments; more items wait in unsorted.
4. **Desk board awake only while charging?** Yes.
5. **Reply text on both devices, sent only over your local link?** You asked for this; please confirm.
6. **Claude Code as a source?** Yes. 23 sessions in 30 days.
7. **Small menu bar item with Quit?** Yes. D09 already asks for it.

---

## 11. Not now

- **Cloud or CloudKit** (needs a paid account): the phone can't update while you're out, and it shows the last sync honestly instead.
- **Push notifications to the phone and Live Activities.**
- **AI-written summaries:** Apple's on-device model is a later option. Facts first.
- **Creating tasks on the Mac:** goals stay on the iPhone, as you chose.
- **Generic app or browser tracking:** excluded by design.
