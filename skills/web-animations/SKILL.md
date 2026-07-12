---
name: web-animations
description: Design, review, or fix UI motion — animations, transitions, gestures, hover/press, modal/drawer/toast, drag — to the bar that makes software feel great (Emil Kowalski / animations.dev). Use when building or auditing any web animation, or when motion feels off (janky, sluggish, too much). Not for designed vector animation (Lottie/Rive) or CSS layout.
---

# Web Animations — motion that feels right

Great motion is invisible: users feel its *absence*, not its presence — a thousand barely-audible details
in tune. This skill is the build/audit **workflow**; the exact defaults (durations, easing curves,
GPU-only props, a11y) live in the frontend pack — `engineering/fields/frontend/stack-defaults.md` →
*Animation & motion*. Read that section first, then apply this. Craft encoded from Emil Kowalski
(animations.dev; creator of Sonner + Vaul).

## Decide before you animate — four questions, in order

If one fails, stop.

1. **Should this animate at all?** By *frequency*: fires 100×/day (shortcuts, command palette, keyboard
   actions) → **no animation, ever.** Occasional (modal, toast, drawer) → yes. Rare/first-run
   (onboarding, celebration) → room for delight.
2. **What's the purpose?** Orient (where did this come from / go?), give feedback, or direct attention.
   No purpose → don't animate.
3. **Which easing?** `ease-out` enter/exit · `ease-in-out` on-screen move · `ease` hover/color ·
   `linear` continuous. **Never `ease-in` on UI.**
4. **How fast?** <300ms; press ~120ms, dropdown ~200ms, modal ~300ms. Faster reads as more responsive.

## Reviewing / improving animations — audit checklist

Go category by category; for each violation, name the fix (see `stack-defaults.md` for values):

- **Purpose** — does it earn its motion, or is it decoration/noise?
- **Frequency** — anything animated that fires 10–100×/day? Remove or drastically reduce.
- **Easing** — any `ease-in`, or default `ease` where `ease-out` belongs? Linear on non-continuous UI?
- **Duration** — anything >300ms that isn't a large surface? Anything janky-fast?
- **Physicality** — enters from `scale(0)`? Springs missing on drag? Bounce too strong?
- **Performance** — animating layout props (`width/height/top`)? Main-thread Framer `x`/`y`? CSS-var
  churn recalculating children?
- **Interruptibility** — keyframes on something that re-triggers (toast, menu)? Should be transition/spring.
- **Accessibility** — `prefers-reduced-motion` handled? `:hover` transforms gated for touch?
- **Cohesion** — timing/easing consistent with the product's personality, or a grab-bag?

## Gotchas (silent feel-killers)

- `ease-in` and over-long durations make UI *feel* slow even at the "same" speed.
- `scale(0)` entries look broken — start at `scale(0.95)`.
- Keyframes can't be interrupted; a re-triggered element jumps/restarts. Use CSS transitions or springs.
- Animating `height`/`width` (accordions) → jank. Animate `transform`, `grid-template-rows`, or FLIP.
- Framer `x`/`y` are main-thread — use `transform: translateX()` when the browser is busy.
- Motion without `prefers-reduced-motion` is an accessibility **bug**, not a nice-to-have.

## Source

Emil Kowalski — <https://animations.dev>, `emilkowalski/skills` (MIT). Easing: easing.dev, easings.co.
Distilled, not vendored — the durable defaults live in the frontend field pack (SSOT).
