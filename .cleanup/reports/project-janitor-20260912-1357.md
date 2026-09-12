# Project Janitor Report

## Run metadata

- Target path: `/Users/andywang/worktrees/Anchor-archive-semifinal-demo`
- Mode: organize
- Permission level: confirm-risky, explicitly approved by the owner on 2026-09-12
- Git repository: yes
- Branch: `codex/archive-semifinal-demo`
- Working tree before: clean at `f1a214057284ccb5d0d9c9435d5816bd94aec6be`
- Detected stack: Swift 6.2, Swift Package Manager, Xcode iOS/macOS project, GitHub Actions
- Timestamp: 2026-09-12 13:57 CST

## Baseline verification

| Check | Result | Notes |
| --- | --- | --- |
| `git rev-list --left-right --count HEAD...origin/main` | Pass: `0 0` | Migration starts from current GitHub `main`. |
| Open pull requests | Pass: none | No teammate PR needs integration first. |
| Native CI run `34673330944` | Pass: 7/7 | Package tests, four Release builds, and two production archive boundaries passed at the baseline commit. |
| `xcodebuild -list -json -project Anchor.xcodeproj` | Pass | Confirms two production apps, two Demo apps, and two Demo-bound UI-test targets. |

## Structure inventory

| Path | Classification | Notes |
| --- | --- | --- |
| `Apps/AnchorIOS`, `Apps/AnchorMac` | active-source | Formal applications; do not move. |
| `Apps/AnchorSafariExtension` | active-source | Formal Safari integration; do not move. |
| `Packages/AnchorKit` excluding Demo support | active-source/tests | Formal domain, UI, observation, and transport code. |
| `Apps/AnchorIOSDemo`, `Apps/AnchorMacDemo` | experiments/archive | Semifinal fixture launchers. |
| `Apps/AnchorIOSUITests`, `Apps/AnchorMacUITests` | tests/archive | Bound specifically to the Demo targets. |
| `Packages/AnchorKit/Sources/AnchorDemoSupport` | experiments/archive | Fixture repository and Demo controls; formal targets do not link it. |
| `Packages/AnchorKit/Tests/AnchorDemoSupportTests` | tests/archive | Tests only the archived fixture layer. |
| `Configuration/AnchorIOSDemo-Info.plist` | config/archive | Demo-only application configuration. |
| `Apps/Shared` | assets | Shared by formal apps; keep canonical copy and snapshot a copy for the archive. |

## Cleanup candidates

| Path | Category | Evidence | Confidence | Planned action | Reason | Risk |
| --- | --- | --- | --- | --- | --- | --- |
| Demo app targets and schemes | Build surface | E3 | High | Move to a separate archived Xcode project | They must no longer appear in the production project. | Xcode graph must remain valid. |
| Demo launchers and Demo-bound UI tests | Archived implementation | E2 | High | Move | All references resolve to Demo targets. | Archived project must compile before removal is accepted. |
| `AnchorDemoSupport` product, target, source, and tests | Package surface | E3 | High | Extract into an archived local package | Formal products have no dependency on it. | Relative package dependencies must be verified. |
| Demo jobs in `native-ci.yml` | CI surface | E3 | High | Remove from production CI | Production CI should validate the formal product only. | Preserve production archive boundary checks. |

## Actions allowed in this run

- Freeze and push the baseline tag `competition-semifinal-demo-2026-09-12`.
- Create `Archive/Competition/SemifinalDemo/AnchorSemifinalDemo.xcodeproj`.
- Move Demo-only implementation and tests into that archive.
- Remove Demo targets, schemes, and DemoSupport from the formal project/package.
- Update production CI and durable repository documentation.
- Commit, push a migration branch, create a PR, wait for CI, and merge only after verification.

## Actions deferred for human review

- Replacing the archived fixture UI tests with new formal end-to-end UI tests is a separate product-test milestone.
- Deleting the archive or creating a separate GitHub repository is not authorized.

## Actions taken

- Pushed annotated tag `competition-semifinal-demo-2026-09-12`; its peeled
  commit is the verified baseline `f1a214057284ccb5d0d9c9435d5816bd94aec6be`.
- Created a self-contained 33-file, 2,030,514-byte source archive at
  `Archive/Competition/SemifinalDemo`, including a snapshot of shared assets.
- Extracted fixture support into the archive-local `AnchorDemoSupport` package.
- Removed both Demo apps, both Demo-bound UI-test targets, their schemes, and
  DemoSupport from the formal Xcode project and root package.
- Split production and archived verification into `native-ci.yml` and the
  path-scoped/manual `archived-demo-ci.yml` workflows.
- Updated current structure, validation, web, CloudKit, and implementation-plan
  documentation without rewriting historical evidence records.

## Files explicitly not touched

- Formal app source behavior, product data, CloudKit state, signing secrets, VPN/proxy configuration, and the dirty Desktop checkout.
- `Packages/AnchorKit/Sources/AnchorCore/MacWorkspaceProcessSource.swift` keeps the legacy Demo bundle exclusion so an installed archived Demo cannot be observed as user work.

## Verification plan

1. Build both schemes in the archived Demo project.
2. Run archived DemoSupport tests.
3. Confirm the formal project lists no Demo target, scheme, UI-test target, or DemoSupport product.
4. Run formal package tests and both production Release builds and archives.
5. Confirm production archives contain no Demo fixture/copy.
6. Push a PR, require the revised Native CI to pass, then merge and verify `main` synchronization.

## Local verification after organization

| Check | Result | Evidence |
| --- | --- | --- |
| Formal Xcode graph | Pass | Only `Anchor iOS`, `Anchor macOS`, `AnchorCommand`, and `AnchorSafariExtension` targets remain. |
| Formal package | Pass | 115 tests in 12 suites. |
| Archived fixture package | Pass | 12 tests in 1 suite. |
| Formal Release builds | Pass | iOS Simulator and macOS arm64 builds succeeded with signing disabled. |
| Archived Demo Release builds | Pass | Archived iOS Simulator and macOS arm64 schemes succeeded with signing disabled. |
| Archived Demo UI-test builds | Pass | Both fixture-bound UI-test targets succeeded with `build-for-testing`. |
| Production archives | Pass | iOS and macOS archives succeeded; both use `com.andywang.anchor`. |
| Production payload scan | Pass | No DemoSupport, fixture, Demo state, scenario copy, or archived browser adapter found. |
| macOS embedded products | Pass | `anchor` helper and Safari Web Extension are present and structurally valid. |
| Project/plist/YAML syntax | Pass | Both project files, the archived plist, and both workflows parsed successfully. |
| Patch hygiene | Pass | `git diff --check` reported no whitespace errors. |

GitHub PR, CI, merge, and final `main` synchronization are recorded after their
remote status is known; they are not predeclared as successful here.
