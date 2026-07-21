# Authoring a new skill

Reference for `levelup` — read this only when adding or rewriting a skill or agent.

The library grows freely: add a skill for any distinct, useful workflow. But hold the quality bar that
keeps a large library lean and navigable (the lesson from the best skill kits).

## The bar

- **One job.** The mega-skill (commits + PRs + changelog + …) is the top mistake. Split it.
- **Description = a routing rule** — specific enough that it activates at exactly the right moment, and
  not otherwise. **Unambiguous:** if a human can't say which skill applies, neither can the agent.
- **Phrase `route_when` / the description as the *question the user would actually ask*, in their words** —
  not a topic label. The router matches by meaning, so `"why is this slow?"` routes far better than
  `"performance optimization"`. A knowledge file is only as findable as the question written on its front
  (the KB lesson) — lead with the real trigger, and freshen it in `refresh` when the way people ask shifts.
- **The description says WHEN, never WHAT.** State only the triggering conditions. **Never summarize the
  skill's own steps or workflow** — a description that describes the process becomes a shortcut the model
  takes *instead of* reading the skill, and the body turns into documentation it skips. (Measured: a
  description saying "code review between tasks" made an agent run *one* review where the body specified
  two. Removing the summary fixed it.) Symptoms, situations, and the user's real words — not a procedure.
- **Name actions, not tools.** Write "dispatch a subagent", "read the file", "run the check" — never a
  specific tool's name. This one rule is why the same skill body runs unedited on Claude Code, Codex,
  Cursor, Gemini, and plain chat. Tool vocabulary belongs in the per-tool wiring, never in a skill.
- **Only what pushes away from defaults.** Don't restate what the model already does well; the
  highest-signal part is a **Gotchas** section — the failure points it hits *without* the skill. (Anthropic.)
- **Lean body, detail on demand** — core instructions fit on a phone screen; push edge cases and reference
  material into companion files next to `SKILL.md` that load only when needed. **Point, never restate:**
  the body names the companion and when to read it; the companion holds the detail, once.
- **Don't duplicate an agent** — review, architecture, refactor, adopt-decisions are agents (isolated
  context). Skills are for inline workflows.
- **Deterministic work → deterministic code** (`~/.mastermind/engineering/core/agent-loop.md`) — script it,
  don't narrate it.
- Mark **user-invoked** (`disable-model-invocation: true`) vs model-invoked, and add the skill to
  `skills/README.md` so the index stays honest.

## Prove the skill changes behavior (watch it fail first)

A skill that reads well but changes nothing is worse than no skill — it costs tokens and buys confidence
you haven't earned. So test it the way you'd test code: **red first.**

1. **Write the scenario** — a concrete task that should trigger the skill.
2. **Run it WITHOUT the skill** (a fresh subagent, no skill loaded) and **write down exactly how it goes
   wrong** — the specific shortcuts and excuses it reaches for. This is your red.
3. **Write the skill against *those* failures** — not against imagined ones.
4. **Run the scenario again with the skill** and confirm the behavior actually changed. Green.
5. **Look for the next loophole**, close it, re-run.

> **If you never watched an agent fail without the skill, you don't know whether the skill teaches the
> right thing.** Do this for any skill meant to enforce a discipline (verification, review, honesty
> gates); skip it for pure reference material, which has nothing to enforce.

## Before you call it done

A new skill directory is a structural change, not just a file: it must ship `SKILL.md` **and** `ABOUT.md`
(the human-facing article the site's library page is generated from), and be registered in
`skills/README.md`, the root `README.md` menu, and the kernel's inlined menu. Then run
`node scripts/check-integrity.mjs`, `node scripts/build-router.mjs`, and `node scripts/build-library.mjs`
— the integrity check fails if any index still lies about what ships.
