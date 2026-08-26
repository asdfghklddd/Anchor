# Anchor CLI event contract

The production macOS app consumes one `ExternalProcessEvent` JSON document per
file from the shared application-group inbox:

`~/Library/Group Containers/group.com.andywang.anchor/Anchor/Inbox/`

The production macOS app embeds a separately signed `anchor` executable in
`Contents/Helpers`. The Sources screen lets the user copy it to an explicitly
selected shell `PATH` location; the sandbox never edits shell profiles or
system directories on launch. A security-scoped bookmark is retained only to
report whether that selected installation still exists.

The same executable is also built from `Packages/AnchorKit` for protocol
development:

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

## Generic shell command lifecycle

The CLI also accepts session-independent command signals. The production Mac
companion binds these signals to the active Anchor session when it consumes the
shared inbox file:

```bash
COMMAND_ID="$(anchor command start \
  --name xcodebuild \
  --workspace "$PWD" \
  --terminal "${TERM_PROGRAM:-Terminal}")"

anchor command finish \
  --id "$COMMAND_ID" \
  --name xcodebuild \
  --workspace "$PWD" \
  --terminal "${TERM_PROGRAM:-Terminal}" \
  --exit-code "$?"
```

`--name` is reduced to the executable basename and `--workspace` is reduced to
the final path component before either value is written. Command arguments and
full working-directory paths are not stored.

For opt-in automatic zsh lifecycle signals, add this to `.zshrc`:

```bash
eval "$(anchor shell zsh)"
```

The generated hook skips Anchor's own commands to prevent recursion. It reports
start, finish, and exit status but does not parse terminal output or infer a
percentage. Tool-specific structured adapters can add progress later without
changing this generic lifecycle contract.

Signals older than the active Anchor session are moved to `.ignored` and never
attached to the new session. Signals wait in the inbox while no session exists.

The CLI source declares observation capability only. A decision can be resolved
in Anchor and synchronized to the Mac, but the CLI does not claim to execute a
source-side action until a future adapter declares `resolveDecision` support.

The CLI is an ingestion adapter, not a source-specific AI integration. An AI or
creative tool only needs to produce this contract; direct integrations can be
added later without changing the session reducer or transport layer.
