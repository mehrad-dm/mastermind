---
id: typeahead-stale-race
domain: frontend
difficulty: hard
---

## Prompt

Fix this React/TypeScript typeahead search component. It must: debounce input by ~300ms, fetch from `/api/search?q=...`, show results in an accessible autocomplete, and never display stale or wrong results. Keep it a single self-contained component (no external libs).

```tsx
import { useEffect, useState } from 'react';

type Item = { id: string; label: string };

export function SearchBox({ onSelect }: { onSelect: (item: Item) => void }) {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Item[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (!query) return;
    setLoading(true);
    const t = setTimeout(async () => {
      const res = await fetch('/api/search?q=' + query);
      const data = await res.json();
      setResults(data.items);
      setLoading(false);
    }, 300);
    return () => clearTimeout(t);
  }, [query]);

  return (
    <div>
      <input value={query} onChange={(e) => setQuery(e.target.value)} />
      {loading && <span>Loading…</span>}
      <ul>
        {results.map((r) => (
          <li key={r.id} onClick={() => onSelect(r)}>{r.label}</li>
        ))}
      </ul>
    </div>
  );
}
```

Requirements: correct behavior when the user types fast (including deleting back to empty), when the network is slow and responses arrive out of order, when a request fails, and when the component unmounts mid-request. The autocomplete must be fully keyboard-operable and screen-reader accessible (WAI-ARIA combobox pattern). Return the complete fixed component.

## Rubric

1. Out-of-order responses can never win: an in-flight request is aborted (AbortController) or its response is discarded via a sequence/latest-check when the query has since changed — clearTimeout alone is not sufficient and is not the only guard.
2. AbortError is explicitly caught and does not set an error state, leave loading stuck true, or surface as an unhandled promise rejection.
3. The query is URL-encoded (encodeURIComponent or URLSearchParams) so inputs containing '&', '#', spaces, or non-ASCII characters produce a correct request.
4. Clearing the input to empty cancels any pending debounce/request, clears results, and resets loading to false — no stale dropdown or stuck spinner remains.
5. Non-OK HTTP responses are handled: res.ok is checked, loading is cleared, a user-visible error state exists, and the code does not crash parsing an error body.
6. No state updates after unmount: the effect cleanup aborts the in-flight fetch or guards setState, covering unmount during both the debounce window and the fetch.
7. Combobox semantics are correct: input has role="combobox" with aria-expanded and aria-controls (and aria-activedescendant or equivalent) referencing a role="listbox" whose options have ids and role="option".
8. Keyboard support: ArrowDown/ArrowUp move the active option, Enter selects it, Escape closes the list — all without moving DOM focus off the input (active option tracked via aria-activedescendant, not tabindex roving into the list).
9. Result availability (e.g., 'N results' / no-results / error) is announced via an aria-live="polite" region rather than being silent, and the announcement is not re-fired on every keystroke.
10. Debounce is preserved: no network request fires for intermediate values abandoned within the ~300ms window (verifiable by inspecting the code path: fetch only occurs inside the settled timer).
