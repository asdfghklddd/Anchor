# Retired web observation contract

Retired from the production flow and removed from the build on 2026-10-02.

## Current boundary

Anchor observes Codex task lifecycle and supported terminal commands. Generic
browser activity does not establish an AI task's progress, and is outside the
current product scope. The app no longer includes:

- the Safari extension, its Xcode target or embedded `.appex`;
- the Safari settings client or native message handler;
- `WebProcessSource`, `WebProcessSignal` or WebInbox polling;
- the general Mac application observer.

The Mac App Group entitlement remains for the active CLI inbox. Removing the web
adapter does not authorize deleting that entitlement or users' existing data.

## Stored-data compatibility

`BuiltInProcessSourceID.web` and `.macWorkspace` retain their original UUIDs.
Existing `AnchorProcess`, `ExternalProcessEvent`, `SessionOperation` and decision
records remain decodable for local history and peer replay. `TaskDashboardPolicy`
filters retired sources and decision records from the active dashboard and return
summary, and rejects decision commands in production.

Raw `anchor.web.activity.v1` producer signals are no longer accepted by the CLI
inbox. This differs from reading previously persisted Anchor events, whose shared
schema is preserved. The cleanup does not erase a user's old WebInbox files or
rewrite the user's event store.

## Historical implementation

The former adapter exchanged hostname-only tab activity through a sandboxed
Safari extension and App Group WebInbox. It did not provide semantic AI progress.
Its complete implementation and schema are preserved in the
[pre-cleanup source commit](https://github.com/asdfghklddd/Anchor/tree/682a382/Apps/AnchorSafariExtension).
This is historical reference, not setup guidance for the current app.

CI now verifies that the macOS archive contains the CLI helper and does not embed
the retired Safari extension. Future AI integrations require an explicit task
lifecycle contract; restoring generic browser tracking is not part of that work.
