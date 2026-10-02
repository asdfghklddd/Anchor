# Anchor

Anchor observes AI task and terminal command state on the Mac and synchronizes it
to an iPhone work dashboard. The Mac is an observation companion; it does not
answer questions, make decisions, or resume external tools on the user’s behalf.

## Current implementation

- Dedicated iOS and macOS production apps with the shared bundle identifier
  `com.andywang.anchor` for universal purchase.
- `AnchorCore`: immutable projections, typed commands, reducers, repository
  contracts, presence inference, return summaries, and event deduplication.
- `AnchorDesign`: adaptive iOS colors from the approved Figma homepage,
  platform-aware components, and an English/Simplified Chinese String Catalog.
  See [DESIGN.md](DESIGN.md) for the frozen design philosophy, current iOS/macOS
  experience, and detailed design requirements.
- `AnchorIOSFeatures`: setup, portrait dashboard, landscape Ambient workspace,
  anchor notes, handoff/away/return, history, management, and settings.
- The production iPhone loop has an explicit final confirmation boundary:
  completing a task retains its detailed history across relaunches. Concurrent
  hosted tasks keep independent conversations and histories; completing one task
  preserves the others. The homepage uses the main conversation for its progress
  capsule and shows individual conversation progress in the anchor chart.
- `AnchorMacFeatures`: menu bar status plus a native detail window using
  `NavigationStack` and an expandable sidebar.
- `AnchorTransport`: Bonjour discovery, one-time-code key agreement, Keychain
  trust, authenticated event envelopes and acknowledgements, BLE RSSI proximity
  advertising/scanning, and an optional CloudKit private event store.
- `AnchorCore`: a versioned external source contract, actor-based source
  ingestion, a durable CLI inbox, deterministic event replay, and a retryable
  durable-sync coordinator.
- Production observation uses Codex conversation lifecycle and generic CLI command
  lifecycle. General Mac application observation, the Safari extension and its
  inbox adapter have been removed. Legacy stored events remain readable; the
  current dashboard filters retired sources and decision records.
- Codex tasks written to local session logs are supported, including the installed
  app branded ChatGPT with bundle ID `com.openai.codex`. Ordinary ChatGPT chats
  and other AI tools without this log contract need dedicated adapters. An open
  application is never treated as evidence of a running AI task.

SwiftData-backed persistence, production CloudKit container activation, and
additional AI task adapters remain later phases. Generic application/browser
activity tracking and decision execution are outside the product scope. The MVP path
already has a crash-safe local event store, an authenticated same-network link,
an optional CloudKit event adapter, and a supported CLI contract.

## Repository map

See [the project map](docs/project-map.md) for source and documentation entry points.

```text
Anchor.xcodeproj
Apps/
├── AnchorIOS/             production iPhone launcher
├── AnchorMac/             production menu bar app
├── AnchorIOSUITests/      isolated production iPhone journeys
├── AnchorMacUITests/      isolated production Mac journeys
└── Shared/                app icon and accent assets
Packages/AnchorKit/
├── Sources/AnchorCore/
├── Sources/AnchorDesign/
├── Sources/AnchorIOSFeatures/
├── Sources/AnchorMacFeatures/
└── Sources/AnchorTransport/
Documentation/
```

## Run and test

Requirements: Xcode 26.2 or later, iOS 26+, and macOS 26+.

Open `Anchor.xcodeproj`, then choose one of the two production app schemes:

- `Anchor iOS`
- `Anchor macOS`

The `Anchor macOS` scheme uses ad-hoc **Sign to Run Locally** signing for its
Debug run and test actions, so a developer account is not required for local
owner acceptance. Release and Archive retain the production App Group and
automatic-signing settings. The App Group remains necessary for the supported
CLI inbox; there is no bundled Safari extension.

Background pairing Keychain operations never request authentication UI. The
legacy macOS keychain also has user interaction disabled within the Anchor
process. Peer credentials and unavailable lookups are cached for that process;
the public device identifier is migrated to UserDefaults without overwriting a
protected legacy item. Production pairing defaults to the Data Protection
keychain, using the app's signing entitlements instead of legacy per-item ACL
authorization. Readable legacy peer keys migrate without deleting the original
items; inaccessible legacy keys require fresh device pairing without a password
dialog. Signing/entitlement failures do not fall back to legacy storage.
Debug UI tests and `ANCHOR_LOCAL_VALIDATION_ROOT` launches use in-memory credentials.

For real-device development that must retain pairing across rebuilds, use a
stable Apple Development signing identity and the optional development config:

```sh
xcodebuild -project Anchor.xcodeproj -scheme 'Anchor macOS' \
  -configuration Debug \
  -xcconfig Configuration/AnchorMac-Development.xcconfig \
  ANCHOR_SIGNING_DEVELOPMENT_TEAM=YOUR_TEAM_ID build
```

This selects Data Protection Keychain storage and its access-group entitlement,
without enabling CloudKit or App Group capabilities. Xcode may need one-time
developer-certificate setup; this is separate from app-user permissions.
Ordinary ad-hoc Debug builds retain noninteractive legacy compatibility. They
can lose access to previously authorized peer keys after recompilation and are
not a substitute for signed real-device or distribution acceptance.
Build-only CI can set `CODE_SIGNING_ALLOWED=NO`; unsigned Release products are
compile checks and cannot validate production Keychain access.

Run package tests without booting a simulator:

```sh
cd Packages/AnchorKit
swift test
```

If a Desktop/File Provider build cache fails code signing with `resource fork,
Finder information, or similar detritus not allowed`, keep generated products
outside that folder. From `Packages/AnchorKit`, run:

```sh
swift test --scratch-path /tmp/anchor-swift-build
```

This changes only the build location; signing settings and source resources stay intact.

The `Anchor iOS` and `Anchor macOS` schemes also contain the formal UI-test
targets. Their launch environments create a private temporary repository and
disable live CloudKit, proximity, Bonjour, and source observation, so the tests
do not mutate the installed app's task data or source permissions.

GitHub Actions builds both production Release schemes, runs the package tests,
compiles both formal UI-test bundles, archives both apps, and checks that Demo
resources are absent. The local acceptance record and remaining device checks are in
[`Documentation/VALIDATION.md`](Documentation/VALIDATION.md).

## Public repository boundary

Production targets and the formal `AnchorKit` package use real local task data.
Test fixtures live under `Tests` and are not linked into the apps. No credentials,
CloudKit secrets, or signing material are stored in this repository.

The source is published for portfolio review. No redistribution or commercial-use
license is granted.

## Source export and competition history

Both production launchers start without recording tasks in Debug and Release.
Task data comes from user actions, observed sources, or paired devices. The iOS
profile reports actual connection/cloud state; unavailable background notifications
are described explicitly. Session elapsed time is not a measurement of focused work.
External process status remains source-owned. Production apps do not offer
decision confirmation or dispatch source actions.

Upgrading a recording build backs up `session-state.json` beside the original
with a `before-recording-cleanup-<UUID>.bak` suffix before removing the three
reserved recording task identities and marked recording process events. Real
session goals and notes are retained. Upgrade both devices before reconnecting;
an older recording build can still generate synthetic presence changes. This
migration does not erase cloud records or backup files.

The competition submission record is retained locally under
`../Build/Submission-final-20261002/`. It identifies the original submitted flat
source package, which differs from today's source tree. The old ZIP and unpacked
verification copies were removed during the user-approved local cleanup; the
submission record and its hashes remain unchanged. A current export does not
replace that historical record.

Create a clean source ZIP from the current working files (including uncommitted
changes):

```sh
python3 scripts/validation/check-production-data.py
python3 scripts/release/export-source.py /tmp/Anchor-source-submission.zip
```

The export includes the native project, production packages, resources, tests,
and supporting scripts/documentation. It excludes Git history, build output and
device data. Test doubles stay in `Tests`; they are not linked into the apps.

Real-device Bluetooth/Bonjour pairing, speech permissions, signed CLI App Group
handoff and provisioned CloudKit must be checked on the corresponding
hardware/account; a successful unsigned build does not validate these services.

### Reliability follow-up

Local task edits now finish after local persistence and replicate in the background.
Codex/CLI observations retain their task ownership; the production dashboard
rejects decision commands and has no decision UI or notification sender. Photo
processing and file access run off the UI thread; recording cleanup is scoped to
the correct speech request. See the latest section of
[the validation record](Documentation/VALIDATION.md) for regression, native UI,
command execution and event stress-test results and remaining device checks.
