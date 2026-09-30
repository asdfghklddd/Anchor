# Anchor

Anchor is a native iPhone and macOS attention companion for people coordinating
several AI-assisted processes at once. It preserves the goal, live process state,
human decisions, and the context needed to return after an interruption.

## Current implementation

- Dedicated iOS and macOS production apps with the shared bundle identifier
  `com.andywang.anchor` for universal purchase.
- `AnchorCore`: immutable projections, typed commands, reducers, repository
  contracts, presence inference, return summaries, and event deduplication.
- `AnchorDesign`: adaptive iOS colors from the approved Figma homepage,
  platform-aware components, and an English/Simplified Chinese String Catalog.
  See [DESIGN.md](DESIGN.md) for the current iOS visual contract.
- `AnchorIOSFeatures`: setup, portrait dashboard, landscape Ambient workspace,
  decisions, anchor notes, handoff/away/return, history, management, and settings.
- The production iPhone loop has an explicit final confirmation boundary:
  completing a task retains its detailed history across relaunches. Concurrent
  hosted tasks keep independent conversations and histories; completing one task
  preserves the others. The homepage uses the main conversation for its progress
  capsule and shows individual conversation progress in the anchor chart.
- `AnchorMacFeatures`: menu bar status plus a native detail window using
  `NavigationSplitView`.
- `AnchorTransport`: Bonjour discovery, one-time-code key agreement, Keychain
  trust, authenticated event envelopes and acknowledgements, BLE RSSI proximity
  advertising/scanning, and an optional CloudKit private event store.
- `AnchorCore`: a versioned external source contract, actor-based source
  ingestion, a durable CLI inbox, deterministic event replay, and a retryable
  durable-sync coordinator.
- Production-only macOS application lifecycle, generic CLI lifecycle, and a
  privacy-minimal Safari Web Extension embedded only in the formal macOS app.

SwiftData-backed persistence, production CloudKit container activation,
site-specific web adapters, and direct integrations remain later phases. The MVP path
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
├── AnchorSafariExtension/ production Safari Web Extension
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
automatic-signing settings. The Safari extension is bundled in Debug, but its
cross-process App Group handoff still requires a provisioned Release build.

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

## Final competition source submission

Both production launchers start without recording tasks in Debug and Release.
Task data comes from user actions, observed sources, or paired devices. The iOS
profile reports actual connection/cloud state; unavailable background notifications
are described explicitly. Session elapsed time is not a measurement of focused work.
External process status remains source-owned after recording a decision.

Upgrading a recording build backs up `session-state.json` beside the original
with a `before-recording-cleanup-<UUID>.bak` suffix before removing the three
reserved recording task identities and marked recording process events. Real
session goals and notes are retained. Upgrade both devices before reconnecting;
an older recording build can still generate synthetic presence changes. This
migration does not erase cloud records or backup files.

Create a clean source ZIP from the current working files (including uncommitted
changes):

```sh
python3 scripts/validation/check-production-data.py
python3 scripts/release/export-source.py /tmp/Anchor-source-submission.zip
```

The export includes the native project, production packages, resources, tests,
and supporting scripts/documentation. It excludes Git history, build output and
device data. Test doubles stay in `Tests`; they are not linked into the apps.

Real-device Bluetooth/Bonjour pairing, speech permissions, signed Safari App
Group handoff and provisioned CloudKit must be checked on the corresponding
hardware/account; a successful unsigned build does not validate these services.

### Reliability follow-up

Local task edits now finish after local persistence and replicate in the background.
Decision delivery uses task ownership and avoids repeated source actions. Photo
processing and file access run off the UI thread; recording cleanup is scoped to
the correct speech request. See the latest section of
[the validation record](Documentation/VALIDATION.md) for regression, native UI,
command execution and event stress-test results and remaining device checks.
