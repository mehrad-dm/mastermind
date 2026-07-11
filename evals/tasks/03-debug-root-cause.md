# Task 03 — Diagnose a slow re-render (root cause, not symptom)

**Prompt (verbatim, both conditions):** paste this code and ask:
> This list feels sluggish when you type in the filter box. Why, and what's the right fix?
>
> ```tsx
> function Page() {
>   const [q, setQ] = useState('')
>   const items = useMemo(() => hugeList.filter(x => x.includes(q)), [q])
>   return (
>     <>
>       <input value={q} onChange={e => setQ(e.target.value)} />
>       <ExpensiveSidebar />        {/* re-renders on every keystroke */}
>       <List items={items} />
>     </>
>   )
> }
> ```

**Why this task:** tests evidence-driven debugging vs. reflexive `memo()` sprinkling.

## Rubric — 1 point each
1. Identifies the **actual** cause: `ExpensiveSidebar` re-renders on every keystroke because it's a
   sibling under the component that owns `q` — not the filtering itself.
2. Proposes a **structural** fix (move the input+state into a small child, or lift `ExpensiveSidebar`
   out as `children`) — the "move state down / lift content up" pattern.
3. Does **not** reach first for `React.memo(ExpensiveSidebar)` as *the* answer, or notes it's the
   weaker/patch fix vs. the structural one.
4. Reasoning is mechanism-level ("X re-renders because Y"), not vibes.
5. Doesn't introduce incorrect claims (e.g. blaming the `useMemo`, which is already correct here).

## Anti-criteria — subtract 1 each
- Wraps everything in `memo`/`useCallback` reflexively.
- Suggests a virtualization library / state manager for a problem that's pure component structure.

**Score = (met − anti) / 5.**
