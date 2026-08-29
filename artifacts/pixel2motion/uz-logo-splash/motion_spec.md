# Uz Logo Splash — Motion Spec

## Motion brief

- **Source:** `May/May/Assets.xcassets/AppIcon.appiconset/AppIcon.png`, 1024 × 1024 RGB PNG, white background, black joined Uz mark.
- **Usage:** first-launch / cold-launch brand splash. The reveal plays once, settles to the verified static mark, then hands off to the app.
- **Personality:** precise, intelligent, trustworthy.
- **Axes:** medium-low energy with a short burst of speed.
- **Preset basis:** Trustworthy / Professional with a fast but readable flight, a physically motivated impact squash, and a 500 ms final hold.
- **Complexity:** one off-screen ball, analytic filled paths for the final mark, and one normalized z centerline used during the draw-on. The ball and U share a center so the conversion reads as one continuous mass rather than a cut.

## Part inventory

| ID | Role | Final state |
|---|---|---|
| `#ball` | Incoming mass | Hidden off the final frame |
| `#u-fill` | Primary U body | Opaque black analytic fill |
| `#z-fill` | Secondary z / completion latch | Opaque black analytic fill |
| `#u-draw` | Reserved U guide | Hidden in the production choreography |
| `#z-draw` | Temporary z construction stroke | Hidden after the fill handoff |

## Choreography

The ball enters from below with a short off-screen hint, accelerates into the center, then squashes as the U grows from the same center. The z follows only after the U is legible, drawing top bar → diagonal → lower bar with the same 100-unit stroke width. The guide is handed to the analytic fill before a restrained 1.5% settle and a required 500 ms hold.

| Time | Beat | U | z | Principles |
|---:|---|---|---|---|
| 0–50 ms | Off-screen hint | Hidden | Hidden | Staging, anticipation |
| 50–450 ms | Ballistic rise | Hidden | Hidden | Timing, arc, slow in/out |
| 320–860 ms | Ball → U conversion | Expands from the ball center; impact squash overlaps arrival | Hidden | Squash/stretch, overlap, follow-through |
| 720–1100 ms | z construction | Stable U | Top bar → diagonal → lower bar | Staging, timing, appeal |
| 1100–1220 ms | Fill handoff + settle | Static fill | Guide hands to static fill; 98.5% → 100% | Follow-through, slow in/out |
| 1220–1720 ms | Brand hold | Static Uz | Static Uz | Staging, appeal |

The 1720 ms core follows the requested pacing: quick entry, readable action, then a full 500 ms hold. Native SwiftUI adds a 240 ms cover fade for the handoff to the home screen.

## Tokens

```css
--p2m-duration: 1720ms;
--p2m-ease-flight: cubic-bezier(0.18, 0.86, 0.24, 1);
--p2m-ease-morph: cubic-bezier(0.22, 0.78, 0.18, 1);
--p2m-ease-impact: cubic-bezier(0.34, 0, 0.18, 1);
--p2m-ease-settle: cubic-bezier(0.4, 0, 0.2, 1);
--p2m-ball-squash-x: 0.74;
--p2m-ball-stretch-y: 1.14;
--p2m-z-stroke-width: 100;
```

Literal cubic Bézier values are used inside keyframes so Chromium cannot silently fall back to linear interpolation.

## Atomic studies

- Hover/lift: restrained scale and 1.5° counter-rotation.
- Pulse: slow 10% scale inspection study supplied by the showcase shell.
- Arc: spring return from a small rotation.
- Press: input feedback study. Production splash uses the same squash/stretch principle on the entering ball.

## Accessibility and delivery

- `prefers-reduced-motion: reduce` shows the finished logo immediately.
- `?static=1` shows the final frame.
- `?t=<ms>` exposes deterministic timeline frames.
- Replay and speed controls affect the live hero animation.
- Production recommendation: translate the approved parameters to native SwiftUI/Flutter paths; do not embed the HTML in the app.

## Geometry QA

- The final analytic SVG reached **0.9842 IoU** against the raster source while keeping smooth edges as the hard gate.
- Residual mask error: `src_only_px = 790`, `render_only_px = 1837`.
- The final U fill extends beneath z only inside an already-black region, removing the antialias seam without changing the visible silhouette.
- The analytic paths were preferred over the noisier automatic trace; source antialiasing and the faint app-icon perimeter were intentionally not encoded as geometry.

## Motion QA

- Deterministic frame strips cover the full 0–1720 ms timeline: off-screen ball hint, center impact, U conversion, z top/diagonal/bottom construction, 500 ms hold.
- The computed-style probe reports nonlinear ball, U, and z values; literal cubic Bézier functions are embedded in every keyframe.
- A 20 ms ink sweep across the rise and z handoff reports no flatline-then-jump signature.
- The z construction stroke uses the same 100-unit width as the U guide and is hidden only after the analytic z fill is fully present, avoiding the previous gray halo.
- The 1720 ms end frame and static SVG render are pixel-identical in the same pipeline: `exact_equal = true`, `different_channel_values = 0`, `max_abs_diff = 0`.
- The native SwiftUI translation builds and runs on **iPhone 17 Pro Max**. Runtime capture confirms the final 500 ms hold and the subsequent 240 ms handoff reveal the destination and remove the splash.
