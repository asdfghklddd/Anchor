# Anchor

Anchor is a native iPhone and macOS attention companion for people coordinating
several AI-assisted processes at once. It preserves the goal, live process state,
human decisions, and the context needed to return after an interruption.

## Current implementation

- Dedicated iOS and macOS production apps with the shared bundle identifier
  `com.andywang.anchor` for universal purchase.
- Dedicated iOS and macOS Demo apps with `com.andywang.anchor.demo`.
- `AnchorCore`: immutable projections, typed commands, reducers, repository
  contracts, presence inference, return summaries, and event deduplication.
- `AnchorDesign`: adaptive Candy Harbor semantic colors, accessible shared
  components, and a complete English/Simplified Chinese String Catalog.
- `AnchorDemoSupport`: persisted, resettable fixtures and raw presence scenarios.
- `AnchorIOSFeatures`: setup, portrait dashboard, landscape Ambient workspace,
  decisions, anchor notes, handoff/away/return, history, management, and settings.
- `AnchorMacFeatures`: menu bar status plus a native detail window using
  `NavigationSplitView`.
- `AnchorTransport`: Bonjour discovery, one-time-code key agreement, Keychain
  trust, authenticated event envelopes and acknowledgements, BLE RSSI proximity
  advertising/scanning, and an optional CloudKit private event store.
- `AnchorCore`: a versioned external source contract, actor-based source
  ingestion, a durable CLI inbox, deterministic event replay, and a retryable
  durable-sync coordinator.

SwiftData-backed persistence, production CloudKit container activation, Safari
adapters, and direct AI source integrations remain later phases. The MVP path
already has a crash-safe local event store, an authenticated same-network link,
an optional CloudKit event adapter, and a supported CLI contract.

## Repository map

```text
Anchor.xcodeproj
Apps/
├── AnchorIOS/             production iPhone launcher
├── AnchorIOSDemo/         iPhone demo launcher
├── AnchorMac/             production menu bar app
├── AnchorMacDemo/         macOS demo launcher
├── AnchorIOSUITests/
├── AnchorMacUITests/
└── Shared/                app icon and accent assets
Packages/AnchorKit/
├── Sources/AnchorCore/
├── Sources/AnchorDesign/
├── Sources/AnchorDemoSupport/
├── Sources/AnchorIOSFeatures/
├── Sources/AnchorMacFeatures/
└── Sources/AnchorTransport/
Product/Prototype/         original definition, React prototype and captures
Documentation/
```

## Run and test

Requirements: Xcode 26.2 or later, iOS 26+, and macOS 26+.

Open `Anchor.xcodeproj`, then choose one of the four shared schemes:

- `Anchor iOS`
- `Anchor iOS Demo`
- `Anchor macOS`
- `Anchor macOS Demo`

Run package tests without booting a simulator:

```sh
cd Packages/AnchorKit
swift test
```

GitHub Actions builds all four Release schemes, runs the package tests, archives
both production apps, and rejects Demo resources or copy in either archive. The
local acceptance matrix and remaining device-only checks are recorded in
[`Documentation/VALIDATION.md`](Documentation/VALIDATION.md).

The Demo apps persist user actions under Application Support. Their developer
controls can switch scenarios or restore the versioned baseline.

## Production data boundary

Production app targets do not link `AnchorDemoSupport` and have no fallback path
to fixtures. To remove all demo infrastructure later:

1. Delete the `Anchor iOS Demo` and `Anchor macOS Demo` targets and schemes.
2. Delete `Apps/AnchorIOSDemo`, `Apps/AnchorMacDemo`, and their UI-test fixtures.
3. Remove the `AnchorDemoSupport` product/target from `Packages/AnchorKit/Package.swift`.
4. Delete `Packages/AnchorKit/Sources/AnchorDemoSupport` and its tests.

No business view or production repository code needs to change.
