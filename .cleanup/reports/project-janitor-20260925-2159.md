# Project Janitor Report

Target: `.`; safe-clean / autonomous-safe; 20260925-2159.

Git: main `8d7570424f7cb0e6de7201737df6626229ff5de5`; dirty before cleanup; fetched origin/main equal; no open PRs.

## Baseline verification
[{'command': 'cd Packages/AnchorKit && swift test', 'result': 'failed before cleanup', 'notes': 'CodeSign AnchorKit_AnchorDesign.bundle: resource fork, Finder information, or similar detritus not allowed', 'log': '/tmp/anchor-janitor-baseline.log'}]

## Structure inventory
Apps + Packages: active production and tests; Configuration + Xcode + .github: protected configuration; Documentation: contracts/plan/evidence; Product: visual authority; Archive: frozen competition app; video: untracked independent video project; ignored build/cache/tmp: excluded.

## Planned actions
| Path | Evidence | Action | Reason |
|---|---|---|---|
| Documentation/PRODUCT_BASELINE.md | E1 | archive | Historical product/design sequencing superseded by implementation plan; video research superseded by local video knowledge index. Keep tracked historical copy and compatibility pointer. |
| Documentation/DEVELOPMENT_BLUEPRINT.md | E1 | archive | Historical product/design sequencing superseded by implementation plan; video research superseded by local video knowledge index. Keep tracked historical copy and compatibility pointer. |
| Documentation/ANCHOR_PRODUCT_VIDEO_RESEARCH.md | E1 | archive | Historical product/design sequencing superseded by implementation plan; video research superseded by local video knowledge index. Keep tracked historical copy and compatibility pointer. |
| Anchor/Assets.xcassets/AppIcon.appiconset | E0 | delete | Empty leftover; not tracked and absent from project/package/CI references. |
| Anchor/Assets.xcassets/AccentColor.colorset | E0 | delete | Empty leftover; not tracked and absent from project/package/CI references. |
| Anchor/Assets.xcassets | E0 | delete | Empty leftover; not tracked and absent from project/package/CI references. |
| Anchor | E0 | delete | Empty leftover; not tracked and absent from project/package/CI references. |
| AnchorTests | E0 | delete | Empty leftover; not tracked and absent from project/package/CI references. |
| AnchorUITests | E0 | delete | Empty leftover; not tracked and absent from project/package/CI references. |
| Figma/Anchor-20-2/assets/svg | E0 | delete | Empty leftover; not tracked and absent from project/package/CI references. |
| Figma/Anchor-20-2/assets/raw | E0 | delete | Empty leftover; not tracked and absent from project/package/CI references. |
| Figma/Anchor-20-2/assets | E0 | delete | Empty leftover; not tracked and absent from project/package/CI references. |
| Figma/Anchor-20-2 | E0 | delete | Empty leftover; not tracked and absent from project/package/CI references. |
| Figma | E0 | delete | Empty leftover; not tracked and absent from project/package/CI references. |
| Packages/AnchorKit/Tests/AnchorDemoSupportTests | E0 | delete | Empty leftover; not tracked and absent from project/package/CI references. |
| .DS_Store | E0 | delete | Finder metadata |

## Knowledge hygiene inventory
| Path | Bytes | Status |
|---|---:|---|
| README.md | 5724 | updated |
| Documentation/ANCHOR_IMPLEMENTATION_PLAN.md | 85387 | updated |
| Documentation/ANCHOR_PRODUCT_VIDEO_RESEARCH.md | 32863 | updated |
| Documentation/VALIDATION.md | 10125 | assessed-no-change |
| Documentation/PRODUCT_BASELINE.md | 11299 | updated |
| Documentation/CLOUDKIT_MVP.md | 4308 | assessed-no-change |
| Documentation/P0_SOURCE_CAPABILITY_AUDIT.md | 32610 | assessed-no-change |
| Documentation/CLI_EVENT_CONTRACT.md | 3529 | assessed-no-change |
| Documentation/DEVELOPMENT_BLUEPRINT.md | 21122 | updated |
| Documentation/WEB_OBSERVATION_CONTRACT.md | 4690 | assessed-no-change |
| video/README.md | 8567 | assessed-no-change |
| video/AGENTS.md | 3709 | assessed-no-change |
| video/CLAUDE.md | 1066 | assessed-no-change |
| video/archive/README.md | 608 | assessed-no-change |
| video/references/README.md | 1340 | assessed-no-change |
| video/docs/README.md | 4018 | assessed-no-change |
| video/docs/project-map.md | 6275 | assessed-no-change |
| video/docs/research/ANCHOR_PRODUCT_VIDEO_RESEARCH.md | 35755 | assessed-no-change |
| video/docs/research/ANCHOR_REFERENCE_STYLE_ANALYSIS.md | 18109 | assessed-no-change |
| video/docs/retrospective/VIDEO_PRODUCTION_LESSONS.md | 7235 | assessed-no-change |
| video/docs/workflow/DELIVERY_QA_TOOLKIT.md | 2193 | assessed-no-change |
| video/docs/workflow/HYBRID_ASSEMBLY_PIPELINE.md | 5499 | assessed-no-change |
| video/docs/workflow/SINGLE_TRACK_CAPTIONS.md | 2867 | assessed-no-change |
| video/docs/workflow/VIDEO_PRODUCTION_WORKFLOW.md | 7815 | assessed-no-change |
| video/docs/scripts/ANCHOR_TEACHER_CUT_SCRIPT.md | 4907 | assessed-no-change |
| video/docs/scripts/ANCHOR_3M15_SCRIPT_DRAFT.md | 30484 | assessed-no-change |
| video/docs/blueprint/MEDIA_REACQUISITION_BLUEPRINT.md | 8657 | assessed-no-change |
| video/deliverables/README.md | 458 | assessed-no-change |
| video/deliverables/2026-competition/README.md | 2329 | assessed-no-change |
| video/public/screenshots/README.md | 377 | assessed-no-change |
| video/public/audio/ATTRIBUTION.md | 1403 | assessed-no-change |
| video/public/audio/README.md | 509 | assessed-no-change |
| video/public/media/README.md | 778 | assessed-no-change |
| video/public/media/anchor-ios-demo-recordings.md | 3903 | assessed-no-change |
| video/public/media/external/README.md | 2887 | assessed-no-change |
| video/public/media/competition/README.md | 929 | assessed-no-change |
| Archive/Competition/SemifinalDemo/README.md | 2129 | assessed-no-change |
| Product/README.md | 1309 | assessed-no-change |
| Product/Prototype/README.md | 5772 | assessed-no-change |
| Apps/AnchorSafariExtension/Resources/README.md | 800 | assessed-no-change |

## Actions taken
- Archived Documentation/PRODUCT_BASELINE.md -> Documentation/archive/PRODUCT_BASELINE.md; retained original-path pointer.
- Archived Documentation/DEVELOPMENT_BLUEPRINT.md -> Documentation/archive/DEVELOPMENT_BLUEPRINT.md; retained original-path pointer.
- Archived Documentation/ANCHOR_PRODUCT_VIDEO_RESEARCH.md -> Documentation/archive/ANCHOR_PRODUCT_VIDEO_RESEARCH.md; retained original-path pointer.
- Removed empty directory Anchor/Assets.xcassets/AppIcon.appiconset
- Removed empty directory Anchor/Assets.xcassets/AccentColor.colorset
- Removed empty directory Anchor/Assets.xcassets
- Removed empty directory Anchor
- Removed empty directory AnchorTests
- Removed empty directory AnchorUITests
- Removed empty directory Figma/Anchor-20-2/assets/svg
- Removed empty directory Figma/Anchor-20-2/assets/raw
- Removed empty directory Figma/Anchor-20-2/assets
- Removed empty directory Figma/Anchor-20-2
- Removed empty directory Figma
- Removed empty directory Packages/AnchorKit/Tests/AnchorDemoSupportTests
- Deleted .DS_Store (8196 bytes).
- Replaced stale current push authorization with explicitly task-scoped historical record.
- Added concise docs/project-map.md and README entry link.

## Needs review / explicitly preserved
- Production implementation pruning requires passing baseline and symbol/call-site proof; no production code deletion approved by this evidence.
- README mainline policy retained despite checkout being main; changing designated branch is a separate decision.
- Ignored build/.build/node_modules/tmp caches excluded; no space reclamation claim.
- Video subtree, screenshot evidence, prototype assets, frozen semifinal project, signing/CI/manifests, stashes and branches preserved.

## Verification after
- PASS: git diff --check.
- PASS: local Markdown links in README, project map, archived documents and compatibility pointers resolve.
- PASS: all 3 archive copies preserve original text except required relative link adjustments.
- PASS: production code, tests, project, configuration, CI, scripts, prototype and Demo archive have no tracked changes.
- Baseline swift test failed before cleanup due to resource-fork/Finder-metadata signing error; not rerun for documentation-only changes. Native app behavior/builds remain unverified.

## Verification plan
Check tracked diff whitespace, archive links and unchanged production tree. Baseline failed before edits; do not represent either native app as tested by this cleanup.
