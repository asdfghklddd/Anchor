# Anchor product baseline

Status: baseline draft derived from the supplied product definition and current
high-fidelity prototype on 2026-08-04.

## Product thesis

Anchor is an attention and context companion for people running several
AI-assisted processes at the same time. It does not replace Claude, ChatGPT,
Gemini, creative tools, terminals, editors, or project managers. It preserves
the information most likely to disappear while a person switches between them:

1. Why the work began and what “done” means.
2. What every active process is doing now.
3. Which result needs a human judgment next.
4. What changed while the person was away.
5. Where to resume without reconstructing the whole mental model.

The first audience is knowledge workers, independent builders, creators, and
researchers who keep several long-running AI or computer tasks active at once.

## Core promise

> Leave the desk without losing the work, then return to the right decision.

Anchor succeeds when it reduces monitoring and context reconstruction. It
fails if it becomes another noisy task list, a surveillance tool, or a feed that
demands more attention than the work itself.

## Product principles

- **The goal is the anchor.** Every process and event remains attached to one
  explicit outcome and completion criterion.
- **Human judgment is scarce.** The interface emphasizes decisions, failures,
  and meaningful completion, not every background event.
- **State is observed, not invented.** A source identifies what it knows and
  when it last observed it. Anchor must show stale or unknown data honestly.
- **Leaving is a transition, not a command.** The system may infer presence,
  but the user must always be able to understand and override that inference.
- **Return is a product moment.** The return view explains the delta, the most
  important blocker, and the recommended resume order before showing detail.
- **Local-first and explicit.** Raw work content stays on the user’s devices by
  default. Every connected source has a visible scope and revocable permission.
- **One domain model, several presentations.** Portrait, landscape, widgets,
  Live Activities, Mac UI, and return summaries project the same underlying state.

## Product vocabulary

- **Anchor session:** one bounded work period with a goal and completion criteria.
- **Process:** a unit of work observed from a manual entry, app integration,
  browser extension, CLI, or another explicit source.
- **Process event:** an immutable observation such as progress, completion,
  failure, output ready, or decision required.
- **Decision request:** a process event that needs a user choice before work can
  continue.
- **Anchor note:** a short user-authored judgment, next step, or context marker.
- **Context snapshot:** a durable summary of the goal, process states, decisions,
  and resume position at a meaningful moment.
- **Handoff:** the transition from desk presence to away presence while Anchor
  secures the latest context.
- **Return:** reconciliation and summarization after desk presence resumes.

## State model

Lifecycle and presence are separate so that a session can stay active while the
user leaves the desk.

### Session status

`draft -> active -> completed -> archived`

- `draft`: goal and processes are being prepared.
- `active`: events and decisions may continue to arrive.
- `completed`: the final snapshot and summary are saved; no new process work is
  expected unless the session is resumed.
- `archived`: retained for history but removed from the active workspace.

### Presence status

`atDesk -> handingOff -> away -> returning -> atDesk`

Automatic detection is advisory. A manual correction must be available and must
be recorded as a presence event for diagnostics.

### Process status

`queued | running | needsDecision | blocked | completed | failed | disconnected`

Progress is optional. A process that cannot report a meaningful percentage must
show a status and last event rather than a fabricated progress value.

### Decision status

`open -> resolved | expired | cancelled`

A resolution records the selected option, actor, timestamp, and resulting
process event. Repeated delivery must not create duplicate decisions.

## Primary user journey

1. **Establish an anchor**
   - The user records a goal, completion criteria, and one to six processes.
   - Text is required for the first implementation; voice is an enhancement.
   - Outcome: an active session exists locally before any remote integration is
     required.

2. **Use iPhone as a desk companion**
   - Portrait provides the full goal and process overview.
   - Landscape is a low-interaction ambient display with large glanceable metrics.
   - Only a decision-required process becomes the dominant visual focus.
   - Outcome: the user can understand the whole workspace without cycling through
     every Mac window.

3. **Record an anchor note**
   - The user saves a judgment, next step, or context marker without changing the
     session or process state.
   - Outcome: the note becomes part of the next context snapshot.

4. **Hand off and leave**
   - Anchor confirms that the latest goal, processes, and open decisions are
     secured before entering away mode.
   - Running processes continue to report events.
   - Outcome: the user sees only meaningful remote changes and open decisions.

5. **Return**
   - Devices reconcile their event histories.
   - The return summary shows elapsed time, net changes, failures, completed work,
     open decisions, and a recommended next action.
   - Outcome: the user can resume or resolve the top decision without rebuilding
     context manually.

6. **Complete and preserve**
   - The session stores a final snapshot, decisions, notes, and summary.
   - Outcome: the work can be reviewed or resumed later.

## Native surface map

### iPhone app

- New anchor setup.
- Active portrait dashboard.
- Active landscape ambient dashboard.
- Process detail and decision sheet.
- Anchor note capture.
- Away dashboard.
- Return summary and resume action.
- Session summary and history.
- Source, sync, notification, privacy, and accessibility settings.

### macOS companion app

- Menu bar status and active-session summary.
- Session pairing and source health.
- Manual event capture and anchor notes.
- Open-source or deep-link action for an iPhone decision.
- Return summary on the Mac when useful, without stealing focus.
- Explicit controls for source permissions and launch-at-login.

“macOS plugin” is a product label, not one technical extension. The native
implementation is a containing macOS companion app with source adapters. A Safari
web extension and CLI are optional adapters distributed alongside it.

## MVP boundary

### Must be in the first end-to-end release

- Native iOS and macOS app targets with a shared domain model.
- Local persistence and crash-safe recovery.
- Manual session and process creation.
- A simulated source, supported CLI event source, and generic Safari lifecycle
  source.
- Same-network low-latency sync with durable iCloud fallback.
- Portrait dashboard, process detail, decision, handoff, away, return, and
  completion flows.
- Honest connection, stale-data, empty, permission-denied, and retry states.
- Unit tests for state transitions, event deduplication, merge rules, and return
  summary generation.
- VoiceOver, Dynamic Type, Differentiate Without Color, and Reduce Motion support.

### Later phases

- Site-specific Safari adapters; other browser packages are outside the MVP.
- Direct integrations with individual AI or creative services.
- Voice capture and automatic context summarization.
- Live Activities, StandBy tuning, and configurable widgets.
- Optional Anchor-managed cloud service and multi-user collaboration.
- Advanced automatic presence inference.

### Explicitly not an MVP strategy

- Reading every notification from every Mac application.
- Screen scraping, keylogging, or broad Accessibility permission as a default.
- Fabricating progress for sources that expose no progress signal.
- Sending raw prompts, documents, or generated assets to an Anchor server without
  a separate, explicit product decision and consent flow.

## Visual and interaction contract

The prototype establishes a “Candy Harbor” visual language:

- Paper white `#FFF8ED`, object white `#FFFDF8`, deep sea `#123B53`, seafoam
  `#91DDC4`, coral `#FF7B62`, sand `#F7BD3C`, cyan `#59CBD0`, and periwinkle
  `#8B84F7` are the reference palette.
- Deep sea is the primary action color. Amber is reserved for attention and
  decision signals, never an entire task identity.
- Process card color represents source identity. Status must also use text,
  symbols, pattern, or shape so color is never the only signal.
- Portrait supports interaction and detail. Landscape reduces information density
  and keeps decisions in an inline side panel rather than a modal takeover.
- Progress bars use solid fill while the user is at the desk and a distinct
  patterned treatment for remotely observed progress.
- Motion supports continuity but is optional. Reduce Motion replaces travel,
  bounce, pulse, and parallax with short opacity transitions.
- Native text must use Dynamic Type. Prototype pixel sizes are visual references,
  not fixed production type sizes.

## Acceptance outcomes

The first vertical slice is successful when:

1. A session created on one device survives restart and appears on the other.
2. A Mac-generated event is visible on a foreground iPhone within two seconds on
   the same local network, with eventual CloudKit delivery when local transport is
   unavailable.
3. Replayed or retried events do not create duplicate history or decisions.
4. An open decision can be resolved on iPhone and the Mac source receives one
   idempotent resolution.
5. After an away interval, the return summary is derived from real event history
   and identifies the highest-priority unresolved item.
6. Loss of network, iCloud, source permission, or a Mac connection produces an
   accurate, recoverable state rather than silent data loss.
7. Core flows remain usable with VoiceOver, large accessibility text, Reduce
   Motion, and Differentiate Without Color.

## Decisions still requiring product ownership

- Minimum supported iOS and macOS versions for the first public release.
- Whether iPhone and Mac ship as one universal purchase and how bundle identifiers
  should be organized.
- Which two real process sources follow the CLI adapter.
- Whether an open decision may execute an action automatically or only deep-link
  the user back to the source.
- How much raw task content is allowed in iCloud and notification previews.
- What signals may infer desk presence and how prominent the manual override is.
- Whether the first beta is personal-only or needs team/workspace concepts.

## Source material

- Original definition: [`Product/Prototype/Anchor.pdf`](../Product/Prototype/Anchor.pdf)
- Prototype guide: [`Product/Prototype/README.md`](../Product/Prototype/README.md)
- Current interaction implementation:
  [`Product/Prototype/src/App.jsx`](../Product/Prototype/src/App.jsx)
- Visual references and captures:
  [`Product/Prototype/output/playwright/`](../Product/Prototype/output/playwright/)
