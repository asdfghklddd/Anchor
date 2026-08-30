# Anchor Web Observation extension

This is the production Safari Web Extension source package for Anchor's generic
web lifecycle adapter. It is embedded only in the formal macOS app.

- Starts after Safari's explicit extension confirmation; the accessible
  popup switch lets the user disable observation at any time.
- Uses `tabs` only to reduce the active HTTP(S) page to its hostname.
- Sends native messages only to the containing `com.andywang.anchor` app.
- Uses Safari's signed native app-extension boundary and Anchor's App Group.
- Ignores incognito, page titles, paths, query strings, content, and form data.
- Requests no host permissions and injects no content scripts.

See `Documentation/WEB_OBSERVATION_CONTRACT.md` for the signal contract,
permission boundary, and validation steps.
