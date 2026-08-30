# Web observation contract

Anchor's MVP web layer is a Safari Web Extension embedded in the production
macOS app. It does not read browser profile databases, cookies, page text, or
network traffic, and it has no Chrome, Chromium, or browser-store dependency.

## Production boundary

The production `Anchor macOS` target embeds `AnchorSafariExtension.appex`. Safari
installs the extension with the containing app, while the user keeps the final
decision to enable it in Safari. Anchor opens the system-managed Safari extension
settings and polls the public `SFSafariExtensionManager` state so the Sources UI
can move from awaiting confirmation to enabled without inspecting Safari data.

The native app extension receives `browser.runtime.sendNativeMessage` requests,
validates them as `anchor.web.activity.v1`, and atomically writes them into the
App Group `WebInbox`. The production app's `WebProcessSource` consumes that
inbox. The containing app and native extension remain sandboxed and share only
`group.com.andywang.anchor` for this flow.

The Demo target embeds neither the Safari extension nor the CLI. The repository
contains no Chromium native-messaging executable, host manifest, external update
configuration, browser setup XPC service, or unpacked Chrome extension.

## Privacy-minimal generic state

The Safari extension reports:

- a random activity UUID scoped to one tab and site;
- monotonically ordered lifecycle signals;
- `active`, `background`, and `closed` state;
- the HTTP(S) hostname only; and
- the static source label `Safari`.

It ignores private tabs and non-HTTP(S) pages. It does not inject content scripts
or store page titles, URL paths, query strings, page content, form values,
cookies, or browsing history in Anchor. The `tabs` permission is used only to
identify the active HTTP(S) hostname. The popup provides a persistent on/off
control independent of Safari's own extension controls.

Generic browser state cannot truthfully reveal a site's internal percentage or
completion state. A future site-specific adapter may emit `running`,
`completed`, or `failed` and optional `0...1` progress only after a separate,
narrow permission and data review.

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
  "browserName": "Safari"
}
```

`siteName`, `progress`, `metric`, and `metricLabel` are optional structured
adapter fields. The native decoder strips any scheme, path, query, or fragment
from `siteHost` again. Progress outside `0...1`, unsupported schemas, oversized
messages, and malformed hosts are rejected and quarantined.

High-frequency active/background changes update the current process card without
adding timeline noise. Structured progress, completion, and failure can create
timeline events. Signals older than the current Anchor session are moved to
`.ignored` rather than attached to a later session.

## Packaging and verification

The Safari resources live in `Apps/AnchorSafariExtension/Resources`. They are
compiled into the signed native app extension and embedded at:

```text
Anchor macOS.app/Contents/PlugIns/AnchorSafariExtension.appex
```

A direct Developer ID distribution can ship the containing macOS app outside the
Mac App Store after signing and notarization. Installation does not bypass
Safari's final extension confirmation or permission UI.

Verification must establish that:

- the formal app contains the `.appex`, its manifest, and the `anchor` CLI;
- the extension point is `com.apple.Safari.web-extension`;
- the app and extension use the same App Group;
- the Demo app contains none of those production adapters; and
- no Chrome/Chromium helper, manifest, update URL, or setup service remains.

## Apple references

- [Messaging between the app and JavaScript in a Safari web extension](https://developer.apple.com/documentation/safariservices/messaging-between-the-app-and-javascript-in-a-safari-web-extension)
- [Running your Safari web extension](https://developer.apple.com/documentation/safariservices/running-your-safari-web-extension)
- [Distributing your Safari web extension](https://developer.apple.com/documentation/safariservices/distributing-your-safari-web-extension)

Safari's native-messaging implementation intentionally ignores the application
identifier supplied by JavaScript and routes the message only to the containing
app's native extension. That is why Anchor needs no external native-host registry
or browser-specific installer.
