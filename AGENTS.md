# Native Mac build and test workflow

## Project UI/UX skill

- For Anchor UI, UX, and motion reviews, read
  `.agents/skills/emil-design-eng/SKILL.md` and `DESIGN.md` first.
  This skill is installed only in this project; provenance and the upstream
  license are stored beside its manifest.
- Apply its interaction and motion principles to native SwiftUI. Web-specific
  CSS, React, and browser prescriptions are not native implementation requirements.
- Preserve user-confirmed layouts and semantics in `DESIGN.md`. Identify any
  proposal that touches those decisions, and distinguish source-confirmed issues
  from hypotheses that need live interaction testing. A review request alone does
  not authorize changing the app UI.
- Treat Part I of `DESIGN.md` as frozen: change it only when the project owner
  explicitly requests a philosophy amendment. Maintain current implementation
  evidence in Part II and derived requirements in Part III; never report a target
  requirement as implemented without evidence.

## Build and test

- Building does not authorize leaving new GUI app instances running. Use build-only
  checks unless the task requires a running app.
- Before launching Anchor on the user's Mac, inspect existing Anchor processes.
  Track every test instance by PID and terminate it on success, failure, interruption,
  and timeout. Do not repeatedly use `open -n` without owning the resulting process.
- For UI tests, set `ANCHOR_UI_TESTING=1`. For local end-to-end validation, set a
  unique `ANCHOR_LOCAL_VALIDATION_ROOT`. These launch modes use in-memory pairing
  credentials and must not access production Keychain items.
- Background pairing reads and writes must use `NoninteractiveKeychain`. Do not
  enable Keychain authentication UI to make an unattended test pass, automate
  password/Always Allow dialogs, or alter the user's Keychain ACLs.
- Production pairing must use the Data Protection keychain and stable signing
  entitlements. Do not silently fall back to legacy storage when signing or
  entitlement checks fail. For persistent real-device development, use
  `Configuration/AnchorMac-Development.xcconfig`; unsigned builds verify compilation
  only and must not be reported as distribution-permission acceptance.
- Never delete production pairing credentials as test cleanup. Use disposable
  test services or temporary keychains, and clean up only resources the test owns.
