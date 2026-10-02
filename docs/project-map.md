# Anchor project map

Anchor is a native iPhone/macOS attention companion with shared event-driven state.
The Mac observes supported AI/terminal tasks and sends their state to the phone.
Generic app/browser tracking and decision execution have been retired.

| Path | Role |
|---|---|
| `Apps/AnchorIOS/AnchorIOSApp.swift` | Production iPhone entry |
| `Apps/AnchorMac/AnchorMacApp.swift` | Production Mac entry |
| `Packages/AnchorKit/Sources/` | Core, design, iOS/macOS features, transport and CLI |
| `Packages/AnchorKit/Tests/` | Shared package tests |
| `Apps/AnchorIOSUITests/`, `Apps/AnchorMacUITests/` | Production UI tests |
| `Anchor.xcodeproj/`, `Configuration/`, `.github/workflows/` | Build, signing and CI; preserve contracts |
| `scripts/validation/`, `scripts/release/` | Production checks and source export |

## Documentation entry points

- [Design](../DESIGN.md): current iOS visual tokens, components, page rules, and verification boundaries.
- [README](../README.md): setup and source submission.
- [Validation](../Documentation/VALIDATION.md): latest verified results and device acceptance still needed.
- [CLI contract](../Documentation/CLI_EVENT_CONTRACT.md): active terminal integration.
- [CloudKit](../Documentation/CLOUDKIT_MVP.md): optional cloud configuration and acceptance still needed.
- [Retired web contract](../Documentation/WEB_OBSERVATION_CONTRACT.md): historical data compatibility; no browser adapter ships.
- [Launch motion](../Documentation/IOS_LAUNCH_MOTION.md): iOS transition behavior.
- [Third-party notices](../Documentation/THIRD_PARTY_NOTICES.md): attribution.

## Verification

Run `swift test` from `Packages/AnchorKit`, not the repository root. Production Xcode schemes are `Anchor iOS` and `Anchor macOS`; CI commands live in `.github/workflows/native-ci.yml`.

Generated dependency and build folders are excluded from source export.
