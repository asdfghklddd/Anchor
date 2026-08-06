# Anchor CLI event contract

The production macOS app consumes one `ExternalProcessEvent` JSON document per
file from the shared application-group inbox:

`~/Library/Group Containers/group.com.andywang.anchor/Anchor/Inbox/`

The `anchor` executable is built from `Packages/AnchorKit`:

```sh
cd Packages/AnchorKit
swift run anchor schema > /tmp/anchor-event.json
swift run anchor emit --file /tmp/anchor-event.json
```

Scripts can also pipe a sanitized event directly:

```sh
cat event.json | swift run anchor emit --inbox "$ANCHOR_INBOX"
```

The event must contain a stable `id`, `sessionID`, `sourceID`, monotonic
source `sequence`, a complete current process snapshot, and an optional
meaningful process event or decision. Dates use ISO-8601 strings. Progress is
optional; when present it must be between `0` and `1`. The source must never
send raw prompts, documents, tokens, or generated assets unless the user has
explicitly chosen to attach them.

Files are written through a temporary name and renamed atomically. Anchor moves
accepted files to `.processed` and malformed/oversized files to `.failed`, so a
crash or retry cannot silently remove the source input. A malformed file is
quarantined without stopping later valid files. If the Mac has not created an
Anchor session yet, a valid event is returned to the inbox and the source waits
until a session exists instead of consuming the event in a retry loop.

The CLI source declares observation capability only. A decision can be resolved
in Anchor and synchronized to the Mac, but the CLI does not claim to execute a
source-side action until a future adapter declares `resolveDecision` support.

The CLI is an ingestion adapter, not a source-specific AI integration. An AI or
creative tool only needs to produce this contract; direct integrations can be
added later without changing the session reducer or transport layer.
