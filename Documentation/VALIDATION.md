# Anchor native validation record

Last updated: 2026-09-30

## Current results

- Shared package: **193 tests passed** (149 core, 25 transport, 19 Mac features). These cover local persistence, slow peer acknowledgements, eventual outbox delivery, decision ownership and idempotency, duplicate process IDs, source ingestion, real loopback Bonjour pairing, reconnect, and event acknowledgement. The optional test against a user-supplied live Codex rollout was skipped because `ANCHOR_REAL_CODEX_ROLLOUT` was unset.
- iPhone 18 Pro / iOS 27 Simulator: **12 full-suite UI tests passed**. After the reliability fixes, **3 targeted tests passed again** for creation and restoration, fresh launch, and speech permission/error handling with cancel and restart.
- macOS: **4 functional UI tests passed** for empty workspace, pairing entry, expanded sidebar hit testing, collapsed navigation, and the resting edge entry. This run did not repeat the separate accessibility audits.
- Final iOS and macOS **Release builds passed** with code signing disabled.
- The built CLI ran actual `true` and `false` commands. Its start and finish records were durably queued with exit codes 0 and 1.
- Native Mac lifecycle stress test: **60 runs and 120 events completed**, with file replacement at run 30, truncation at run 45, and restarts at runs 20, 40, and the end. It had no lost or duplicate records or polling timeouts. Observed peak RSS was 165,936 KiB (about 162 MiB). The input was controlled lifecycle data; this does not establish long-term memory stability under live AI use.
- The production data boundary check and `git diff --check` passed.

Local command output is stored outside the repository in `../Build/logs/real-function-validation-20260930/`.

## Reliability changes verified

- Task edits finish after the durable local save. A background worker drains the outbox, so a slow or disconnected peer does not hold setup, notes, or confirmation on screen. Failed deliveries stay queued for retry.
- Decision confirmation rejects repeat taps and stale sheets. Mac source actions use the envelope's owning task and claim a newly resolved decision once, including when reconnect replays history.
- Connection, presence, source-health, and cloud refreshes preserve actionable operation errors until dismissal or a successful user operation.
- Photo preparation and file access run off the main actor. A cancelled plan view rejects a late image load from a previous task.
- Speech audio-session cleanup belongs to its recognition request. A late callback cannot disable a newer recording's controls or deactivate its audio session.
- Repeated process IDs no longer create duplicate rows or trap snapshot, history, and source lookups.
- Native validation isolates preferences, pairing identity, cloud sync, and the source inbox, so it does not consume installed app data.

## Recording-data removal

- Ordinary Debug and Release launches create no recording tasks. The scheduled iOS return generator, visual-only microphone override, fixed profile trends, arbitrary progress bars, storyboard illustrations, and static cloud-success claims were removed.
- iOS settings state that background notifications are unavailable. Decisions retain source-owned execution status until an observed update.
- On upgrade from a recording build, the local repository backs up `session-state.json` before removing reserved recording task IDs and marked synthetic process activity. Real goals and notes remain. Tests cover backup, preservation, outbox cleanup, and restart idempotency.
- `SimulatedProcessSource` is compiled only in the core test target. UI tests use private temporary storage and do not populate ordinary launches.

## Run the checks

From the repository root:

```sh
python3 scripts/validation/check-production-data.py
cd Packages/AnchorKit && swift test
```

The `Anchor iOS` and `Anchor macOS` schemes in `Anchor.xcodeproj` include formal UI tests. GitHub Actions runs package tests, unsigned Release builds, UI-test compilation, and archive checks for the production apps. A clean source archive can be generated with `python3 scripts/release/export-source.py /tmp/Anchor-source-submission.zip`.

## Device and account acceptance still needed

Physical iPhone–Mac Bluetooth/Bonjour behavior, successful on-device speech transcription, provisioned CloudKit, signed Safari App Group handoff, and long background/sleep recovery require the corresponding devices and signing account. The simulator speech test accepts a clear recognizer-unavailable error when controls remain usable. The unsigned builds and controlled stress run do not establish those services or a zero-defect guarantee.
