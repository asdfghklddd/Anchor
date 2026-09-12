# Anchor Semifinal Demo Archive

This directory preserves the synthetic iOS and macOS fixture applications used
for the competition semifinal. It is intentionally separate from the formal
`Anchor.xcodeproj` and is not part of production CI or release packaging.

## Frozen source of truth

The complete, known-good repository state is tagged as:

```text
competition-semifinal-demo-2026-09-12
```

If future production API changes stop this convenience archive from compiling,
check out that tag to reproduce the exact semifinal applications. Do not change
formal product behavior merely to keep this historical Demo compatible.

## Contents

- `AnchorSemifinalDemo.xcodeproj`: Demo-only iOS/macOS apps and UI-test targets.
- `Apps`: archived launchers, UI tests, and a snapshot of the shared app assets.
- `Configuration`: the archived iOS Demo property list.
- `Packages/AnchorDemoSupport`: fixture repository, controls, localization, and
  fixture-specific tests.

The archived Demo package references the formal `Packages/AnchorKit` tree so the
archive does not duplicate the production domain and UI implementation. The Git
tag above is the durable compatibility boundary.

## Build on demand

From the repository root:

```sh
xcodebuild build \
  -project Archive/Competition/SemifinalDemo/AnchorSemifinalDemo.xcodeproj \
  -scheme "Anchor iOS Demo" \
  -configuration Release \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO

xcodebuild build \
  -project Archive/Competition/SemifinalDemo/AnchorSemifinalDemo.xcodeproj \
  -scheme "Anchor macOS Demo" \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  CODE_SIGNING_ALLOWED=NO

swift test \
  --package-path Archive/Competition/SemifinalDemo/Packages/AnchorDemoSupport
```

These commands are archival verification only. New product work belongs in the
formal apps and `Packages/AnchorKit`.

The shared schemes also retain the historical iOS/macOS UI-test targets. CI
compiles those targets with `build-for-testing`; running them remains an explicit
historical acceptance action rather than a production release gate.
