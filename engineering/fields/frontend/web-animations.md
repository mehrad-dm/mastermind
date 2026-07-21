---
field: frontend
route_when: [animation, motion, transition, gesture, spring, easing, scroll, framer-motion, hover, drawer, toast, modal, popover]
---

# Web Animations & Motion — the craft of UI that feels right

Part of the **frontend field pack** — loaded when building or reviewing animation, motion, transitions,
or gestures. This is the complete, vendored playbook, not a summary.

> **Source (MIT):** Emil Kowalski — `emilkowalski/skills` · [animations.dev](https://animations.dev/) ·
> creator of **Sonner** (13M+ weekly downloads) and **Vaul**. Reproduced with attribution; deepen at the
> course. In a world where everyone's software is good enough, **taste is the differentiator** — and taste
> is *trained, not innate*: study great work, reverse-engineer animations, practice relentlessly.

## Core philosophy

- **Taste is trained, not innate.** Not personal preference — a trained instinct to see what elevates.
  Don't just make it work; study *why* the best interfaces feel the way they do. Inspect, reverse-engineer,
  be curious.
- **Unseen details compound.** Most polish users never consciously notice — that's the point. "All those
  unseen details combine to produce something that's just stunning, like a thousand barely audible voices
  all singing in tune." (Paul Graham) The aggregate of invisible correctness is what people love without
  knowing why.
- **Beauty is leverage.** People choose tools on the whole experience, not just function. Good defaults and
  good animation are real differentiators — underused in software. Use them to stand out.

## Review format (required)

When reviewing UI code, output a markdown **table** with Before / After / Why columns — never a list with
"Before:"/"After:" on separate lines.

| Before | After | Why |
| --- | --- | --- |
| `transition: all 300ms` | `transition: transform 200ms ease-out` | Specify exact properties; avoid `all` |
| `transform: scale(0)` | `transform: scale(0.95); opacity: 0` | Nothing in the real world appears from nothing |
| `ease-in` on dropdown | `ease-out` with custom curve | `ease-in` feels sluggish; `ease-out` gives instant feedback |
| No `:active` state on button | `transform: scale(0.97)` on `:active` | Buttons must feel responsive to press |
| `transform-origin: center` on popover | trigger-anchored origin | Popovers scale from their trigger (modals stay centered) |

## The animation decision framework

Before writing any animation, answer these in order.

**1. Should this animate at all?** — by frequency:

| Frequency | Decision |
| --- | --- |
| 100+ times/day (keyboard shortcuts, command palette) | **No animation. Ever.** |
| Tens of times/day (hover, list nav) | Remove or drastically reduce |
| Occasional (modals, drawers, toasts) | Standard animation |
| Rare/first-time (onboarding, celebrations) | Can add delight |

**Never animate keyboard-initiated actions** — repeated hundreds of times daily; animation makes them feel
slow and disconnected. (Raycast has no open/close animation — optimal for something used all day.)

**2. What is the purpose?** Every animation needs a clear "why": spatial consistency (toast enters/exits
same direction → swipe-to-dismiss feels intuitive), state indication, explanation, feedback (button scales
on press), or preventing jarring appear/disappear. If the purpose is just "looks cool" and it's seen often,
don't animate.

**3. What easing?**
- Entering/exiting → **`ease-out`** (starts fast, feels responsive)
- Moving/morphing on screen → **`ease-in-out`**
- Hover/color change → **`ease`**
- Constant motion (marquee, progress) → **`linear`**
- **Never `ease-in` on UI** — it starts slow, so a 300ms dropdown *feels* slower than `ease-out` at the
  same 300ms (it delays the initial movement, exactly when the user is watching most closely).

Use **custom curves** — the built-in CSS easings are too weak. Don't invent them; grab stronger variants
from [easing.dev](https://easing.dev/) / [easings.co](https://easings.co/):

```css
--ease-out:     cubic-bezier(0.23, 1, 0.32, 1);      /* strong ease-out for UI */
--ease-in-out:  cubic-bezier(0.77, 0, 0.175, 1);     /* strong on-screen movement */
--ease-drawer:  cubic-bezier(0.32, 0.72, 0, 1);      /* iOS-like drawer (Ionic) */
```

### CSS is the house vocabulary — GSAP names are a translation, not a default

**Write easing as `cubic-bezier(...)`.** It's stack-agnostic, works in CSS transitions, WAAPI, and Motion
alike, and matches the field's actual default (`stack-defaults.md`: **Motion / Framer Motion** for UI
motion). **GSAP is *not* a stack default here** — its `power2.out`-style names show up in the vendored
motion dataset (`ui-ux-pro-max`, `--domain gsap`) and in third-party code, so you need to *read* them, but
don't adopt them as the house vocabulary. Translate to CSS at the boundary.

These are **exact** equivalences, derived from GSAP's own ease definitions in `gsap@3` source
(`Quad,Cubic,…` → `Power1,Power2,…`; `easeOut = 1 - (1 - p)^n`) and verified to floating-point precision —
not eyeballed approximations:

| GSAP name (secondary) | Exact CSS equivalent | Same curve as |
| --- | --- | --- |
| `power1.out` | `cubic-bezier(0.3333, 0.6667, 0.6667, 1)` | quad out |
| `power1.in` | `cubic-bezier(0.3333, 0, 0.6667, 0.3333)` | quad in |
| `power2.out` | `cubic-bezier(0.3333, 1, 0.6667, 1)` | cubic out |
| `power2.in` | `cubic-bezier(0.3333, 0, 0.6667, 0)` | cubic in |
| `back.out(n)` | `cubic-bezier(0.3333, (n+3)/3, 0.6667, 1)` — e.g. `back.out(1.4)` → `cubic-bezier(0.3333, 1.4667, 0.6667, 1)` | overshoot |
| `none` / `linear` | `linear` | — |

**Deliberately omitted, because no exact `cubic-bezier` exists** — don't let a lookup table lie to you:

- **`power3` / `power4`** (quart/quint) are degree-4 and degree-5 polynomials; a cubic Bézier can't express
  them. The values circulating online are ~2–4% off.
- **`expo`** — GSAP's is a *custom blend*, not the textbook `2^(10(p-1))`, so the usual "easeOutExpo"
  bezier doesn't match it at all.
- **`sine`**, **`circ`** — transcendental/irrational, not polynomial.
- **`elastic`**, **`bounce`** — they oscillate; a cubic Bézier is single-humped and mathematically cannot.
- **`*.inOut` of anything** — GSAP defines these piecewise (two half-curves), which is two beziers, not one.

For all of these, pick a CSS curve by *feel* from [easing.dev](https://easing.dev/) — don't pretend it's a
conversion.

**4. How fast?** — **duration scales with the area the motion covers.** One policy, three tiers. Grounded
in the [Material 3 motion duration tokens](https://m3.material.io/styles/motion/easing-and-duration)
(`short1` 50ms → `long4` 600ms) and Material's size rule: *large distances or dramatic changes in surface
area take longer; short distances or minor changes take less.*

| Tier | What it covers | Duration | M3 token band |
| --- | --- | --- | --- |
| **Small / local** | button press, toggle, checkbox, hover, icon swap, tooltip, small popover | **100–200ms** | `short2`–`short4` |
| **Medium / component** | dropdown, select, modal, drawer, toast, card expand, accordion | **200–350ms** | `short4`–`medium3` |
| **Large / full-screen** | route/page transition, overlay wipe, shared-element hero morph | **350–500ms** | `medium3`–`long2` |

**600ms (`long4`) is the hard ceiling** — and Material's own guidance is that past ~400ms motion starts to
*feel* slow on mobile, so only a genuine full-screen change of surface earns the top of the large tier. A
modal is **medium, not large**: it's a centered component, not a new screen. Exit is always faster than enter.

**Three kinds of motion this policy does not clock**, because they have no fixed duration by nature:
**springs and elastic settle** (parameter-driven — see below), **scroll-scrubbed motion** (tied to scroll
position, not time), and **ambient loops** (skeleton shimmer, marquee — keep one beat under ~1.5s so a long
wait doesn't read as frozen). Marketing/explanatory animation sits outside UI timing entirely and can be longer.

**Perceived performance:** a 180ms select feels more responsive than a 400ms one; a fast-spinning spinner
makes loading *feel* faster at identical load time; `ease-out` at 200ms feels faster than `ease-in` at 200ms
because movement starts immediately.

## Spring animations

Springs simulate physics — no fixed duration, they settle on parameters. Use for: drag with momentum,
elements that feel "alive" (Dynamic Island), interruptible gestures, decorative mouse-tracking.

```jsx
import { useSpring } from 'framer-motion'
// Without spring: artificial, instant → const rotation = mouseX * 0.1
const springRotation = useSpring(mouseX * 0.1, { stiffness: 100, damping: 10 })
```

Decorative springs (mouse-tracking) add life; a *functional* graph in a banking app is better with no
animation. Know when decoration helps vs hinders.

**Config** — Apple's approach is easiest to reason about:
```js
{ type: "spring", duration: 0.5, bounce: 0.2 }          // recommended
{ type: "spring", mass: 1, stiffness: 100, damping: 10 } // more control
```
Keep bounce subtle (0.1–0.3); avoid it in most UI, use for drag-to-dismiss and playful interactions.

**Interruptibility advantage:** springs keep velocity when interrupted — CSS keyframes restart from zero.
Ideal for gestures the user might reverse mid-motion (expand an item, hit Escape → smoothly reverses).

## Component building principles

- **Buttons must feel responsive** — `transform: scale(0.97)` on `:active` with a ~160ms ease-out
  transition. Subtle (0.95–0.98). Applies to any pressable element.
- **Never animate from `scale(0)`** — nothing appears from nothing. Start `scale(0.95)` + `opacity: 0`.
- **Origin-aware popovers** — scale in from the trigger, not center (`transform-origin` = the
  Radix/Base-UI transform-origin variable). **Modals are the exception** — keep them centered.
- **Tooltips: skip delay on subsequent hovers** — delay the first (prevents accidental activation), but
  once one is open, adjacent ones open instantly (`transition-duration: 0ms`), which feels faster.
- **CSS transitions over keyframes for interruptible UI** — transitions retarget mid-flight; keyframes
  restart from zero. For anything rapidly triggered (toasts, toggles), use transitions.
- **Blur to mask imperfect crossfades** — a subtle `filter: blur(2px)` during a state swap blends the two
  overlapping states into one perceived transformation. Keep blur < 20px (heavy blur is expensive in Safari).
- **Animate entry with `@starting-style`** — the modern no-JS way; replaces the `useEffect(() =>
  setMounted(true))` pattern. Fall back to a `data-mounted` attribute where support is missing.

```css
.toast {
  opacity: 1; transform: translateY(0);
  transition: opacity 300ms ease, transform 300ms ease;
  @starting-style { opacity: 0; transform: translateY(100%); }
}
```

## CSS transform mastery

- **`translateY(100%)` = the element's own height** — percentages in `translate()` are relative to the
  element's size, so it adapts to content. How Sonner positions toasts and Vaul hides the drawer. Prefer
  percentages over hardcoded px.
- **`scale()` scales children too** (unlike width/height) — on button press, font/icons scale
  proportionally. A feature, not a bug.
- **3D depth** — `rotateX/rotateY` + `transform-style: preserve-3d` gives real 3D (coin flips, orbits) with
  no JS.
- **`transform-origin`** — the anchor for transforms; set it to match the trigger for origin-aware motion.

## clip-path for animation

`clip-path` is one of the most powerful animation tools, not just for shapes. `clip-path: inset(top right
bottom left)` — each value eats in from that side.

```css
.hidden  { clip-path: inset(0 100% 0 0); }  /* hidden from right */
.visible { clip-path: inset(0 0 0 0); }     /* fully visible */
```

- **Tabs with perfect color transitions** — duplicate the tab list, style the copy as "active," clip it so
  only the active tab shows, animate the clip on change. Seamless in a way per-property color timing can't be.
- **Hold-to-delete** — colored overlay `inset(0 100% 0 0)` → on `:active` transition to `inset(0 0 0 0)`
  over 2s linear; snap back on release with 200ms ease-out; add `scale(0.97)` for press feedback.
- **Image reveal on scroll** — start `inset(0 0 100% 0)` → animate to `inset(0 0 0 0)` on
  `IntersectionObserver` / `useInView({ once: true, margin: "-100px" })`.
- **Comparison sliders** — overlay two images, clip the top with `inset(0 50% 0 0)`, drive the right inset
  from drag position. No extra DOM, fully hardware-accelerated.

## Gesture & drag interactions

- **Momentum dismissal** — don't require a distance threshold; compute velocity `Math.abs(distance) /
  elapsed` and dismiss if it exceeds ~0.11. A quick flick is enough.
- **Damping at boundaries** — dragging past the natural edge should move less the further you go (things
  slow before they stop; they don't hit a wall).
- **Pointer capture** — once dragging starts, capture all pointer events so it continues off-element.
- **Multi-touch protection** — ignore extra touch points after a drag begins (`if (isDragging) return`),
  or the element jumps to a new finger.
- **Friction, not hard stops** — allow over-drag with increasing friction; it feels more natural.

## Performance rules

- **Only animate `transform` and `opacity`** — they skip layout and paint (GPU). Animating
  `padding/margin/height/width` triggers all three rendering steps.
- **CSS variables are inheritable** — changing a var on a parent recalcs *all* children. In a drawer with
  many items, updating `--swipe-amount` on the container is expensive; set `element.style.transform`
  directly instead.
- **Framer Motion `x`/`y`/`scale` shorthands are NOT hardware-accelerated** — they run on the main thread
  via rAF. Use the full `transform` string for GPU acceleration under load:
  `<motion.div animate={{ transform: "translateX(100px)" }} />`.
- **CSS animations beat JS under load** — CSS runs off the main thread and stays smooth while the browser
  loads/paints; rAF-based JS drops frames. Use CSS for predetermined animation, JS for dynamic/interruptible.
- **WAAPI** — `element.animate([...], { duration, fill: 'forwards', easing })` gives JS control at
  CSS-level performance, hardware-accelerated and interruptible, no library.

## Accessibility

- **`prefers-reduced-motion`** — reduced ≠ zero. Keep opacity/color transitions that aid comprehension;
  drop movement and position (transform) animations.
  ```css
  @media (prefers-reduced-motion: reduce) { .element { animation: fade 0.2s ease; /* no transform motion */ } }
  ```
- **Touch-device hover** — gate hover transforms so a tap doesn't trigger a false hover:
  ```css
  @media (hover: hover) and (pointer: fine) { .element:hover { transform: scale(1.05); } }
  ```

## Building loved components (the Sonner principles)

1. **Developer experience is key** — no hooks/context/setup; drop `<Toaster />` once, call `toast()`
   anywhere. Less friction → more adoption.
2. **Good defaults > options** — ship beautiful out of the box; most users never customize.
3. **Naming creates identity** — "Sonner" over "react-toast"; sacrifice discoverability for memorability
   when it's worth it.
4. **Handle edge cases invisibly** — pause timers when the tab hides, fill gaps between stacked toasts to
   keep hover, capture pointer during drag. Users never notice — exactly right.
5. **Transitions, not keyframes, for dynamic UI** — added rapidly, must retarget smoothly.
6. **Build a great docs site** — let people touch/play/understand before adopting.

- **Cohesion** — match motion to the component's personality (Sonner is slightly slow and uses `ease`, not
  `ease-out`, to feel elegant; a dashboard should be crisp and fast). Easing, duration, design, name — all
  in harmony.
- **opacity + height** for list enter/exit is trial-and-error — adjust until it feels right; no formula.
- **Review the next day / in slow motion** — fresh eyes catch timing flaws invisible at full speed.
- **Asymmetric enter/exit** — slow where the user decides (hold-to-delete 2s), fast where the system
  responds (release 200ms). Exit generally faster than enter.

## Stagger

When multiple elements enter together, stagger them (30–80ms between items) for a natural cascade. Keep
delays short — long ones feel slow. Stagger is decorative; never block interaction while it plays.

```css
.item { opacity: 0; transform: translateY(8px); animation: fadeIn 300ms ease-out forwards; }
.item:nth-child(2) { animation-delay: 50ms } .item:nth-child(3){ animation-delay: 100ms }
@keyframes fadeIn { to { opacity: 1; transform: translateY(0); } }
```

## Debugging animations

- **Slow-motion** — bump duration 2–5× or use the DevTools animation inspector. Look for: overlapping
  states in a crossfade, abrupt easing, wrong transform-origin, out-of-sync properties.
- **Frame-by-frame** — Chrome DevTools Animations panel reveals timing issues between coordinated
  properties.
- **Real devices** — test touch gestures on physical hardware (phone via USB + Safari remote devtools),
  not just the simulator.

## Review checklist

| Issue | Fix |
| --- | --- |
| `transition: all` | Specify exact properties: `transition: transform 200ms ease-out` |
| `scale(0)` entry | Start `scale(0.95)` + `opacity: 0` |
| `ease-in` on UI | Switch to `ease-out` / custom curve |
| `transform-origin: center` on popover | Trigger-anchored origin (modals stay centered) |
| Animation on a keyboard action | Remove it entirely |
| Duration outside its tier | Re-tier it: small/local 100–200ms · medium/component 200–350ms · large/full-screen 350–500ms |
| Any UI duration > 600ms | Over the ceiling — cut it, unless it's a spring, a scroll-scrub, or an ambient loop |
| GSAP ease name in house code | Translate to `cubic-bezier(...)`; GSAP is not a stack default |
| Hover animation without media query | Add `@media (hover: hover) and (pointer: fine)` |
| Keyframes on a rapidly-triggered element | Use CSS transitions (interruptible) |
| Framer Motion `x`/`y` under load | Use `transform: "translateX()"` for hardware acceleration |
| Same enter/exit speed | Make exit faster than enter |
| Elements all appear at once | Add stagger (30–80ms between items) |
