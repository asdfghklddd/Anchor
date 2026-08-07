# CloudKit durable event path

The MVP backend includes a private-database `CloudKitEventStore` and a
`DurableEventSynchronizer` that uploads the local outbox before applying remote
events. Upload acknowledgement is intentionally separate from local commit:
if iCloud is unavailable, the event remains in the local outbox and can be
retried later. A retry after a lost CloudKit response treats the same immutable
record as success, while a conflicting record ID is surfaced as an error.
Remote order is not trusted; the local repository deduplicates by event
ID/source sequence/deduplication key and deterministically replays the event
history.

A build signed by a paid Apple Developer Program Team (individual or
organization) may create `DurableSyncRunner` only when the bundle contains:

`ANCHOR_CLOUDKIT_CONTAINER_IDENTIFIER = iCloud.com.andywang.anchor`

The development schema for `AnchorEventEnvelope` should contain these fields:

| Field | CloudKit type | Required | Purpose |
| --- | --- | --- | --- |
| `sessionID` | String | yes | Session UUID used by the remote query |
| `sourceID` | String | yes | Device/source UUID |
| `sequence` | Number (Int64) | yes | Per-source event sequence |
| `timestamp` | Date/Time | yes | Deterministic ordering and incremental query |
| `type` | String | yes | Envelope type |
| `payload` | Bytes | yes | Encoded `SessionOperation` payload |
| `schemaVersion` | Number (Int64) | yes | Wire schema version |
| `deduplicationKey` | String | no | Optional operation deduplication key |

The record name is the envelope UUID, so it is not an additional custom field.
Mark `sessionID` and `timestamp` queryable, and `timestamp` sortable, because
the store queries by session and orders the returned events by timestamp.

The current project is signed with Andy's free Personal Team, which does not
support the iCloud capability. Personal-Team builds therefore intentionally
omit the CloudKit entitlement and bundle key, keep the app local-first, and
leave the CloudKit backend available for a future paid-Team configuration. The
repository now includes separate CloudKit variant files under `Configuration/`;
the default schemes remain local-first. When a paid Developer Team is
available, the variant files add the same entitlement and bundle key to both
formal targets; their existing foreground
`DurableSyncRunner` will then use this private container on the existing
60-second cadence. Demo targets remain local-only.

To build the future CloudKit variant without changing the current personal-Team
configuration, provide the paid Team ID explicitly. The variant intentionally
does not store a Team ID in Git:

```sh
xcodebuild -project Anchor.xcodeproj -scheme "Anchor iOS" \
  -xcconfig Configuration/AnchorIOS-CloudKit.xcconfig \
  ANCHOR_CLOUDKIT_DEVELOPMENT_TEAM=YOUR_PAID_TEAM_ID build

xcodebuild -project Anchor.xcodeproj -scheme "Anchor macOS" \
  -xcconfig Configuration/AnchorMac-CloudKit.xcconfig \
  ANCHOR_CLOUDKIT_DEVELOPMENT_TEAM=YOUR_PAID_TEAM_ID build
```

In Xcode, the same `.xcconfig` files can be assigned as the base configuration
file for dedicated CloudKit build configurations; a CloudKit scheme can then
select those configurations after the paid Team is available.

Before treating the path as production-ready, the team must still:

1. Create and deploy the private CloudKit record type `AnchorEventEnvelope`.
2. Confirm the iCloud container is enabled for both production App IDs and
   their provisioning profiles in the Apple Developer account.
3. Build the formal targets with the matching CloudKit `.xcconfig` files and
   paid Team ID.
4. Exercise account unavailable, quota, schema, and two-device offline merge
   cases in the development container.

Background push delivery is intentionally not enabled yet. The current runner
is foreground-driven and there is no CloudKit subscription/remote-notification
handler in this MVP; adding `aps-environment` before that path exists would
create a misleading capability without improving synchronization.

Those are Apple-account provisioning steps, not code that can be truthfully
verified in this local repository. Until they are complete, CloudKit may report
an unavailable or failed sync state, while the apps remain local-first and no
local event is discarded.
