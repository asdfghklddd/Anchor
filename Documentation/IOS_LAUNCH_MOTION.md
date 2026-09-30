# iOS launch motion — 2026-09-29

The launch presentation uses a finite 1.14-second sequence: 120 ms anticipation,
160 ms landing, 420 ms rebound/settle, then a 280 ms crossfade beginning at 860 ms.
A single expanding ring and the wordmark begin at the 280 ms landing point.
The app content stays mounted during the presentation, with hit testing and
accessibility temporarily gated until the overlay is removed.

Reduce Motion uses a static mark and wordmark with a 180 ms fade after 220 ms.
There is no continuous animation, fake progress, network asset fetch, or new
runtime dependency. Cancelled view tasks can restart from a consistent state.

## References evaluated

- https://github.com/GetStream/swiftui-spring-animations — spring timing,
  multi-step movement and settling; used as conceptual reference. No source copied.
- https://github.com/GetStream/purposeful-ios-animations — purpose-driven UI motion.
- https://github.com/airbnb/lottie-ios — suitable for authored vector timelines;
  requires an animation asset. No Lottie asset was available for this brand.
- https://github.com/rive-app/rive-ios — suitable for interactive characters and
  state machines; would be appropriate with a dedicated Anchor character asset.

The implementation uses SwiftUI keyframe tracks so position, squash/stretch and
rotation have explicit timings. It preserves Anchor's existing brand mark and
semantic colors. This work does not use Duolingo artwork or claim to reproduce
its proprietary animation system.
