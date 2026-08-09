# Authoring a new skill

> **Paths here are relative to the MasterMind repo** — authoring happens upstream. This file
> ships inside project brains too; there, the generators live under `.mastermind/scripts/`
> (router and integrity only).

Reference for `levelup`: read this only when adding or rewriting a skill or agent.

The library grows freely: add a skill for any distinct, useful workflow. But hold the quality bar that
keeps a large library lean and navigable (the lesson from the best skill kits).

## The bar

- **One job.** The mega-skill (commits + PRs + changelog + …) is the top mistake. Split it.
- **Description = a routing rule**: specific enough that it activates at exactly the right moment, and
  not otherwise. **Unambiguous:** if a human can't say which skill applies, neither can the agent.
- **Phrase `route_when` / the description as the *question the user would actually ask*, in their words**,
  not a topic label. The router matches by meaning, so `"why is this slow?"` routes far better than
  `"performance optimization"`. A knowledge file is only as findable as the question written on its front
  (the KB lesson): lead with the real trigger, and freshen it in `refresh` when the way people ask shifts.
- **The description says WHEN, never WHAT.** State only the triggering conditions. **Never summarize the
  skill's own steps or workflow**: a description that describes the process becomes a shortcut the model
  takes *instead of* reading the skill, and the body turns into documentation it skips. (Measured: a
  description saying "code review between tasks" made an agent run *one* review where the body specified
  two. Removing the summary fixed it.) Symptoms, situations, and the user's real words: not a procedure.
- **Name actions, not tools.** Write "dispatch a subagent", "read the file", "run the check", never a
  specific tool's name. This one rule is why the same skill body runs unedited wherever the brain is
  loaded: a skill that says `WebSearch` breaks on the first tool that calls it something else. Tool
  vocabulary belongs in the per-tool wiring, never in a skill.
- **Only what pushes away from defaults.** Don't restate what the model already does well; the
  highest-signal part is a **Gotchas** section, the failure points it hits *without* the skill. (Anthropic.)
- **Lean body, detail on demand**: core instructions fit on a phone screen; push edge cases and reference
  material into companion files next to `SKILL.md` that load only when needed. **Point, never restate:**
  the body names the companion and when to read it; the companion holds the detail, once.
- **Don't duplicate an agent**: review, architecture, refactor, adopt-decisions are agents (isolated
  context). Skills are for inline workflows.
- **Deterministic work → deterministic code** (`~/.mastermind/engineering/core/agent-loop.md`): script it,
  don't narrate it.
- Mark **user-invoked** (`disable-model-invocation: true`) vs model-invoked, and add the skill to
  `skills/README.md` so the index stays honest.

## Match the form to the failure

Before you write a line, work out which failure it guards: the right *shape* differs per failure, and
picking wrong makes the text worse than saying nothing:

| The failure | The form that works |
| --- | --- |
| **Discipline**: it knows the right move and skips it under pressure | A flat prohibition **plus the excuse it defeats**. This is the one place a negative earns its keep. |
| **Wrong-shaped output**: it produces the wrong kind of thing | A **positive recipe**: show the shape you want. Head-to-head wording tests found the prohibition arm produced *more* of the unwanted content than the recipe arm: and worse than the no-guidance control. |
| **Missing knowledge**: it can't know this from the repo | A plain statement of fact, no exhortation. |
| **Wrong default**: it reaches for the common option, not the right one | State the default, then the condition that overrides it. |

So *"never fabricate a check you didn't run"* is correctly a prohibition. That's discipline under
pressure. *"Don't write bullet points"* is the failing form; *"write in flowing prose"* is the fix.
Converting the first kind to positive framing weakens a real guard; leaving the second kind negative
actively summons what it forbids.

**No nuance clauses, no exemption clauses.** *"Don't do X unless it matters"* reopens the negotiation the
rule existed to close, and the exemption is the door every rationalization walks through. If a rule has a
real exception, name that exception concretely, or drop the rule.

## Prove the skill changes behavior (watch it fail first)

A skill that reads well but changes nothing is worse than no skill, it costs tokens and buys confidence
you haven't earned. So test it the way you'd test code: **red first.**

1. **Write the scenario**: a concrete task that should trigger the skill.
2. **Run the no-guidance control first**: a fresh subagent, no skill loaded. **If it already does the
   right thing, stop and don't author the line.** Guidance for a failure that doesn't occur is a no-op
   billed to context on every future session; that check is what separates a rule from a superstition.
3. **Mine the failure verbatim.** When it does go wrong, copy the *exact* excuses and rationalizations it
   produced: its sentences, not your paraphrase: and write the skill against those. A skill written
   against imagined failure closes imagined loopholes.
4. **Run the scenario again with the skill** and confirm the behavior actually changed. Green.
5. **Re-run the same wording several times.** Five runs, five readings means the wording isn't binding
   yet. That is a defect in the text, not noise in the model. Rewrite until the runs converge.
6. **Meta-test whatever didn't take.** When a run still goes wrong with the skill loaded, ask that agent:
   *"how could this instruction have been written so the right option was obviously the only one?"* The
   answer sorts the cause: the text was unclear, it was incomplete, or it was never read: and each of
   those takes a different repair.
7. **Look for the next loophole**, close it, re-run.

> **If you never watched an agent fail without the skill, you don't know whether the skill teaches the
> right thing.** Do this for any skill meant to enforce a discipline (verification, review, honesty
> gates); skip it for pure reference material, which has nothing to enforce.

**Keep the failing scenario.** The scenario that proved the skill was needed is the skill's regression
test: store it (a `pressure/` note beside the skill, or the eval task it became) so the next editor
can re-run it after rewording. A behaviour rule whose original failure can't be replayed drifts into
folklore, and folklore gets deleted by the next cleanup.

## Test the trigger, not just the body

A skill that never fires is worse than no skill: a perfect body that never gets read changes nothing.
So test the description the way you tested the body: run it against ~20 realistic queries, phrased the
way people actually ask.

Half the value is in the **negatives**: near-miss queries that must *not* route here: the neighbouring
skill's job, the same words in a different context, the one-line change this skill is meant to skip. A
negative that's obviously irrelevant tests nothing. And **hold a few queries back**, so you aren't
tuning on the same set you measure on.

## Before you call it done

A new skill directory is a structural change, not just a file: it must ship `SKILL.md` **and** `ABOUT.md`
(the human-facing article the site's library page is generated from), and be registered in
`skills/README.md`, the root `README.md` menu, and the kernel's inlined menu. Then run
`node scripts/check-integrity.mjs`, `node scripts/build-router.mjs`, and `node scripts/build-library.mjs`
the integrity check fails if any index still lies about what ships.
