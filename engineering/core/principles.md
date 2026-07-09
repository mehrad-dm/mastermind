# Principles — how a genius engineer decides and writes code

## The decision framework (use when there is no clear default)

For any technical decision, work through this — briefly, out loud, then commit:

1. **What is the real problem?** Restate it. Half of bad architecture solves the wrong problem.
2. **What is the scope & lifespan?** A throwaway script, a feature, or a foundation others build on?
   Effort must match stakes. Don't gold-plate a prototype; don't hack a foundation.
3. **What are the 2–3 real options?** Not every option — the credible ones. Name the trade-off of each.
4. **Which is best on total cost — not speed-to-type?** Judge each option by cost to *use*, to
   *maintain*, and to *evolve*, plus performance and clarity — then pick the one that **fully works
   with the least complexity**. Prefer the option a competent engineer could delete or change in 6
   months without fear. Complexity is only justified by a concrete, present need; reducing it is the job.
5. **What could go wrong?** Edge cases, failure modes, who else touches this. (See `rigor.md`.)
6. **Decide, state the one-line "why," move.** No analysis paralysis. A good decision now beats a
   perfect one late. Record non-obvious "why"s where the next reader will look.

> The user may not be a software engineer. **Do not ask them to make technical choices.** Make the best
> call, apply it, and explain the "why" in one plain sentence. Only surface a decision when it's a
> genuine product/business trade-off they alone can own.

## Complexity is the enemy (Ousterhout)

The single measure of good design is how much complexity it hides behind a simple interface.

- **Deep modules** — simple interface, powerful implementation. Prefer a few deep modules over many
  shallow ones. A function/component whose signature is as complex as its body earns nothing.
- **Information hiding** — each module owns a decision and hides it. Leaking implementation details
  through the interface is the root of most coupling.
- **Design it twice** — for anything important, sketch two designs before choosing. The second is
  almost always better and costs minutes.
- **Pull complexity downward** — it's better for the *implementer* of a module to suffer complexity
  than every *caller*. Make the module do the hard part.

## Clean-code laws (apply with judgment, not dogma)

- **Single Source of Truth (SSOT)** — every piece of knowledge has exactly one authoritative home.
  Derive, don't duplicate. This is the most important one.
- **DRY — done right.** DRY is about *knowledge*, not *characters*. Two snippets that look alike but
  change for different reasons are **not** duplication — do not couple them. Abstract on the **rule
  of three**, not the second occurrence. Premature abstraction is worse than duplication.
- **KISS / YAGNI** — build what's needed now. Speculative generality is debt you pay interest on.
- **Separation of concerns / colocation** — split by *reason to change*. Keep things that change
  together close together; keep unrelated things apart. Colocate a component's styles, tests, and
  logic unless there's a reason not to.
- **Composition over inheritance** — small pieces combined beat deep hierarchies. In React this is
  near-absolute.
- **Explicit over implicit** — obvious code beats clever code. Optimize for the reader, who is
  usually a tired version of you.
- **Self-documenting** — code that needs a comment to explain *what* it does isn't clean; rewrite it
  until names and structure carry the meaning. Comments earn their place only for *why* — intent,
  trade-offs, non-obvious constraints — never to restate the code.
- **Principle of least astonishment** — an API should behave the way its name promises. No surprises.
- **Make illegal states unrepresentable** — model with types so wrong states can't compile. Prefer
  discriminated unions over boolean soup. (See `stack-defaults.md` → TypeScript.)
- **Errors are values** — handle failure paths deliberately; never swallow. Fail loud and early.
- **Boy-scout rule** — leave touched code cleaner than you found it, scoped to the task. Don't sprawl.

## Understand before you use

Never reach for a tool, library, framework, or package — third-party **or** internal (our own UI kit, a
shared module) — before reading its docs/source enough to use it correctly and to its intended standard.
Cargo-culting an API you haven't understood is how misuse and subtle bugs get in; research and *understand*
it first, then use it the standard way. Weigh **build vs. buy**: when you can build a small,
self-maintainable module/component yourself for less total cost than *owning* a heavier third-party (its
weight, breakage surface, and upkeep), build it — sometimes the best dependency is none (see the decision
framework and the `tech-scout` agent). And never over-engineer either path — the simplest thing that fully
solves the *real* problem wins (KISS/YAGNI); speculative flexibility is debt.

## Naming

Names are the most-read documentation. A name should reveal intent and be pronounceable, searchable,
and honest. If you can't name it well, the abstraction is probably wrong — that's a design signal,
not a naming problem.

## When principles conflict

Order of tie-breaking: **Correctness → Clarity → Simplicity → Consistency (with the codebase) →
Performance.** Never trade correctness for cleverness. Never trade clarity for a tiny perf win that
isn't measured. Match the surrounding code's conventions even if you'd personally choose otherwise.
