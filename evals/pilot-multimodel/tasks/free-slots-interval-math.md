---
id: free-slots-interval-math
domain: general
difficulty: medium
---

## Prompt

Implement a scheduling helper in TypeScript (or plain JavaScript with JSDoc types):

```ts
type Interval = { start: number; end: number }; // minutes since midnight, start < end for valid busy blocks

/**
 * Given a working window [dayStart, dayEnd) and a list of busy intervals,
 * return the free intervals within the window, sorted by start time.
 * busy may be unsorted, may contain overlapping or touching intervals,
 * and may contain intervals partially or fully outside the window.
 */
function getFreeSlots(busy: Interval[], dayStart: number, dayEnd: number): Interval[]
```

Example: getFreeSlots([{start: 540, end: 600}, {start: 720, end: 780}], 480, 1020) → [{start: 480, end: 540}, {start: 600, end: 720}, {start: 780, end: 1020}].

Write the implementation. Handle every edge case implied by the doc comment; state any additional assumptions you make (e.g. invalid inputs) in a comment.

## Rubric

1. Returns the full window [{start: dayStart, end: dayEnd}] when busy is empty, and [] when busy fully covers the window — no crash, no zero-length or inverted slots
2. Handles unsorted input correctly (sorts by start before sweeping), verified by the algorithm not assuming input order
3. Merges overlapping AND touching busy intervals (e.g. [540,600] + [600,660] yields no free gap at 600, and [540,660] + [550,570] does not create a phantom slot inside)
4. Clamps busy intervals that extend before dayStart or after dayEnd, and ignores intervals entirely outside the window
5. Never emits zero-length free slots (e.g. busy starting exactly at dayStart or ending exactly at dayEnd produces no {x, x} entries)
6. Does not mutate the input array (sorts a copy) and degenerate/invalid entries (end <= start) are either filtered out or handled per an explicitly stated assumption
