# Project Janitor — code cleanup

Target: .; safe-clean / autonomous-safe; dirty main. Remote main equals HEAD; no open PRs.

## Baseline

Isolated scratch build passed all 147 package tests (Core 123, Transport 21, Mac features 3). Default cache failed codesign due to FinderInfo on generated bundle.

## Planned action table

| Path | Evidence | Action | Reason |
|---|---|---|---|
| Packages/AnchorKit/Sources/AnchorCore/Repository.swift | E2 | delete private unused wrapper | Only declaration exists across tracked Swift and full repository search; four active callers directly invoke private static replay; no dynamic dispatch or selector attributes; wrapper has no side effects beyond forwarding. |
| Packages/AnchorKit/.build/out/Products/Debug/AnchorKit_AnchorDesign.bundle | E0 | remove only com.apple.FinderInfo xattr | codesign rejects Finder metadata on generated bundle; isolated scratch build passes |

## Preserved / deferred

- All previous cleanup changes and untracked video/screenshots
- Public APIs, active SwiftUI views and accessibility behavior
- Signing config, source resource xattrs, caches other than the named generated bundle attribute
- CI, manifests, tests, prototypes, frozen Demo, Git branches and stashes
- Public unused symbols: CodexLifecycleScanner, AnchorNotification, HarborClayAvatar, HarborWaveDivider. Retain public API compatibility.

## Verification plan

Run default swift test after targeted cache metadata repair. Remove private wrapper and rerun package tests. Check Git diff and references.

## Completed

- Removed 11-line private unused replayPreservingSignals wrapper; four existing call sites continue to use static replay directly.
- Attempted removal of only FinderInfo on generated AnchorDesign bundle; attribute reappeared and default swift test still failed. No source or global metadata changes.
- Documented isolated scratch build command in README; verified with scratch path /tmp/anchor-janitor-swift-20260925.

## Verification

- Before and after: all 147 tests pass in isolated scratch directory (Core 123, Transport 21, Mac features 3).
- `git diff --check` passed.
- No byte-identical tracked production source/script duplicates.
- Public candidates were retained, not treated as dead code solely from search counts.

## Limits

- Default Desktop .build remains affected by regenerating FinderInfo; isolated scratch path is a verified workaround, not a system-level repair.
- No iPhone simulator/device UI validation or complete Xcode app build performed; no UI code changed.
