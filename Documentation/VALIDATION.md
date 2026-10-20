# Anchor native validation record

Last updated: 2026-10-19

## Current results — Meanwhile, the pick-up card, the desk reminder and desk motion (2026-10-19)

Approved by the owner on 2026-10-19: while the agent works on the task you're on, the desk
board says what to do instead of the phone ("Meanwhile": the next task that needs you, or
this task's next step); picking the phone up during work interrupts with a card; leaving
Anchor with the phone in hand reminds you after 2 minutes; and the board's motion follows
real work (water flowing while a run is reported, one swell per new result, the task swap
and the step-done sequence). D05, D08, D10 and D11 in DESIGN.md were changed accordingly.

- **Swift package: 239 tests in 32 suites passed** (Swift Testing's own count; the package
  has no XCTest cases). New: `TaskMeanwhileTests` (7: only while waiting, reading order,
  longest-waiting first, the step after the agent's matched step, the desk hold) and the
  `deskWaitMeanwhile` design-preview fixture.
- **iOS Simulator (iPhone 18 Pro, iOS 27) Debug build and macOS Debug build passed**
  (signing disabled for macOS); `git diff --check` passed.
- **New UI test `testDeskWaitAndPickUp`** with the isolated desk-wait fixture: the board
  shows "Meanwhile → 个人网站" with that chip framed; turning upright shows the pick-up
  card; "Use the phone anyway" dismisses it; a second pick-up shows it again; tapping the
  Meanwhile card makes 个人网站 current, and the card then reads its result to check;
  turning sideways puts the card away. Passed, as did `testLivePlanDeskBoard` with its
  fixture imported. Screenshots were inspected and kept in
  `../Build/Previews/DeskWait-20261019/`. Both fixtures were removed from the simulator
  afterwards.
- **A bug the UI test found and fixed:** the first tap on "Use the phone anyway" did
  nothing because only the 18 pt words took touches; the whole 44 pt row now does (D03).
- **Rest of the iOS UI suite** (run without the new test): 16 passed, 3 skipped (fixtures
  not imported, as before), 2 failed.
  `testLivePlanDeskBoard` failed only because its fixture was not imported (its skip check
  passes on an empty home) and passed once imported. `testFinalConfirmationClearsCurrentWork
  AndRestoresDetailedHistory` fails on "Multiple matching elements" for the task's name
  (card and glance lane); it fails the same way on the previous commit `418f08a`, so it
  predates this change and is left as is.
- **Not verified:** on a real iPhone, whether turning upright always means picking up the
  phone; how the flowing water and the swell read from the corner of the eye and whether
  they distract; that the reminder arrives (and under a Focus mode) and whether 2 minutes is
  right; the soft haptic. The UI tests have no connected Mac, so the water never flows and
  the reminder is never scheduled there; the swell is checked by code path only.
  Phone alerts when an agent finishes and a Live Activity are not built (they depend on a
  device test of background Bluetooth delivery).

## Results — the personal-tool direction, phases 1–7 (2026-10-16 to 10-18)

Built on `feat/auto-show` in one commit per phase, following
[the approved product direction](PRODUCT_DIRECTION_2026-10-17.md): a live plan per task,
the Mac filing agent work under tasks and steps, results and return across every task on
the phone, the desk board and the Mac welcome back, waiting-for-reply and test facts,
Claude Code as a second source, a lighter setup, suggested steps, a today recap and the
menu bar item.

- **Swift package: 351 tests passed** (Core 231, MacFeatures 59, Transport 43,
  IOSFeatures 18). New suites cover live plans and stable step IDs, next actions
  (answer, fix, review, start, wait, finish), TaskMatcher placement, return overview,
  sync freshness and peer contact, the edge buoy count, the Mac away tracker and welcome
  content, Codex turn facts (tests, questions) in the current `exec`/`js` tool format,
  Claude Code turns (prompt to `end_turn`, split replies, interruption, sidechain,
  AskUserQuestion, checkpoint resume), the plan step splitter, suggested next steps and
  the today recap. The existing `idleBoatRestingBehavior` 20 ms timing test failed in two
  concurrent runs and passed 5 of 5 alone; its timing was not changed.
- **macOS and iOS Debug builds passed** with signing disabled.
- **iOS UI tests on a spare iPhone 17 Pro simulator** (isolated stores, uninstalled
  afterwards): workspace rotation, landscape draft suspension, formal task creation and
  restore, two hosted tasks, leave and return, closing setup keeps the draft, the
  goal-and-steps setup rule with Skip on empty criteria, the populated return review at
  normal and largest accessibility size (`scripts/validation/ios-populated-return.py`),
  dashboard readability light and dark (`scripts/validation/ios-dashboard-readability.py`)
  and a design preview of the live-plan desk board. Screenshots of the multi-task return
  page, the desk board (current task, switched task, accessibility size) and the home
  freshness line were inspected.
- **Mac previews** of the task cards, welcome-back card (light/dark) and buoy count were
  rendered with `ImageRenderer` (`ANCHOR_DESIGN_PREVIEW_EXPORT`) and inspected. No Anchor
  Mac app instance was launched.
- **Real-log checks, aggregate only** (counts and record structure, never message text):
  over the last 30 days of Codex logs, 90 test commands were recognized (55 passed,
  5 failed, 30 without a visible exit code) and 7 turns ended with an unanswered question.
  Over 23 Claude Code sessions, the reader ends 143 of 145 turns as finished or stopped;
  the 2 open ones were still running. This check found and fixed assistant entries whose
  `type` sits after a long message body.
- **Not verified:** two real devices syncing reply previews, test verdicts and step
  answers; peer-contact freshness after a real phone lock; the Mac idle, lock and sleep
  detection and the welcome-back panel on a real desktop (focus, Esc, multiple displays);
  notification clicks opening a task; the menu bar item; granting the Claude Code folder
  through the system picker in a signed build; the desk board staying awake while charging
  (the simulator reports no charging state); haptics and VoiceOver on hardware.


## Current results — Codex first connection and suggested tracking (2026-10-15)

- First connection now opens the Mac detail window with a Codex folder authorization guide after bookmark restoration. The picker shows hidden folders and targets the user's home instead of the sandbox container. Release and CloudKit entitlements include app-scoped bookmarks; CloudKit also includes user-selected file access.
- Discovery proposes matches from the latest user request, including conversations created before the anchor and updated afterwards. Suggestions require explicit confirmation, allow choosing another active task, and can be ignored or reviewed later. Existing bindings keep their owner. Conversation text remains transient and local.
- Core regression: **178 tests passed**. Mac feature regression: **39 tests passed with `--no-parallel`**. In the initial concurrent run, the existing `idleBoatRestingBehavior` test failed its 40 ms timing assertion; no boat implementation or timing assertion was changed. The serial Mac rerun passed. New tests cover explicit confirmation, corrected ownership, duplicate confirmation, ignored-pair persistence, completed-task rejection, latest-request filtering, ambiguous suggestions, and a resumed-conversation phone/Mac lifecycle journey.
- **macOS Release build passed for arm64 and x86_64 with signing disabled**, using `xcodebuild -project Anchor.xcodeproj -scheme 'Anchor macOS' -configuration Release -destination 'platform=macOS' -derivedDataPath /tmp/anchor-codex-derived CODE_SIGNING_ALLOWED=NO build`. Both entitlement plists pass `plutil -lint`.
- Onboarding and review views were rendered through `NSHostingView` with disposable data and visually checked in light/dark. The preview helper uses `ANCHOR_DESIGN_PREVIEW_EXPORT`; files for this run are `/tmp/anchor-codex-previews`. Initial ImageRenderer output omitted the AppKit scroll content, so final inspection used NSHostingView snapshots. No production Anchor app was launched or replaced.
- **Not verified:** a fresh signed installation's system folder picker, granting and reopening a real security-scoped bookmark, real phone pairing, keyboard/VoiceOver interaction, or runtime popup focus. Unsigned compilation and model tests do not constitute distribution permission acceptance. No new installer was published.

## Current results — macOS edge berth, boat, cues and window cards (2026-10-12)

- Owner-requested changes: the edge boat moved to the lower-right corner above the Dock. It was redrawn in the app-icon language, the anchor now sinks a fixed 84 pt below the boat (drop 2.1 s → 1.5 s), the edge sounds are synthesized (four cues instead of Bottle/Tink), and the detail window was reorganized into a single card system without changing its skeleton or page order.
- **Swift package: 246 tests passed** (Core 158, Transport 43, MacFeatures 27, IOSFeatures 18). New tests: fixed berth geometry (`AnchorEdgeEffectsMetricsTests`) and cue bounds, WAV encoding and pitch variation (`AnchorEdgeSoundSynthesizerTests`). The multiple-anchor tests now expect the dedicated `anchorJoined` / `anchorReleased` receipts.
- **macOS and iOS Debug builds passed** with signing disabled.
- One `ANCHOR_UI_TESTING=1` instance was launched, tracked by PID, terminated, and its temporary store and defaults suite were removed. Screenshots confirmed the berth in the lower-right corner above the Dock (tucked state) and the new current-work layout fitting above the fold. Populated cards (multiple tasks, attention, events) were checked in light and dark with `ImageRenderer` in a scratch package copy, not in the running app. The drop sequence was checked frame by frame the same way.
- Cue loudness was measured offline: the former Bottle and Tink played at about -51 / -53 dBFS RMS at their configured volumes. The new landed and retrieved cues play at about -45 / -46 dBFS, and the joined and released receipts at about -49 / -50 dBFS.
- **Not verified:** the live drop/splash/retrieve on a phone-anchored task; how the cues sound and how intrusive they are on real speakers; whether the panel's transparent area passes clicks through to apps underneath (synthetic input was not used against the user's desktop); multi-display and full-screen Spaces; VoiceOver for the new connection button and activity disclosure.

## Current results — iOS dashboard readability (2026-10-02)

- Main-conversation capsules now show a ring plus integer percentage, or `? 未知` / `? Unknown` when progress is absent. Visible and accessibility values use the same joined-first conversation. Existing task colors, staggered card sizes, status lamps and completion seals are retained. Setup's cyan primary button now uses the adaptive `onAccent` text/spinner color. Calculated normal enabled text contrast is **6.56:1 light** and **8.05:1 dark** (previous light white-on-cyan: **1.72:1**); these calculations do not establish disabled, pressed or transparency acceptance.
- **The targeted Core data journey passed:** nil, 0%, 63% and 100% remain distinct after secondary/main conversation reordering and a repository reload. No fixture reader or sample data was added to shipping targets.
- **iOS Debug build-for-testing passed.** The creation close/restore/discard/success UI regression passed. The final readability UI test passed separately in real simulator light and dark appearance, with zero failures or skips. Each appearance covers portrait, landscape, the largest accessibility text category and opening a visible task detail. This was targeted verification, not a rerun of the complete app test suite.
- Screenshots were visually inspected. Standard-size progress capsules fit the existing card geometry in portrait/landscape and both appearances. The setup button's enabled light-state label is visibly legible. At the largest accessibility size the capsules enlarge without clipping, but the **existing fixed home header and bottom create control can overlap scrolled content**; whole-page accessibility acceptance remains open. Actual VoiceOver speech, hardware viewing and haptics were not tested.
- An initial attempt to select dark mode with launch arguments still rendered light. Final runs set the simulator's system appearance and restored it afterwards. One intermediate large-text navigation assertion tapped the first card after it had scrolled behind the header; the final test taps the fully visible measured-progress card. The overlap is recorded as an outstanding UI issue, not hidden by the passing test.
- Repeat with `python3 scripts/validation/ios-dashboard-readability.py --device SIMULATOR_UUID` after installing the debug app on a booted simulator. The runner generates fixtures through the Core test, imports only a reserved UI-test store, requires both UI passes without skips, restores system appearance and removes temporary event data even on failure. The production-data checker rejects this fixture namespace and export variable in shipping code.
- Raw results: `/tmp/anchor-readability-review-20261002/`. Retained visual evidence: `../Build/Previews/Readability-20261002/` (seven named screenshots and their result mapping). Earlier mislabeled/duplicate screenshots were removed from that preview folder.
- Ocean/horizon, hanging-anchor and boat-docking rotation ideas are interaction proposals outside the shipping app. The in-conversation previews support reversible rotation; they do not prove Core Motion behavior, UIKit rotation, rotation-lock handling or physical-device feel.

## Current results — product-scope cleanup (2026-10-02)

- The pre-cleanup source was committed and pushed as `682a382` before deleting code. The current cleanup removes the Safari target/adapter, general Mac application observer, unused UI and source-action execution APIs. Legacy event/decision models and source UUIDs remain decodable; dashboard command rejection and stored-data filtering remain covered.
- **Swift package regression succeeded:** Swift Testing reports **223 tests** across Core (149), Transport (43), MacFeatures (21), and IOSFeatures (10). One optional local-Codex-rollout test was skipped because `ANCHOR_REAL_CODEX_ROLLOUT` was not supplied. The count changed from 236 by removing 14 retired-feature tests and adding one regression that quarantines old raw web signals while continuing CLI ingestion.
- The first run, concurrent with both Release builds, failed two fixed-delay animation assertions. After the builds finished, a standalone rerun passed; the final run after removing the remaining action APIs also passed. No animation timings were changed to obtain that result.
- Final **iOS Simulator Release and macOS Release builds passed** with signing disabled. The macOS product retains `Contents/Helpers/anchor` and no longer embeds `AnchorSafariExtension.appex`. The CLI App Group and pairing entitlements remain unchanged.
- **Five iOS UI tests passed on the final source:** note persistence, leave/return, final completion/history, populated return details and populated return at accessibility text size. Both xcresult summaries report zero failures or skips (3 workflow + 2 populated-return tests). The existing isolation script removed both temporary event stores after the run.
- **macOS UI runtime acceptance remains unverified:** both the initial attempt and a separate retry failed before running either selected test because the runner timed out while enabling system automation mode. Debug test-bundle compilation succeeded. The retry wrapper found no pre-existing test instance and checked/terminated only processes from its owned temporary build path after exit. No GUI permission settings or user data were changed.
- Production-data boundary, project plist validation and diff-whitespace checks passed. The export script now includes the project-only Skill and its license/provenance alongside AGENTS.md.
- `DESIGN.md` is unchanged by this cleanup; its SHA-256 remains `760bc3e4027a2c6c7ce0af551e8ece41771abd4b42661661822c2b93b88c39f3`.

The local cleanup ledger is `../Build/Cleanup-20261002.json`. It records removed generated files, duplicate-to-retained paths and preserved-input hashes. Submission records keep their original historical hashes even though old ZIP/extracted verification copies have been removed. Current source exports are separate from the original competition submission.

Raw logs for this run use the `/tmp/anchor-cleanup-*` prefix. This section describes the cleanup snapshot; the dated sections below preserve earlier evidence. Historical Safari/decision acceptance items below no longer apply to the current product. Hardware Bluetooth/Bonjour, signed Keychain/CLI handoff, speech permissions and optional provisioned CloudKit remain separate device/account acceptance checks.

## Historical source-submission results (2026-09-30)

- Shared package: **205 tests passed** (149 core, 37 transport, 19 Mac features) in the final source-submission regression. These cover local persistence, slow peer acknowledgements, eventual outbox delivery, decision ownership and idempotency, duplicate process IDs, source ingestion, real loopback Bonjour pairing, reconnect, event acknowledgement, noninteractive Keychain access, and production pairing migration. The optional test against a user-supplied live Codex rollout was skipped because `ANCHOR_REAL_CODEX_ROLLOUT` was unset.
- Earlier iPhone 18 Pro / iOS 27 Simulator validation: **12 full-suite UI tests passed**. After the reliability fixes, **3 targeted tests passed again** for creation and restoration, fresh launch, and speech permission/error handling with cancel and restart. These UI suites were not repeated for the final source-submission regression.
- Earlier macOS validation: **4 functional UI tests passed** for empty workspace, pairing entry, expanded sidebar hit testing, collapsed navigation, and the resting edge entry. This run did not repeat the separate accessibility audits. These UI tests were not repeated for the final source-submission regression.
- Final iOS and macOS **Release builds passed** with code signing disabled.
- The built CLI ran actual `true` and `false` commands. Its start and finish records were durably queued with exit codes 0 and 1.
- Native Mac lifecycle stress test: **60 runs and 120 events completed**, with file replacement at run 30, truncation at run 45, and restarts at runs 20, 40, and the end. It had no lost or duplicate records or polling timeouts. Observed peak RSS was 165,936 KiB (about 162 MiB). The input was controlled lifecycle data; this does not establish long-term memory stability under live AI use.
- The production data boundary check and `git diff --check` passed.

Earlier command output is stored outside the repository in `../Build/logs/real-function-validation-20260930/`. Final source-submission regression output is stored in `../Build/logs/keychain-source-submission-20260930/`.

## Final source-submission verification (2026-09-30)

- Reran the full shared package suite after the Keychain changes: **205 tests passed**; the optional live Codex rollout check remained skipped.
- Both macOS Release and iOS Simulator Release builds passed with signing disabled. No app was launched by these build checks.
- Production data boundary and `git diff --check` checks passed. The source export includes the current working files, including the noninteractive Keychain wrapper, modern pairing migration, isolated validation, stable signed-development configuration, tests, and native workflow guidance.
- Signed fresh-install and upgrade permission behavior remains a device/account acceptance check. Network, Bluetooth, and notification permissions remain separate system permissions requested when their corresponding features need them.

## Keychain authorization follow-up (2026-09-30)

- Diagnosed three concurrently running ad-hoc Mac app instances, including two
  temporary validation/capture bundles. Their designated requirements used
  different code hashes. All three and the attached Xcode debug session were stopped.
- Background transport Keychain calls now disallow both legacy macOS password
  dialogs and Data Protection authentication UI. A disposable locked legacy
  keychain returned authentication errors immediately for reads and writes.
- **30 targeted tests passed** across pairing identity and local-link transport,
  including concurrent denied reads, legacy device-ID retention, stable fallback
  identity, persisted peer-key updates, network reconnect and Bluetooth fallback.
- Final macOS Debug and iOS Simulator Debug builds passed. The isolated Mac
  lifecycle script passed startup, event capture, restart without replay,
  out-of-order/duplicate input and interruption capture. No Mac Anchor processes
  remained after cleanup. Production data boundary and diff checks passed.
- Debug UI/local validation uses in-memory pairing credentials; the validation
  scripts own their app PIDs and clean up on exit, interrupt and termination.
  Existing inaccessible production credentials were not deleted or reauthorized.
  Stable-signature real-device pairing and recovery of previously denied
  credentials remain device/account acceptance checks.

## Production permission reduction follow-up (2026-09-30)

- Production `PairingIdentityStore` now defaults to the Data Protection keychain.
  Mac Release and the optional stable signed development configuration use this
  backend; ad-hoc Debug retains noninteractive legacy compatibility. Formal UI
  and isolated local validation remain memory-only.
- Only a confirmed missing modern item can trigger a noninteractive legacy
  migration. Readable secrets are copied to the modern backend without deleting
  old items. A denied legacy credential can be replaced by freshly verified
  pairing in the modern backend. Signing failures do not fall back to legacy.
- **36 targeted tests passed** for identity caching, migration, entitlement
  failure handling, persisted legacy test updates, network and Bluetooth paths.
  Modern-backend migration is tested with a controlled client; successful
  production Keychain access still requires signed-device acceptance.
- macOS Release and iOS Simulator Release compiled successfully with signing
  disabled, without launching an app. These are compilation checks, not proof of
  fresh-install or upgrade permission behavior. Distribution acceptance must use
  an App Store build or a correctly signed/notarized Developer ID build under a
  fresh macOS user account.

## Reliability changes verified

- Task edits finish after the durable local save. A background worker drains the outbox, so a slow or disconnected peer does not hold setup, notes, or confirmation on screen. Failed deliveries stay queued for retry.
- Decision confirmation rejects repeat taps and stale sheets. Mac source actions use the envelope's owning task and claim a newly resolved decision once, including when reconnect replays history.
- Connection, presence, source-health, and cloud refreshes preserve actionable operation errors until dismissal or a successful user operation.
- Photo preparation and file access run off the main actor. A cancelled plan view rejects a late image load from a previous task.
- Speech audio-session cleanup belongs to its recognition request. A late callback cannot disable a newer recording's controls or deactivate its audio session.
- Repeated process IDs no longer create duplicate rows or trap snapshot, history, and source lookups.
- Native validation isolates preferences, pairing identity, cloud sync, and the source inbox, so it does not consume installed app data.

## Recording-data removal

- Ordinary Debug and Release launches create no recording tasks. The scheduled iOS return generator, visual-only microphone override, fixed profile trends, arbitrary progress bars, storyboard illustrations, and static cloud-success claims were removed.
- iOS settings state that background notifications are unavailable. Decisions retain source-owned execution status until an observed update.
- On upgrade from a recording build, the local repository backs up `session-state.json` before removing reserved recording task IDs and marked synthetic process activity. Real goals and notes remain. Tests cover backup, preservation, outbox cleanup, and restart idempotency.
- `SimulatedProcessSource` is compiled only in the core test target. UI tests use private temporary storage and do not populate ordinary launches.

## Run the checks

From the repository root:

```sh
python3 scripts/validation/check-production-data.py
cd Packages/AnchorKit && swift test
```

The `Anchor iOS` and `Anchor macOS` schemes in `Anchor.xcodeproj` include formal UI tests. GitHub Actions runs package tests, unsigned Release builds, UI-test compilation, and archive checks for the production apps. A clean source archive can be generated with `python3 scripts/release/export-source.py /tmp/Anchor-source-submission.zip`.

## Device and account acceptance still needed

Physical iPhone–Mac Bluetooth/Bonjour behavior, successful on-device speech transcription, provisioned CloudKit, signed Safari App Group handoff, and long background/sleep recovery require the corresponding devices and signing account. The simulator speech test accepts a clear recognizer-unavailable error when controls remain usable. The unsigned builds and controlled stress run do not establish those services or a zero-defect guarantee.

## 2026-10-02 — iOS 草稿、记录保存与状态灯

- 用户授权实现 UI/UX 评审的 I1、I2、I3。草稿在当前 App 使用期间保留，成功创建或明确放弃后清空；记录保存中防连点，失败保留文字，成功反馈跟随本地持久化结果；移除任务卡五角星，完成使用对勾徽章。
- 新增 `AnchorIOSFeaturesTests`：7 个测试通过，其中状态映射参数测试覆盖全部 7 种 ProcessStatus。覆盖失败重试、未完成保存期间重复提交、成功后再次点击、空白输入、混合会话、无进程个人计划、环境进程过滤和主动中断。命令：`swift test --scratch-path /tmp/anchor-uiux-swift-build --filter 'AnchorNoteSubmissionTests|HostedTaskIndicatorTests'`。
- iOS Debug 模拟器构建通过。4 个不同 UI 流程测试通过：关闭/恢复/放弃/提交后重置草稿；横屏暂存与恢复；连续创建两个任务及昵称恢复；保存记录后重开可见已保存内容。测试采用 `ANCHOR_UI_TESTING=1` 和独立存储。
- 截图检查发现新增草稿提示与底部按钮重叠，已将提示与放弃入口移至底部 safeAreaInset 操作栈，最终将滚动内容和底部操作放入独立的 VStack 布局区域，并裁剪滚动边界，避免固定按钮覆盖步骤导航。测试增加两者不重叠的坐标断言。早期失败分别为 SwiftUI 类型推断超时和测试对系统确认按钮的多节点匹配，已拆分表达式并调整测试定位。
- 产物：`/tmp/anchor-uiux-unit.log`、`/tmp/anchor-uiux-ios-tests-r2.xcresult`（包含两个通过的回归测试及已修正的测试定位失败）、`/tmp/anchor-uiux-ios-tests-r3.xcresult`（两项通过）、`/tmp/anchor-uiux-ios-layout-v2.xcresult`（横屏通过）、`/tmp/anchor-uiux-ios-layout-verified.xcresult`（草稿与布局坐标断言通过）。
- 本次未重跑全部包测试或 macOS App UI 测试；未验证真机触感、VoiceOver 全流程和强制退出后的草稿恢复。草稿采用内存暂存，强制退出恢复不属于本次实现。

## 2026-10-02：收敛为 AI／终端任务看板

- 两个正式启动器启用 TaskDashboardPolicy；Mac 不再注册 MacWorkspaceProcessSource 和 WebProcessSource，当前来源名称请求不再枚举系统应用，入站同步不再派发决策动作。
- 当前任务和并行任务视图过滤旧环境／浏览器来源、决策对象及相关时间线／返航变化；旧存储与归档保持兼容。决策命令（包括任务作用域包装）在正式模型中被拒绝。
- 来源设置保留 Codex／终端；移除普通应用／Safari 设置入口，明确 ChatGPT 内部任务尚未接入。旧扩展打包资源仍保留，正式 App 不消费 WebInbox。
- 31 项相关 Swift 测试通过，包含新增 2 项范围与兼容测试，以及 Codex 生命周期、CLI 命令、模型可靠性回归。日志：/tmp/anchor-dashboard-tests.log。
- 最终源码的 macOS Debug 和 iOS Simulator Debug 编译通过，均为 CODE_SIGNING_ALLOWED=NO。日志：/tmp/anchor-dashboard-mac-build.log、/tmp/anchor-dashboard-ios-build.log。
- git diff --check 通过。本轮未启动 GUI App，未重复 UI 自动化、实际手机同步或签名发行验证；未访问或修改生产配对凭据。未新增 ChatGPT／其他 AI 应用接入，不声称已有自动卡顿识别。

## 2026-10-02：核心使用流程最终回归

### 提交版本核对与更正

- 实际提交记录指向 `../Build/Submission-v4/Anchor-source-submission-v4-20261001.zip`，SHA256 为 `e8ed55d1f6a4e4c8256fa58792a53eb70480abd383e733c58b7b2763abd10005`，本次未修改此文件或比赛提交。
- v4 内包含 CodexAutoAssociation 和自动扫描代码，并非只有页面；原验证未覆盖所有实际触发边界。旧规则排除单关键词和投锚超过 30 分钟的新会话。
- 本机 `/Applications/ChatGPT.app` 的 CFBundleIdentifier 是 `com.openai.codex`，版本 `26.928.40906`。此前“ChatGPT 内部任务未接入”的笼统描述不准确：本地 Codex 格式任务属于现有接入，普通聊天不应一并声称已支持。

### 实现与证据

- 修复单关键词／长时间锚点匹配、手动与自动绑定跨任务重启恢复及终端结束事件归属。后续用户收紧了离开规则，见文末长时间中断验证。新增显式“暂时离开”入口。
- **220 项 Swift 测试通过**：155 Core、37 Transport、21 MacFeatures、7 IOSFeatures。日志 `/tmp/anchor-workflow-full-tests.log`。
- 新增完整流程测试使用两个独立持久仓库、生产 LinkedSessionRepository、MacSourceSetupModel 文件扫描、CodexSessionBinder 和 CodexLifecycleFileSource，验证投锚／记录、自动发现、跨任务恢复、状态回传、返航摘要、结束、双端归档及重新读取历史。事件传输在该测试中使用内存转发，不冒充物理设备测试。
- 单独启用真实 Bonjour 测试：从本机近期实际 Codex 日志提取一组开始／完成事件，仅保留时间戳、事件类型和 turn ID；经真实 loopback Bonjour 配对、断线、事件积压、重连同步到返航摘要。输入是实际事件重放，不代表现场发起了新 AI 请求，也未复制提示正文。
- **2 项 iOS UI 测试通过**：暂时离开 → 返航四卡 → Back 继续；最终确认结束 → 重启 → 历史详情。使用 ANCHOR_UI_TESTING=1、独立存储、内存配对。结果 `/tmp/anchor-core-workflow-ios.xcresult`。
- 原生 Mac 隔离生命周期脚本通过：启动、开始／完成、中断、重启游标、迟到和重复事件；记录目录 `/tmp/anchor-mac-local-e2e.O5zApB`。测试实例由脚本持有 PID 并关闭，没有使用生产凭据或会话。
- macOS Debug 最终构建通过；iOS UI 测试构建通过。最终 iOS 增量构建记录 `/tmp/anchor-core-workflow-ios-final.log`。均关闭签名，不代替发行安装验证。
- 尚需真机验收：手机与 Mac 的系统权限、同网配对、蓝牙实际距离、后台／休眠恢复，以及用户真实内容在关键词匹配中的命中情况。首次文件夹授权和终端 Shell 接入仍需按系统流程完成。

## 2026-10-02：长时间中断、竖屏返航与蓝牙采样修复

以下记录为上一轮验证；其中 10 分钟默认值已被后续用户明确指定的 5 分钟覆盖。

- 用户最新规则：办公室内短暂走动继续工作；不做 Wi-Fi RSSI 采样。已有认证连接持续中断 10 分钟才进入自动交接／离开。单独 BLE 断开或信号变弱且 Wi-Fi 通道仍连通，不触发离开；不足 10 分钟的失联重连不触发返航。手动“暂时离开”立即生效。
- 返航由认证重连或明确的手动返回触发，横屏／近场读数本身不触发。四卡摘要竖屏可用；前台每次返航一次系统触感，Back 后才出现可关闭的横屏提示。
- BLE 已连接后通过 readRSSI 持续采样，信任认证前不把候选设备距离当作当前 Mac；加入三样本确认、强弱阈值滞回、失效读数／12 秒过期清理、断开时取消采样。RSSI 用于近场指示，不单独决定离开。
- 新的 awaySince 可选操作字段和 awayStartedAt 会话字段保存失联开始时间，使返航摘要包含 10 分钟确认期的变化；快照按真正创建时间记录。旧的 presence 操作仍可解码。重连回调可补算被 iOS 暂停的计时器，但不宣称能补出系统从未交付的断连信号。
- **228 项 Swift 测试通过**：160 Core、40 Transport、21 MacFeatures、7 IOSFeatures。覆盖 599 秒／600 秒／20 分钟断连、Wi-Fi 保持连通、转屏不返航、未配对／权限异常、摘要完整时间范围、自动重连模型链路、一次性触感标记、旧事件兼容及 RSSI 过滤。日志：`/tmp/anchor-return-tests-verified.log`。
- 本次全量测试启用了实际本机日志两条生命周期事件的 Bonjour 回放：`ANCHOR_REAL_CODEX_ROLLOUT=/tmp/anchor-real-lifecycle-sample.jsonl`。该数据仅含类型、时间与 turn ID；测试通过，不代表真实无线走动验收。
- **1 项 iOS UI 流程测试通过**：暂时离开 → 横屏仍保持离开 → 竖屏手动返航 → 四卡 → Back → 横屏提示 → 转屏后提示消失。只用隔离存储与内存配对，测试退出已终止其 App。结果：`/tmp/anchor-return-review-ios.xcresult`；截图：`../Build/Previews/Return-20261002/`。截图是模拟器实际渲染，任务文字由 UI 测试输入，没有注入虚构任务进度。
- iOS 测试构建与 macOS 构建通过；macOS 日志 `/tmp/anchor-return-review-mac.log`。生产数据边界脚本、git diff --check 通过。未启动新的 Mac GUI 进程。
- 尚需真机验收：真实 BLE RSSI 阈值、无线离开／重连、iPhone 触感，以及锁屏／后台／Mac 休眠。iOS 不允许自动把后台 App 强行带到前台；本次没有新增后台通知或提示音。断连只能作为长时间中断的近似证据，不能识别人离开和 Mac 关机的区别。

## 2026-10-02：5 分钟、独立蓝牙通道与返航弹簧动效

- 按用户明确要求将默认失联确认门槛改为 300 秒；保留 3 秒交接和手动离开立即生效。任一已认证通道在线即保持工作，只有蓝牙也可独立支持工作／离开／返航。修复网络不可用时单独 BLE failed 被掩盖为 unavailable 的汇总状态。
- BLE 近场输出离散 near／far；连续 3 个明确样本确认方向，中间滞回区保留此前结果，缺失／过期证据为 unknown。新增中间区间、噪声打断和方向反转测试，无线阈值仍需真机校准。
- 返航四卡以 scale 0.92、向下 22pt、spring(duration: 0.36, bounce: 0.26) 弹入，卡间 35ms；入口只消费一次模型的返航展示标记，与一次触感同步。转屏、子弹层返回及摘要数据刷新不重复弹入。宿主取消返航时的整页上滑，避免与卡片动效叠加。系统或 App 减少动态效果时用 160ms 淡入。
- **231 项 Swift 测试通过**：161 Core、42 Transport、21 MacFeatures、7 IOSFeatures。覆盖 299／300／301 秒、蓝牙独立工作、蓝牙唯一通道 disconnected／failed 后恢复、RSSI 离散状态。蓝牙通道测试使用真实 AnchorBonjourClient 汇总逻辑与模拟的 BLE 连接回调，未启动 Bonjour，不冒充物理 BLE 测试。实际本机 Codex 两事件的 Bonjour 回放也通过。日志 `/tmp/anchor-five-minute-tests.log`。
- **2 项 iOS UI 流程测试通过**：常规动效、减少动态效果；都验证暂时离开、转屏不返航、竖屏摘要、Back 和横屏提示。结果 `/tmp/anchor-return-spring-ios.xcresult`，日志 `/tmp/anchor-return-spring-ios.log`。测试 App 使用隔离存储／内存配对，并在结束时终止。
- 已录制模拟器实际画面并提取入场阶段帧检查；5 秒预览 `../Build/Previews/Return-spring-20261002/return-card-spring-preview.mp4`，包含进入返航摘要与返回工作区。录制进程已结束。视频不验证实体触感。
- iOS 测试构建、macOS 构建通过；Mac 构建日志 `/tmp/anchor-five-minute-mac.log`。未启动新的 Mac GUI App。git diff --check 与源码导出中的生产数据边界检查通过。

## 2026-10-02：返航数据链路与有内容的页面

### 数据与行为

- `ReturnReviewContent` 从当前真实投影派生投锚上下文、离开时长、任务状态统计及查看顺序。变化列表使用 `ReturnSummary`，当前进展使用任务最新状态；两者分别回答“离开时发生了什么”和“现在怎么样”。
- 新增 `ReturnDataJourneyTests`：两个持久仓库通过生产 `LinkedSessionRepository` 传输，手机先投锚并离开，Mac 在断线期间收到七个不同状态任务，手机先打开空摘要，再重连补到数据。断线和收包由测试传输控制；验证迟到内容进入已打开页面、重复回放去重、读取持久仓库恢复、返回后两端仍保留任务及投锚记录，以及补数不重复触感标记。
- 回归样例包含两个完成、一个运行中、一个明确失败、一次主动中断、一个断连、一个排队任务。过滤后的返航事件统计排除旧环境活动，并且不把主动中断计为失败。
- 已修复真实交互问题：任务 ID 与 sheet 展示状态分开更新，首次点“下一步”可能打开空内容；改为随 sheet 原子传入所选任务。详情保持选中的任务身份，实时刷新不会把详情替换成另一个任务。
- 首卡支持投锚记录全文；变化入口支持完整标题、详情、来源和时间；状态统计有图标与文字，大字号使用两列；下一步优先查看明确失败及需要留意的任务。没有记录或 Mac 离线时明确说明状态。保留用户确认的四卡骨架、弹簧入场及返回顺序。

### 验证与隔离

- **236 项 Swift 测试通过**：162 Core、43 Transport、21 MacFeatures、10 IOSFeatures。日志 `/tmp/anchor-populated-all-tests.log`。其中真实本机 Codex 生命周期样本的 loopback Bonjour 回放已启用并通过；不把此结果视作手机无线实测。
- macOS Debug 构建通过，日志 `/tmp/anchor-populated-mac-build.log`；iOS 在 UI 测试中完成构建，均关闭签名。
- **5 项不同 iOS UI 流程通过**：有数据的标准字号与 Accessibility XXXL、无远端任务记录的手动返航、减少动态效果、最终确认归档后重启读取历史。有数据流程读取记录全文、全部变化、校验状态计数、打开对应失败任务详情、返回工作区。最终两项数据 UI 测试 2 passed／0 skipped：`/tmp/anchor-return-review-complete/review.xcresult`；三项既有流程：`/tmp/anchor-return-data-regression.xcresult`。
- 已逐张检查四卡、长标题、变化列表、任务详情、大字号和横屏截图，修复了大字号图标占位过窄。横屏改用全屏截图，避免应用元素截图在旋转后错误裁剪。最终截图目录 `../Build/Previews/Return-data-20261002/complete/`，可读名称以 `standard-`／`large-` 开头。
- 页面数据从测试目标生成的真实仓库文件导入两个保留 UUID 的 UI 隔离目录；正式 App 没有新增固定样例或导入入口。生成的仓库文件和两个注入目录会被清理；回归数据仅在测试源码中，截图保留为验证证据。生产数据边界检查禁止这次导出变量和保留 UUID 进入正式源码。
- 可复现命令：先在指定模拟器安装 Debug App，再执行 `python3 scripts/validation/ios-populated-return.py --device SIMULATOR_UUID`。脚本生成临时事件仓库、运行两项 UI 测试，要求 2 passed／0 skipped，结束或失败后清理它拥有的目录，保留日志和 xcresult。清理覆盖 Xcode 重装后迁移到的新沙盒路径；本轮已确认临时仓库及当前模拟器中的两个保留 UUID 目录均不存在，测试 App 已退出。
- 初轮视觉测试找到并修复了 sheet 空内容；最大字号测试改为先把点击中心滚到固定 Back 上方；横屏截图等待系统转屏动画结束，避免截取旋转中间帧。一次 Xcode 失败诊断收集超时，后续关闭冗长的 sysdiagnose 收集，保留测试截图与断言结果。
- 本轮覆盖软件链路与模拟器 UI；实体 iPhone 的无线重连、后台唤醒和触感仍属于真机验收范围。

## 2026-10-09：Mac 边缘锚多任务含义与 Codex／终端来源边界

### 实现

- 边缘锚改为“手机上至少有一个有效投锚”：手机投锚确认按任务集合保存；第一个投锚抛锚、最后一个结束收锚；中途新增任务只拉动绳索并溅起小水花，结束其中一个只轻提绳索；手机或 Mac 切换、查看任务不再收锚或重新抛锚。小船图形、抛锚与收锚动画参数未改。
- Codex 发现只接受用户发起的对话（`thread_source` 为 user／chatgpt_handoff，且没有子代理来源或父线程）；扫描窗口放宽到 72 个最近文件后再截取 12 个候选。旧版自动绑定到子代理日志的记录在恢复时移除。
- 自动关联只读取用户输入：去掉打开页面信封、提及文件与引用的 ChatGPT 对话等附带上下文，有“My request”段落时只取其后文字。
- 同一 Codex 对话的多轮在看板展示层合并为一行（身份与位置取第一轮，状态取最新一轮，保留全部事件）；原始事件、运行记录与历史数据不改写。桌面端来源名为 ChatGPT，标题为工作区文件夹名。
- 终端命令运行不足 10 秒的开始／结束成对移入 `.ignored`，不产生进程；新开始的命令满 10 秒才上报。退出码 129／130／131 记为中断，不计入失败与返航失败数。

### 验证与边界

- **243 项 Swift 测试通过**：158 Core、43 Transport、24 MacFeatures、18 IOSFeatures；1 项可选的本机 Codex 回放测试未提供样本而跳过。新增覆盖：多任务切换／新增／结束时的边缘行为、子代理过滤与候选挤占、附带上下文剥离、对话合并、短命令忽略、长命令先开始后结束、中断口径。
- macOS 与 iOS Simulator Debug 构建通过（关闭签名）；`git diff --check` 与生产数据边界检查通过。
- 本机 `~/.codex/sessions` 只读核对（只统计结构与数量，不输出内容）：210 个日志中 47 个用户对话、163 个 guardian／子代理会话；新逻辑候选全部为用户对话，提取的请求不含附带上下文标签。按旧逻辑模拟时，156 个 guardian 会话中有 106 个会被关联到其父对话的锚点，且有 4.3% 会匹配无关锚点；用户对话以输入文字为题时的自身匹配从 17／33 提升到 33／33。
- 未做：与实体 iPhone 联调的边缘回执观感与音量、真实终端中 10 秒规则的使用感受、合并对话在手机图表上的视觉检查。

## 2026-10-13：此刻总览、边缘浮标与前端打磨

### 实现

- iOS 首页 Anchors 进度图改为“此刻”总览（`TaskTide`／`WorkGlance`／`HomeTideCard`）：标题计数、按任务的状态轨道、最新变化；横屏使用紧凑版。任务卡三灯改为状态文字，进度胶囊仅在来源上报时出现。
- Mac 以同一总览（`MacGlanceCard`，共享 `TideLaneView`、`AnchorTaskIdentity`）取代四列任务网格；边缘小船旁新增失败／等待／完成浮标（`EdgeBuoySignal`）。
- 文案：Mac 失联改为灰色、权限问题琥珀色；Focus 改为“已进行”；返航 Back 改为“继续工作”主按钮；返航变化不再显示原始 Codex 事件名；移除退役的“Waiting for judgment”；Mac 来源设置去除工程用语；Mac 日期按中文界面格式化。

### 验证与边界

- Swift 测试：新增 `TaskTideTests`（8）、`EdgeBuoyTests`（3）、`DesignPreviewFixtureTests`、`MacDesignPreviewTests`，全部通过。全量运行中 `AnchorEdgePresentationModelTests` / `AnchorPhoneAnchorStateTests` 的计时类用例在并行负载下偶发失败，单独重跑 3 次均通过；此前未改动 Mac 代码时已出现同一现象。
- iOS Simulator（iPhone 18 Pro，iOS 27）Debug 构建与 `DesignPreviewUITests` 通过：竖屏浅色／深色、横屏、AccessibilityXL 与空态截图已人工检查。`DashboardReadabilityUITests` 的未知进度断言同步改为“未上报进度”，本轮未重跑。
- macOS Debug 构建通过；Mac 总览与浮标仅以 ImageRenderer 渲染检查（浅色／深色），未启动 Mac 应用做实机交互。
- 测试数据只写入隔离的模拟器 UI 测试目录与临时目录；未访问生产存储或钥匙串。
- 未做：真机一眼可读性、浮标在多显示器／全屏下的可见度与打扰程度、Live Activity／灵动岛（需新增扩展 target 与后台更新方案，另行决定）。

## 2026-10-13：统一色彩令牌

- 新增 `AnchorColorTokens`（iPhone 与 Mac 唯一色值来源）与 `AnchorStateTone`；删除 Mac 资源目录中 21 个独立 colorset 与依赖它们的 `check-mac-contrast.py`；`AccentColor`、`AnchorLaunchBackground` 与令牌同步。规范见 [COLOR_SYSTEM.md](COLOR_SYSTEM.md)。
- `AnchorColorTokenTests`（6 项）检查文字 4.5:1、状态填充与控件边界 3:1、品牌／操作底上内容 4.5:1、身份色 2.5:1 且远离状态色相、令牌唯一；全部通过。全量 Swift 测试 265 项通过（本轮未出现计时类偶发失败）。
- iOS Simulator 与 macOS Debug 构建通过；iPhone 首页浅色／深色截图与 Mac 总览浅色／深色渲染已人工检查。未做：真机、增强对比度与减少透明度下的截图，`DashboardReadabilityUITests` 未重跑。

## 2026-10-13：横屏工作台、无文字邀请与到达动效

- 新增 `WorkInvitation`（邀请条件与桌前时段）、`WorkInvitationHarbor`（竖屏水面带）、`DeviceGravityMonitor`（仅邀请期间读取重力）与共享 `HostedTaskStatus`；横屏 `LandscapeAmbientDashboard` 按桌面阅读距离重建；删除返航后的文字横屏提示。
- Swift 测试：`WorkInvitationTests` 6 项，全量 271 项通过。iOS UI 测试：横屏跟随、横屏暂存草稿、离开与返航（含减少动态效果）、设计预览通过；有数据返航两项因未导入其夹具而跳过，与以往相同。离开与返航测试原先按任务名点按卡片，因此刻总览轨道同名而改为按卡片标识定位（该同名问题自上一轮总览改版即存在）。
- 模拟器截图检查：竖屏邀请水面带、横屏到达与就位、转回竖屏起锚。验证邀请画面时使用了临时的“视为 Mac 已连接”启动开关与临时截图测试，均已删除，不在提交中。
- 未做：真机上的重力摆动、横摇手感、方向锁定提示、触感强度与 landscapeLeft 实际握持；模拟器无运动传感器，只能看到无重力时的横摇与水流动画。

## 2026-10-13：锚按钮邀请与投锚成功收尾

- 按项目所有者反馈：横屏邀请改为由底部锚按钮长成摇摆的锚完成（`HarborAnchorButton`），移除侧边单独的锚与绳；水面带只保留水面。新增投锚成功收尾：小锚落入按钮、水波与一次成功触感（`AnchorSetupDraft.wasCreated` 区分成功与放弃）。邀请在有弹层时等待，投锚收尾播放后约 1.1 秒再出现。
- 修正：水流方向起初把锚底推向右侧（旋转符号相反），已在录制检查中发现并改为向左；横屏任务行与最新变化恢复按钮朗读属性（`accessibilityElement(children: .ignore)` 会去掉按钮属性）。
- 测试：全量 Swift 271 项通过；iOS UI 测试 创建并恢复正式任务、草稿保留、横屏跟随、横屏暂存草稿、离开与返航、设计预览通过。`testCreatesAndRestoresAFormalTask` 原先按任务名查找按钮，因此刻总览轨道同名（上一轮总览改版引入）而改为按卡片标识查找。
- 录屏：`Build/Previews/Landscape-20261013/anchor-button-invitation-flow.mp4` 由 UI 测试驱动真实流程录制；录制期间临时启用“视为 Mac 已连接”开关与录制测试，均已删除。手机外框转动为后期合成；模拟器无重力与触感。

## 2026-10-13：自查修正两处

- 同屏状态用词不一致：横屏任务行的运行状态读作“进行中”（`status.running`），旁边的总览计数读作“项运行中”。状态词改用 `tide.running`（运行中），新增 `StateWordingTests` 约束总览计数与状态词一致；该测试在修正前失败、修正后通过。
- 邀请在弹层后继续：“有弹层时等待”只在邀请出现时检查。邀请中点按长大的锚新建任务时，邀请会在表单后继续计时并可能悄悄用掉，投锚收尾也会落进仍是锚形的按钮。现在弹层或全屏页打开时暂停邀请（不计为放弃），关闭后按收尾顺序重新出现。
- 验证：全量 Swift 272 项通过；iOS UI 测试 6 项通过；macOS 构建通过。第二项依赖已连接的 Mac，UI 测试无法覆盖，按代码路径检查。
