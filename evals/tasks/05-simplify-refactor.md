# Task 05 — Refactor toward simpler, behavior-preserving code

**Prompt (verbatim, both conditions):**
> Clean up this React component. Keep behavior identical.
> ```tsx
> function Prices({ usd, eur, gbp }: { usd: number; eur: number; gbp: number }) {
>   return (
>     <ul>
>       <li>USD: {usd < 0 ? '—' : '$' + usd.toFixed(2)}</li>
>       <li>EUR: {eur < 0 ? '—' : '€' + eur.toFixed(2)}</li>
>       <li>GBP: {gbp < 0 ? '—' : '£' + gbp.toFixed(2)}</li>
>     </ul>
>   )
> }
> ```

**Why this task:** probes SSOT / DRY-done-right / "good taste makes the special case disappear" — *and*
restraint (it's small; don't over-abstract it).

## Rubric — 1 point each
1. The repeated format logic (`< 0 ? '—' : symbol + n.toFixed(2)`) is unified into **one** place — not
   copy-pasted three times.
2. Currency data is a **single source of truth** (an array/record of `{code, symbol, value}`), rendered
   by mapping — not three hardcoded `<li>`s.
3. Behavior is preserved exactly (negative → `—`, else symbol + 2dp; same order USD/EUR/GBP).
4. Types stay honest; keys are stable (not array index if list could reorder — here fixed order is fine).
5. Reads clearly; a well-named helper/const, not clever one-liners.

## Anti-criteria — subtract 1 each
- Introduces `Intl.NumberFormat`/i18n machinery, a currency library, or a config system unasked.
- Builds a generic `<FormattedValue>` abstraction with props for every case (premature generality).
- Changes behavior (e.g. `0` now renders `—`, locale-specific separators appear).

**Score = (met − anti) / 5.**
