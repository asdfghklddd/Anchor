# Anchor native validation record

Last updated: 2026-09-14

## Formal iOS core-loop developer acceptance

Status: **Simulator and protocol-level verification passed; physical-device pairing remains pending**.

The production iOS target now covers the local task boundary that the product
requires: create a task, persist it through relaunch, explicitly confirm its
end, remove it from the foreground, and reopen its full details from task
history after another relaunch. A first-run card links directly to Mac
connection settings. Production iOS surfaces no longer average unrelated
process percentages or synthesize an impact percentage; a percentage is shown
only when its source supplied that process value.

Verified on an iPhone 17 Pro Simulator running iOS 26.3.1:

1. Connection entry, setup required-field gating, and editable text creation.
2. Task creation, process display, app termination, and durable recovery.
3. Finish shortcut, explicit second confirmation, foreground exit, relaunch,
   task-history navigation, and detailed criteria/process recovery.

Repository integration tests cover offline iPhone creation, later flush to a
paired Mac repository, Mac-originated notes and Codex running/completed updates,
completion on iPhone, history on both replicas, and a subsequent new task without
reviving the archived one. A separate end-to-end test now writes real-format
Codex JSONL, lets the production file source and coordinator consume it, sends
the resulting events through an authenticated Network.framework Bonjour link,
queues the running event while the client is disconnected, flushes it after
reconnection, and then observes completed in the iPhone repository. This
exercises the real transport stack on one Mac; it does not replace physical
two-device testing.

Remaining physical-device checks include speech permission and dictation,
local-network and Bluetooth prompts, real Mac pairing and interruption,
CloudKit backup/deletion, background/lock-screen behavior, and provisioned
signing.

## Mac Codex MVP local acceptance

Status: **Mac ingestion and code-level iPhone synchronization passed; physical-device acceptance remains pending**.

For direct Xcode acceptance, open the production project, select the
`Anchor macOS` scheme and `My Mac`, then Run. Its Debug configuration uses
ad-hoc **Sign to Run Locally** signing and does not require an Apple developer
account or provisioning profile. Release and Archive keep the production
automatic-signing and App Group configuration.

The current Mac-side MVP can create an isolated local test task, let the owner
authorize the Codex sessions folder once, show a bounded list of recent task
candidates, explicitly attach one or more candidates to the current Anchor
task, observe lifecycle changes, recover bookmarks/checkpoints and task-scoped
associations after relaunch, and keep current work separate from archived
history. It does not retain prompt, model-response, or tool-output bodies.

From the repository root, run:

```bash
./scripts/validation/launch-mac-local-mvp.sh
```

The launcher builds the formal `Anchor macOS` target and opens it with a fresh
temporary data root. It does not launch the archived Demo project or write production
Anchor data. In the App:

1. Open **Sources**.
2. Under Codex, click **Authorize Sessions Folder**, select the Codex `sessions`
   folder, and confirm the system panel. Anchor then discovers up to 12 recent
   JSONL candidates from session identity, workspace basename, modification time,
   and lifecycle events only.
3. Click **Track** on the candidate that belongs to the current Anchor task. A
   candidate never mutates task history before this explicit association. The
   existing **Choose session** flow remains available as a single-file fallback.
4. Start and finish a Codex turn, then verify the task observation changes.
5. Quit and rerun the launcher with the printed validation directory to verify
   folder bookmark, task association, and lifecycle checkpoint recovery.
6. Use the current-task completion action and confirm that current work becomes
   empty while history remains available. A source bound to the old task must
   not update a later Anchor task.

Known local-acceptance boundaries:

- The launcher is Debug-only test scaffolding because no iPhone is currently
  available to create a real task. Release ignores these environment variables.
- The direct Xcode Debug build is ad-hoc signed and intentionally omits the host
  App Sandbox and App Group entitlement so local Codex/CLI file observation and
  Bonjour can be exercised without a provisioning profile. It does not prove
  the provisioned sandbox boundary or Safari App Group handoff.
- Claude Code, physical iPhone synchronization, Safari long-response capture,
  sleep/wake, and release distribution remain outside this local checkpoint.
- A 600-Run stress test preserves all data but raises long-running RSS. This is
  recorded as post-MVP performance work; normal medium-task acceptance should
  focus on correctness and workflow.

## Automated results

The 2026-09-14 Codex-to-iPhone MVP change passed all 26 Codex-focused tests and
all 125 package tests. The earlier three `pairingTimedOut` failures were traced
to tests browsing the same `_anchor._tcp` service as the already-running Anchor
app; transport tests now inject an isolated Bonjour service type while production
keeps `_anchor._tcp`. The metadata supervisor, privacy minimization, multi-session
tracking, task isolation, lifecycle scanner, encrypted local link, iPhone
projection, reconnect outbox, and checkpoint tests all passed. The end-to-end
Codex reconnect case also passed five consecutive repetitions. Formal `Anchor macOS` arm64 Debug
and unmodified `Anchor iOS` Debug builds also passed. The pre-existing untracked
`ProcessTaskSheet.swift` was not edited; its required `Open on Mac` shared
localization was added so the formal iOS target remains buildable. Both formal
iOS and macOS Release configurations also build with signing disabled.

- Formal `AnchorKit`: 119 Swift Testing cases in 12 suites, including source parsing,
  checkpoint acknowledgement, migration, task ownership/current-history rules,
  interruption semantics, presence, pairing, and encrypted transport.
- Archived `AnchorDemoSupport`: 12 fixture-only cases in 1 suite. These are run
  from the separate semifinal archive and are not part of the formal package.
- Formal `Anchor macOS` arm64 Debug builds with default Xcode settings using
  ad-hoc local signing; an optimized Release-validation build with signing
  disabled also succeeds.
- Formal UI automation is now part of the production project rather than the
  archived fixture project. The iPhone suite passed 3/3 real Simulator journeys:
  connection/setup gating, task creation and relaunch, plus explicit completion,
  foreground exit, and detailed history recovery. Both iPhone and Mac UI-test
  bundles compile with the formal apps.
- Real current Codex rollout capture, real system file panel/bookmark recovery,
  formal UI completion/foreground exit, restart without replay, and a 600-Run /
  1200-Event three-fault stress test have passed on this Mac.
- Production Release builds: `Anchor iOS` and `Anchor macOS` build with Swift
  6.2. The two archived semifinal Demo schemes also build independently from
  `Archive/Competition/SemifinalDemo/AnchorSemifinalDemo.xcodeproj`.
- Production archives: iOS and macOS both use `com.andywang.anchor`; archive scans
  contain no `AnchorDemoSupport`, fixture files, Demo state, controls, or scenario
  copy.
- Production CI: 115 package tests, two Release builds, two formal UI-test builds,
  both production archives, and the production/archive boundary run for `main`,
  `codex/**`, and pull requests.
  A separate path-scoped/manual workflow runs the archived package tests and two
  Demo build-for-testing jobs, including the fixture-bound UI-test targets,
  without making them part of the release surface.

## Archived semifinal Demo UI and accessibility matrix

| Device | Appearance / language / text | Result |
| --- | --- | --- |
| iPhone 16e | Light / Simplified Chinese / default | Four core UI flows passed |
| iPhone 17 Pro | Light / Simplified Chinese / default | Four core UI flows passed |
| iPhone 17 Pro | Dark / English / maximum accessibility size | Four core UI flows passed |
| iPhone 17 Pro | Increased contrast | Active, return, and landscape audits passed |
| iPhone 17 Pro Max | Dark / English / maximum accessibility size | Four core UI flows passed |

These historical fixture runs cover the active workspace, portrait decision navigation, return
summary, and landscape inline decision flow. The landscape flow additionally
asserts selected state, confirms through the shared reducer, and waits for the
resolved UI. `performAccessibilityAudit()` runs on the active, return, and
landscape core screens.

XCTest has reproducible contrast false positives when it samples anti-aliased or
partially clipped high-contrast text at a `ScrollView` edge. The test filter is
limited to four stable identifiers whose rendered ink/paper contrast was manually
verified above 12:1; all other findings fail the suite.

## Remaining device-only acceptance

- The formal macOS UI suite covers empty-work/source navigation and the explicit
  completion-confirmation/foreground-exit boundary. It compiles, but execution
  is pending because Developer Mode is disabled on this Mac; Xcode could not
  materialize its test Runner. No system security setting was changed.
- Physical-device checks remain for VoiceOver reading order, system keyboard
  dictation, haptics, rotation, local-network permission prompts, Bluetooth
  behavior, Mac sleep/recovery, and a real two-device encrypted round trip.
- SwiftData, production CloudKit, offline merge, background transfer, and
  provisioned CLI/Safari end-to-end checks remain later acceptance work. Archived
  Demo data is not evidence for any production adapter.

Simulator runs keep one device booted at a time and shut all devices down after
acceptance to control local memory pressure.
