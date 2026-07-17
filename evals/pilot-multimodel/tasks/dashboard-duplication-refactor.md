---
id: dashboard-duplication-refactor
domain: frontend
difficulty: easy
---

## Prompt

Refactor this component to remove the copy-paste duplication while preserving its exact behavior (three independent requests, each section shows its own loading and error state). Keep it in TypeScript.

```tsx
import { useEffect, useState } from 'react';

export function Dashboard() {
  const [users, setUsers] = useState<any[]>([]);
  const [usersLoading, setUsersLoading] = useState(true);
  const [usersError, setUsersError] = useState('');
  const [posts, setPosts] = useState<any[]>([]);
  const [postsLoading, setPostsLoading] = useState(true);
  const [postsError, setPostsError] = useState('');
  const [tags, setTags] = useState<any[]>([]);
  const [tagsLoading, setTagsLoading] = useState(true);
  const [tagsError, setTagsError] = useState('');

  useEffect(() => {
    fetch('/api/users').then((r) => r.json()).then((d) => { setUsers(d); setUsersLoading(false); }).catch(() => { setUsersError('Failed'); setUsersLoading(false); });
    fetch('/api/posts').then((r) => r.json()).then((d) => { setPosts(d); setPostsLoading(false); }).catch(() => { setPostsError('Failed'); setPostsLoading(false); });
    fetch('/api/tags').then((r) => r.json()).then((d) => { setTags(d); setTagsLoading(false); }).catch(() => { setTagsError('Failed'); setTagsLoading(false); });
  }, []);

  return (
    <div>
      <section>{usersLoading ? 'Loading…' : usersError ? usersError : users.map((u) => <div key={u.id}>{u.name}</div>)}</section>
      <section>{postsLoading ? 'Loading…' : postsError ? postsError : posts.map((p) => <div key={p.id}>{p.title}</div>)}</section>
      <section>{tagsLoading ? 'Loading…' : tagsError ? tagsError : tags.map((t) => <div key={t.id}>{t.label}</div>)}</section>
    </div>
  );
}
```

## Rubric

1. The fetch/loading/error pattern is extracted once (custom hook such as useFetch<T>, or a reusable component/function) and used for all three resources — no triplicated fetch logic remains
2. Behavior is preserved: three requests still fire on mount, and each section independently shows loading, error, or data (one failing does not blank the others)
3. The extracted hook/function is generically typed (e.g. useFetch<User[]>) and the any[] state types are replaced with concrete interfaces or type parameters — not left as any
4. A cleanup/cancellation guard is added so state is not set after unmount (AbortController or ignore flag in the effect)
5. Non-OK HTTP responses (e.g. 500 with an HTML body) are treated as errors rather than parsed as JSON success
6. Rendering logic per section is either shared or clearly parameterized, and each section still renders the same fields (name, title, label) with stable keys
