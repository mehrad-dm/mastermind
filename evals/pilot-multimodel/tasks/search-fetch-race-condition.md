---
id: search-fetch-race-condition
domain: frontend
difficulty: hard
---

## Prompt

Users report that this search box sometimes shows results for an OLD query after they finish typing (e.g. they type 'anna', but results for 'an' appear last and stick). It also crashes occasionally with 'cannot update state on unmounted component' patterns and breaks when someone searches for 'a&b'. Fix all the problems.

```tsx
import { useEffect, useState } from 'react';

export function UserSearch() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Array<{ id: string; name: string }>>([]);

  useEffect(() => {
    if (query.length > 0) {
      fetch('/api/users?q=' + query)
        .then((r) => r.json())
        .then((data) => setResults(data));
    }
  }, [query]);

  return (
    <div>
      <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder='Search users' />
      <ul>
        {results.map((u) => (
          <li key={u.id}>{u.name}</li>
        ))}
      </ul>
    </div>
  );
}
```

Return the corrected component.

## Rubric

1. Stale responses can never overwrite newer ones: the effect uses an AbortController (aborting in cleanup) or an ignore/cancelled flag checked before setState
2. The effect returns a cleanup function so no state update fires after unmount or after the query changes
3. The query is safely encoded in the URL (encodeURIComponent or URLSearchParams), so 'a&b' works
4. Fetch failures and non-OK HTTP responses are handled without an unhandled rejection, and abort errors are not surfaced to the user as errors
5. Clearing the input does not leave stale results from the previous query on screen
6. The user gets some pending/loading indication (state or UI) while a request is in flight
