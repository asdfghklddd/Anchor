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

The production app creates `DurableSyncRunner` only when the bundle contains:

`ANCHOR_CLOUDKIT_CONTAINER_IDENTIFIER = iCloud.com.andywang.anchor`

Before enabling that key in the release configuration, the team must:

1. Create and deploy the private CloudKit record type `AnchorEventEnvelope`.
2. Add the matching iCloud container entitlement to both production targets.
3. Add the CloudKit capability and remote-notification/background delivery
   configuration in the Apple developer account.
4. Exercise account unavailable, quota, schema, and two-device offline merge
   cases in the development container.

Those are Apple-account provisioning steps, not code that can be truthfully
verified in this local repository. Until they are complete, the apps remain
local-first and the CloudKit runner is disabled; no local event is discarded.
