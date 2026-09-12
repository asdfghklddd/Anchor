# Anchor native validation record

Last updated: 2026-09-12

## Mac Codex MVP local acceptance

Status: **developer verification passed; ready for owner testing without an iPhone**.

The current Mac-side MVP can create an isolated local test task, let the owner
confirm one Codex JSONL in the system file panel, observe lifecycle changes,
recover its bookmark/checkpoint after relaunch, and keep current work separate
from archived history. It does not read prompt or model-response bodies.

From the repository root, run:

```bash
./scripts/validation/launch-mac-local-mvp.sh
```

The launcher builds the formal `Anchor macOS` target and opens it with a fresh
temporary data root. It does not launch the archived Demo project or write production
Anchor data. In the App:

1. Open **Sources**.
2. Under Codex, click **Choose session**. Anchor locates the directory that
   contains the newest JSONL by filesystem modification time and shows its
   filename in the panel message without reading the file contents.
3. Select that filename and click **Open**. The public `NSOpenPanel` API does not
   reliably preselect an existing file, so these two system-panel actions remain
   the authorization boundary.
4. Start and finish a Codex turn, then verify the task observation changes.
5. Quit and rerun the launcher with the printed validation directory to verify
   bookmark/checkpoint recovery without selecting the file again.
6. Use the current-task completion action and confirm that current work becomes
   empty while history remains available.

Known local-acceptance boundaries:

- The launcher is Debug-only test scaffolding because no iPhone is currently
  available to create a real task. Release ignores these environment variables.
- The local build is unsigned and does not prove provisioned App Sandbox
  behavior. A developer account is not required for this isolated test.
- Claude Code, iPhone synchronization, Safari long-response capture, sleep/wake,
  and release distribution are outside this Mac Codex MVP checkpoint.
- A 600-Run stress test preserves all data but raises long-running RSS. This is
  recorded as post-MVP performance work; normal medium-task acceptance should
  focus on correctness and workflow.

## Automated results

- Formal `AnchorKit`: 115 Swift Testing cases in 12 suites, including source parsing,
  checkpoint acknowledgement, migration, task ownership/current-history rules,
  interruption semantics, presence, pairing, and encrypted transport.
- Archived `AnchorDemoSupport`: 12 fixture-only cases in 1 suite. These are run
  from the separate semifinal archive and are not part of the formal package.
- Formal `Anchor macOS` arm64 Debug builds with signing disabled; an optimized
  Release-validation build using only the Debug isolation gate also succeeds.
- Real current Codex rollout capture, real system file panel/bookmark recovery,
  formal UI completion/foreground exit, restart without replay, and a 600-Run /
  1200-Event three-fault stress test have passed on this Mac.
- Production Release builds: `Anchor iOS` and `Anchor macOS` build with Swift
  6.2. The two archived semifinal Demo schemes also build independently from
  `Archive/Competition/SemifinalDemo/AnchorSemifinalDemo.xcodeproj`.
- Production archives: iOS and macOS both use `com.andywang.anchor`; archive scans
  contain no `AnchorDemoSupport`, fixture files, Demo state, controls, or scenario
  copy.
- Production CI: 115 package tests, two Release builds, both production archives,
  and the production/archive boundary run for `main`, `codex/**`, and pull requests.
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

- Existing iOS/macOS UI-test targets are archived with the semifinal Demo because
  they launch fixture apps. Formal production end-to-end UI targets remain a
  separate milestone and are not implied by the historical matrix above.
- Physical-device checks remain for VoiceOver reading order, system keyboard
  dictation, haptics, rotation, local-network permission prompts, Bluetooth
  behavior, Mac sleep/recovery, and a real two-device encrypted round trip.
- SwiftData, production CloudKit, offline merge, background transfer, and
  provisioned CLI/Safari end-to-end checks remain later acceptance work. Archived
  Demo data is not evidence for any production adapter.

Simulator runs keep one device booted at a time and shut all devices down after
acceptance to control local memory pressure.
