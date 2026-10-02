# Maintaining the Anchor product atlas

Public URL: **https://asdfghklddd.github.io/Anchor/**

## Files

| File | Purpose |
| --- | --- |
| `index.html` | Chinese overview, design changes, and evidence boundaries |
| `data.js` | Version, source baseline, page inventory, flow edges, and screenshot provenance |
| `app.js` | Maps, path highlighting, filters, detail dialogs, and shareable hashes |
| `styles.css` | Responsive layout, reduced motion, keyboard focus, and print layout |
| `assets/` | Application icon and native UI screenshots using isolated test data |
| `.nojekyll` | Publish the static files directly |

No package install, bundler, remote font, analytics, or runtime service is required.
All asset paths are relative so the site works under the repository's `/Anchor/` path.

## Publishing

The repository uses **GitHub Pages → Deploy from a branch → main → /docs**.
Commits to this directory on `main` trigger the standard Pages build and deployment.
The README links to the stable public URL. Do not publish the repository root or local
build directories as the Pages source.

Local preview from the repository root:

```sh
python3 -m http.server 8765 --bind 127.0.0.1 --directory docs
```

Open `http://127.0.0.1:8765`. A modern browser is required for native HTML dialogs.

## Updating the snapshot

1. Read `DESIGN.md` and the current iPhone/Mac navigation and core implementations.
2. Update the date and `baseline` in `data.js`, and the corresponding snapshot copy
   in `index.html`. The baseline must be a published commit containing the referenced
   code. Source links are pinned to this commit so a discussion stays reproducible.
3. Update page entries and flow edges together. An entry needs a stable `id`, title,
   platform, kind, summary, entry point, behavior, and repository-relative source path.
4. Add screenshots only from a controlled test or expressly approved public material.
   Record the date and capture scope in `assets` metadata. Keep structural illustrations
   identified as such; do not present historical screenshots as current UI.
5. Check search, device and image filters, every map, node links, Escape to close,
   focus restoration, direct `#page/<id>` URLs, and small-screen overflow. Check that
   every referenced local file and source path exists.
6. Commit the static atlas and README changes. Push to `main`, wait for the Pages
   deployment to succeed, and verify the live URL and a direct node link.

Source-supported behavior and design goals are separate. CloudKit, BLE/Bonjour,
permissions, signing, and accessibility claims must retain their actual acceptance
boundaries. This website does not establish native distribution or device acceptance.

## Snapshot: 2026-10-02

- Source baseline: `3ed3e0c25e3734f94945c2b1a921b5c7e3cbe285`.
- 43 page/module entries across iPhone, Mac, and shared core; five map views.
- iPhone screenshots: existing 2026-10-02 formal UI-test captures and layout review.
  The populated return captures use `ReturnDataJourneyTests` and `PopulatedReturnUITests`.
- Mac source/settings capture: built from this baseline and captured in an isolated
  Debug app with `ANCHOR_UI_TESTING=1`, a disposable store, and in-memory pairing.
  It illustrates the source section of Settings. The main Mac work window is described
  from source; this capture does not verify all Mac navigation or actual device links.
- The large-text image on the accessibility entry is a return-page adaptation example,
  not a screenshot of the accessibility settings screen. The process detail image is
  the return workflow's process sheet. The creation image shows a restored draft step.
- Duplicate images may be referenced by multiple related entries; the Mac Codex and
  settings entries currently use the same source-section capture.

## Collaboration

Each node has a copyable `#page/<id>` URL and a source link. The feedback button opens
a prefilled GitHub issue draft with the node URL and baseline. It never submits an
issue automatically. Collaborators need GitHub write access only for editing the
repository, not for reading the public atlas.

### Local readability revision included in the screenshots

While the atlas was being prepared, another local update changed
`HostedTaskCard.swift` (explicit unknown/percentage text) and `AnchorSetupView.swift`
(button foreground contrast). The new 2026-10-02 formal UI-test screenshots were
incorporated into the home, landscape and setup entries. At capture time these
changes were not yet committed; those entries explicitly distinguish the local
revision from the pinned source baseline. `data.js.localRevision.files` records the
SHA-256 of both source files at capture time. They belong to the native development
work and are not included in the website-only commit.

When that update is committed, advance the baseline after checking that the file
hashes still match, and remove the temporary local-revision labels.
