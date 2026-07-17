---
id: recurring-event-dst
domain: frontend
difficulty: hard
---

## Prompt

A React component must list the next N occurrences of a weekly recurring meeting. The meeting is defined as a wall-clock time in an IANA time zone (e.g., 09:00 every Wednesday in Europe/Berlin, first occurrence '2026-03-25T09:00:00'), and each occurrence must be displayed in the viewer's zone. No date libraries — standard Date + Intl only. Fix this implementation:

```tsx
function nextOccurrences(startISO: string, count: number): Date[] {
  const first = new Date(startISO); // meant to be 09:00 Europe/Berlin
  const out: Date[] = [];
  for (let i = 0; i < count; i++) {
    out.push(new Date(first.getTime() + i * 7 * 24 * 3600 * 1000));
  }
  return out;
}

export function OccurrenceList({ startISO, count, viewerZone }: {
  startISO: string; count: number; viewerZone: string;
}) {
  return (
    <ul>
      {nextOccurrences(startISO, count).map((d, i) => (
        <li key={i}>{d.toLocaleString()}</li>
      ))}
    </ul>
  );
}
```

The event zone is a prop (`eventZone: string`). The meeting must stay at 09:00 event-zone wall-clock across DST transitions (Europe/Berlin springs forward 2026-03-29). Handle nonexistent and ambiguous wall-clock times deterministically and document the chosen rule in a comment. The result must not depend on the machine's own local time zone.

## Rubric

1. Occurrences that cross the spring-forward transition remain 09:00 wall-clock in the event zone — the UTC instant shifts by one hour rather than being computed as a fixed +604800000 ms.
2. The start string is interpreted in the event zone, not via bare `new Date('YYYY-MM-DDTHH:mm:ss')` (which is runtime-local-zone dependent) and not as UTC.
3. Zone offsets are derived correctly at each occurrence's date via Intl.DateTimeFormat({ timeZone }).formatToParts (or an equivalent correct instant-to-wall-clock conversion) — no hardcoded offsets like +1/+2.
4. Recurrence stepping happens in calendar/wall-clock space (advance the date by 7 days, then resolve to an instant in the event zone), so DST weeks are correctly 167 or 169 hours apart in UTC.
5. Nonexistent wall-clock times (spring-forward gap) are resolved deterministically with a documented rule, producing a valid Date — never an Invalid Date/NaN.
6. Ambiguous wall-clock times (fall-back repeat) are resolved deterministically with a documented rule (e.g., first/earlier offset) — the resolution is explicit in code, not left to platform luck.
7. Display uses toLocaleString/Intl.DateTimeFormat with an explicit timeZone: viewerZone option, and the rendered date (including day-of-week, which may differ from the event zone's) derives from the exact UTC instant.
8. The computation is independent of the runtime's local zone: no use of local getters/setters (getHours/setDate on local time) in the conversion path — only UTC accessors/arithmetic plus Intl with explicit zones.
9. Edge inputs handled: count = 0 returns an empty list; an invalid IANA zone string surfaces a clean, caught error (Intl throws RangeError) rather than crashing the render.
10. List keys are stable and content-derived (e.g., the occurrence's epoch/ISO instant), not the array index.
