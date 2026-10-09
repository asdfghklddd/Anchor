# iOS launch motion — Harbor Drop (2026-10-08)

Requested by the project owner on 2026-10-08 to replace the 2026-09-29 sequence
(1.14 s anticipation, landing, rebound and single ripple).

## Sequence

| Time (s) | Beat |
| --- | --- |
| 0.00–0.34 | The harbor rises out of the blank system launch screen; the logo fades in and lifts 12 pt with a small crouch and −5° tilt |
| 0.20–0.58 | The logo falls under gravity (quadratic ease-in), stretching along the fall and tilting to +3° |
| 0.58 | Impact: brief squash, 14 spray droplets on ballistic paths, three flattened ripple rings, and a travelling dip in the surface |
| 0.58–~1.6 | An underdamped spring (ω 6.5, ζ 0.62) carries 30 % of the fall speed to the resting depth; nine bubbles rise and vanish at the surface |
| 0.88 / 1.02 | `ANCHOR` and the slogan (`launch.slogan`: “让思路靠岸” / “Let your thinking come ashore”) sharpen out of an 8 pt blur while settling 8 pt upward |
| 1.78–2.20 | The tide rises past the top of the screen, the text lifts away, and the scene fades from 45 % of the tide onward, handing over to the workspace |

A tap anywhere starts the tide immediately with a 0.26 s exit. Reduce Motion (system or
app setting) shows a still harbor with the resting logo and slogan, holds 0.55 s and
fades in 0.18 s. The workspace stays mounted underneath; hit testing and accessibility
are gated until the overlay is removed.

## Implementation

- `HarborLaunchChoreography` (AnchorDesign, platform-neutral) computes every pose,
  particle, reveal and waterline as a pure function of elapsed time; covered by
  `HarborLaunchChoreographyTests`.
- `HarborLaunchSplash` draws it in a `TimelineView(.animation)`: a back `Canvas` (sky,
  far water, light shafts), the logo image, a translucent near-water `Canvas` that tints
  whatever is submerged (rim, ripples, bubbles, spray), then the wordmark.
- `AnchorLaunchGate` starts the clock on first appearance, so a slow cold start does not
  skip the opening beats, and removes the overlay after `Timing.total`.
- The logo (`AnchorLaunchLogo` in `Colors.xcassets`) is cut from `AppIcon-1024.png` with
  straight alpha; colors come from `AnchorIOSStyle`, including `oceanSurface`/`oceanDeep`.
- No timers, `Task.sleep` frame loops, network assets or new dependencies.

## Verification

Simulator recordings (iPhone 18 Pro, iOS 27.0) in light, dark and Reduce Motion are under
`../../Build/Previews/Launch-20261008/`. Not yet verified on a physical device or for
frame pacing on ProMotion displays. In the Debug simulator build the system launch
screen stays up for about 2–3 s before the first frame; that cost precedes this sequence.
