# Anchor

Anchor is a native SwiftUI companion for people coordinating several AI-assisted
workflows at once. It keeps the original goal, live process state, key decisions,
and the context needed to return to work after an interruption.

## Repository map

- `Anchor/` - current native SwiftUI application scaffold.
- `AnchorTests/` and `AnchorUITests/` - native test targets.
- `Product/Prototype/` - imported product brief, visual references, React/Vite
  high-fidelity prototype, and prototype verification screenshots.
- `Documentation/PRODUCT_BASELINE.md` - agreed product intent, state model, MVP
  boundary, and acceptance outcomes.
- `Documentation/DEVELOPMENT_BLUEPRINT.md` - proposed native architecture,
  platform boundaries, data and sync strategy, testing policy, and delivery plan.

## Requirements

- Xcode 26.2 or later
- iOS 26.2 or later
- macOS 26.2 or later

Open `Anchor.xcodeproj` in Xcode and select either an iPhone simulator or **My Mac** as the run destination.

The current Xcode project is a shared multiplatform scaffold. Before feature
development, it should be separated into dedicated iOS and macOS app targets
that share a small domain layer, as described in the development blueprint.
