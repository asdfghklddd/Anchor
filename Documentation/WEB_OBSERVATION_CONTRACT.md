# Web observation contract

Anchor's generic web layer is an explicit browser extension plus a local native
messaging host. It does not read browser profile databases, cookies, page text,
or network traffic.

## Current production checkpoint

The production macOS app now registers a dedicated `WebProcessSource` that
consumes `anchor.web.activity.v1` signals from the App Group `WebInbox`. The
Chromium-compatible WebExtension in `Integrations/AnchorWebExtension` is disabled
by default and begins observing only after the user enables its popup switch.

The generic extension reports:

- a random activity UUID scoped to one browser tab and site;
- monotonically ordered lifecycle signals;
- `active`, `background`, and `closed` state;
- the site hostname only; and
- the static source label `Browser`.

It explicitly ignores private/incognito tabs and non-HTTP(S) pages. It does not
request host permissions, inject content scripts, or store page titles, URL
paths, query strings, page content, form values, cookies, or browsing history in
Anchor. The browser's `tabs` permission is used only to identify the active
HTTP(S) hostname.

Generic browser state cannot truthfully reveal a site's internal percentage or
completion state. Later site-specific adapters may emit `running`, `completed`,
or `failed` and optional `0...1` progress, but only after a separate narrow site
permission and data review.

## Signal schema

```json
{
  "id": "01A23B45-C678-4901-A234-56789BCDEF01",
  "schema": "anchor.web.activity.v1",
  "activityID": "11A23B45-C678-4901-A234-56789BCDEF02",
  "sequence": 42,
  "state": "active",
  "occurredAt": "2026-08-25T10:00:00Z",
  "siteHost": "docs.example.com",
  "browserName": "Browser"
}
```

`siteName`, `progress`, `metric`, and `metricLabel` are optional structured
adapter fields. The macOS decoder strips any scheme, path, query, or fragment
from `siteHost` again, even if an external extension bypasses the bundled
JavaScript. Progress outside `0...1`, unsupported schemas, oversized messages,
and malformed hosts are rejected and quarantined.

High-frequency active/background changes update the current process card without
adding timeline noise. Structured progress, completion, and failure can create
timeline events. Signals older than the current Anchor session are moved to
`.ignored` rather than attached to a later session.

## Native messaging boundary

Chrome and Chromium send one UTF-8 JSON message framed by a four-byte length.
The `anchor` executable validates the frame, re-decodes and minimizes the signal,
atomically writes it into the dedicated Web inbox, and returns one framed
acknowledgement. Standard output contains protocol frames only.

The host name is `com.andywang.anchor.web`. The extension public key pins its ID
to `omodbnhjlobhhkjcbaeokekfadoeiemk`, and the native-host manifest allowlists
only that exact extension origin. The committed manifest is a template; this
checkpoint does not install or edit any browser profile.

For a local development check:

```bash
cd Packages/AnchorKit
swift build -c release --product anchor

.build/release/anchor browser manifest \
  --path "$PWD/.build/release/anchor"
```

The generated JSON belongs at the browser-specific user NativeMessagingHosts
location, for example:

- Chrome: `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/`
- Edge: `~/Library/Application Support/Microsoft Edge/NativeMessagingHosts/`
- Chromium: `~/Library/Application Support/Chromium/NativeMessagingHosts/`

Load `Integrations/AnchorWebExtension` as an unpacked extension only on a test
browser profile, register the generated manifest, then enable observation from
the popup. A signed/notarized binary, in-app installer, uninstall path, and store
distribution are still required before end-user release.

## Safari boundary

Safari uses the same WebExtensions concepts but a different native boundary: a
Safari Web Extension native app extension receives messages and shares data with
the containing app through the App Group. It must be added as its own signed
production target with explicit website permissions. The Chromium stdio host is
not presented as Safari support.

## Implementation references

- Chrome's native messaging contract defines the host manifest, pinned
  `allowed_origins`, stdio framing, and output limits:
  <https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging>
- Apple's Safari Web Extension documentation defines the three-sandbox native
  messaging and App Group design:
  <https://developer.apple.com/documentation/safariservices/messaging-between-the-app-and-javascript-in-a-safari-web-extension>
- `LastByteLLC/iClaw` demonstrates a Swift length-prefixed native host:
  <https://github.com/LastByteLLC/iClaw/blob/c55a0885ca2ac206cccace9210b79aeef8be1ec0/Sources/iClawNativeHost/main.swift>
- `enokcollective/select-copy` demonstrates pinning an extension ID and writing
  browser-specific native-host manifests on macOS:
  <https://github.com/enokcollective/select-copy/blob/3a3c7793ef45b5bcbf3e410e2fc730987f9bdede/macos/Sources/SelectCopy/HostInstaller.swift>

Anchor reuses the protocol shape, not those products' browser-control scope:
this bridge is observation-only and intentionally excludes page content and
remote browser control.
