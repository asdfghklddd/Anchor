# Anchor Web Observation extension

This is the production Chromium WebExtension source package for Anchor's generic
web lifecycle adapter. It is not linked to either Demo app.

- Disabled until the user enables the accessible popup switch.
- Uses `tabs` only to reduce the active HTTP(S) page to its hostname.
- Sends native messages only to the pinned `com.andywang.anchor.web` host.
- Uses the sandboxed `AnchorWebBridge` embedded only in the production macOS app.
- Ignores incognito, page titles, paths, query strings, content, and form data.
- Requests no host permissions and injects no content scripts.

See `Documentation/WEB_OBSERVATION_CONTRACT.md` for the signal contract, local
development registration, security boundary, and Safari follow-up work.
