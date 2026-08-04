# Anchor native validation record

Last updated: 2026-08-05

## Automated results

- `AnchorKit`: 12 Swift Testing cases across session reduction, presence timing,
  Demo persistence/reset, event idempotency, pairing key agreement, and encrypted
  payload round trips.
- Release builds: `Anchor iOS`, `Anchor iOS Demo`, `Anchor macOS`, and
  `Anchor macOS Demo` all build with Swift 6.2 and no Swift concurrency warnings.
- Production archives: iOS and macOS both use `com.andywang.anchor`; archive scans
  contain no `AnchorDemoSupport`, fixture files, Demo state, controls, or scenario
  copy.
- CI: package tests, the four Release builds, both production archives, and the
  production/Demo boundary run for `main`, `codex/**`, and pull requests.

## iPhone UI and accessibility matrix

| Device | Appearance / language / text | Result |
| --- | --- | --- |
| iPhone 16e | Light / Simplified Chinese / default | Four core UI flows passed |
| iPhone 17 Pro | Light / Simplified Chinese / default | Four core UI flows passed |
| iPhone 17 Pro | Dark / English / maximum accessibility size | Four core UI flows passed |
| iPhone 17 Pro | Increased contrast | Active, return, and landscape audits passed |
| iPhone 17 Pro Max | Dark / English / maximum accessibility size | Four core UI flows passed |

Each matrix run covers the active workspace, portrait decision navigation, return
summary, and landscape inline decision flow. The landscape flow additionally
asserts selected state, confirms through the shared reducer, and waits for the
resolved UI. `performAccessibilityAudit()` runs on the active, return, and
landscape core screens.

XCTest has reproducible contrast false positives when it samples anti-aliased or
partially clipped high-contrast text at a `ScrollView` edge. The test filter is
limited to four stable identifiers whose rendered ink/paper contrast was manually
verified above 12:1; all other findings fail the suite.

## Remaining device-only acceptance

- The macOS UI test target builds for testing, but this Mac has Developer Mode
  disabled, so the runner cannot launch until the owner enables it intentionally.
- Physical-device checks remain for VoiceOver reading order, system keyboard
  dictation, haptics, rotation, local-network permission prompts, Bluetooth
  behavior, Mac sleep/recovery, and a real two-device encrypted round trip.
- SwiftData, CloudKit, offline merge, background transfer, CLI/Safari, and real AI
  source adapters are later phases by design and are not represented by Demo data.

Simulator runs keep one device booted at a time and shut all devices down after
acceptance to control local memory pressure.
