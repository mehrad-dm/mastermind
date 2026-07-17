---
id: countdown-timer-stale-closure
domain: frontend
difficulty: medium
---

## Prompt

This quiz countdown is broken: it counts 30 → 29 and then sticks at 29 forever, and onTimeout never fires. QA also found that navigating away mid-countdown logs warnings, and that if the component re-mounts, timers seem to double up. Fix it.

```tsx
import { useEffect, useState } from 'react';

export function Countdown({ seconds, onTimeout }: { seconds: number; onTimeout: () => void }) {
  const [remaining, setRemaining] = useState(seconds);

  useEffect(() => {
    setInterval(() => {
      if (remaining > 0) {
        setRemaining(remaining - 1);
      } else {
        onTimeout();
      }
    }, 1000);
  }, []);

  return <span aria-live='polite'>{remaining}s</span>;
}
```

Explain the root cause in one or two sentences, then return the fixed component.

## Rubric

1. Correctly identifies the stale closure: the interval callback captured the initial `remaining` value, so it always computes 30 - 1
2. The fix makes the count actually reach 0 (functional updater setRemaining(r => r - 1), or a ref, or an effect keyed on remaining) — not just re-running the same broken code
3. The effect returns a cleanup that clears the interval, fixing both the unmount warning and the double-timer on re-mount
4. onTimeout is called exactly once when the timer reaches 0, and the interval stops afterward (does not keep ticking or call onTimeout repeatedly)
5. onTimeout is not called during render or inside the state-updater function; it is invoked from an effect or the interval callback after the state transition
6. The countdown does not skip or reset if the parent re-renders (interval is not recreated every render, and a changing onTimeout identity is handled via ref or documented deps)
