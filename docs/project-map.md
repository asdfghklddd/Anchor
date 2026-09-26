# Anchor project map

Anchor is a native iPhone/macOS attention companion with shared event-driven state.

| Path | Role |
|---|---|
| `Apps/AnchorIOS/AnchorIOSApp.swift` | Production iPhone entry |
| `Apps/AnchorMac/AnchorMacApp.swift` | Production Mac entry |
| `Apps/AnchorSafariExtension/` | Safari integration |
| `Packages/AnchorKit/Sources/` | Core, design, iOS/macOS features, transport and CLI |
| `Packages/AnchorKit/Tests/` | Shared package tests |
| `Apps/AnchorIOSUITests/`, `Apps/AnchorMacUITests/` | Production UI tests |
| `Anchor.xcodeproj/`, `Configuration/`, `.github/workflows/` | Build, signing and CI; preserve contracts |
| `scripts/validation/`, `scripts/p0/` | MVP validation and source probes |
| `Product/Prototype/` | Original product and visual reference; preserve assets |
| `Archive/Competition/SemifinalDemo/` | Frozen separate Demo project; not redundant production code |
| `video/` | Separate local Git repository for video work; not part of this repository |

## Documentation entry points

- [README](../README.md): setup and designated development branch policy.
- [Implementation plan](../Documentation/ANCHOR_IMPLEMENTATION_PLAN.md): confirmed requirements and dated delivery ledger. Historical authorizations do not carry forward.
- [Validation](../Documentation/VALIDATION.md): dated verification evidence; not proof of subsequent builds.
- [CLI contract](../Documentation/CLI_EVENT_CONTRACT.md), [web contract](../Documentation/WEB_OBSERVATION_CONTRACT.md), [CloudKit](../Documentation/CLOUDKIT_MVP.md): integration boundaries.
- [Source capability audit](../Documentation/P0_SOURCE_CAPABILITY_AUDIT.md) and `Documentation/evidence/`: retained diagnostic evidence.
- `Documentation/archive/`: early product baseline, development sequencing and video research. Original paths are short compatibility pointers.
- `video/docs/README.md`: local video knowledge index in the separate repository.
- `.cleanup/reports/`: local cleanup reports; not product documentation.

## Verification

Run `swift test` from `Packages/AnchorKit`, not the repository root. Production Xcode schemes are `Anchor iOS` and `Anchor macOS`; CI commands live in `.github/workflows/native-ci.yml`.

Preserve pre-existing untracked video/screenshots and Git stashes. Ignore generated dependency/build folders during source cleanup. Check Git state and current task authorization before publishing changes.
