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

The default schemes do not configure a CloudKit container. macOS Debug uses
ad-hoc signing by default; persistent device development can select
`Configuration/AnchorMac-Development.xcconfig`. Release uses the configured
production signing settings. None of these facts establishes that a CloudKit
container has been provisioned or accepted on two devices.

Both production launchers call `AnchorCloudSyncFactory.makeRunner`. It returns
no runner without a container identifier. The separate CloudKit variants under
`Configuration/` supply that identifier and the required entitlements. When
configured, the factory's current default polling interval is **5 seconds**;
this is a foreground-driven runner, not background push delivery. No Demo target
is part of the current project.

To build the optional CloudKit variant, supply the provisioned Developer Team ID
explicitly. The variant does not store that Team ID in Git:

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
