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
| `scripts/validation/`, `scripts/release/` | Production checks and source export |

## Documentation entry points

- [Design](../DESIGN.md): current iOS visual tokens, components, page rules, and verification boundaries.
- [README](../README.md): setup and source submission.
- [Validation](../Documentation/VALIDATION.md): latest verified results and device acceptance still needed.
- [CLI contract](../Documentation/CLI_EVENT_CONTRACT.md), [web contract](../Documentation/WEB_OBSERVATION_CONTRACT.md), [CloudKit](../Documentation/CLOUDKIT_MVP.md): integration boundaries.
- [Launch motion](../Documentation/IOS_LAUNCH_MOTION.md): iOS transition behavior.
- [Third-party notices](../Documentation/THIRD_PARTY_NOTICES.md): attribution.

## Verification

Run `swift test` from `Packages/AnchorKit`, not the repository root. Production Xcode schemes are `Anchor iOS` and `Anchor macOS`; CI commands live in `.github/workflows/native-ci.yml`.

Generated dependency and build folders are excluded from source export.
