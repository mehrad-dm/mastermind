---
name: lint
description: Use to check MasterMind's own instruction files — the kernel, core, skills and agents — for bloat, repeated rules, and contradictions between layers. Fires before a release, after several skills changed, or when the brain feels bloated or self-contradictory. Reports findings with file:line; you approve every change. This lints MasterMind itself, never your project's code — for that, use refactorer.
---

# MasterMind — Lint

Instruction text rots in a specific way: rules accumulate, the same principle gets restated in three
layers, and prohibitions pile up long after the model outgrew needing them. Anthropic removed ~80% of
Claude Code's system prompt with no measured loss, and named the mechanism of harm — accumulated
guardrails produce *conflicting instructions*, so the model spends its reasoning reconciling them
before it can act. This skill finds that drift in MasterMind itself.

**It reports. It never edits.** Every finding comes back as a proposal you approve or reject —
see the guard at the bottom for why that constraint is not negotiable.

## Pass A — deterministic, near-free

**Run the script; don't do this by hand:**

```bash
node scripts/lint-brain.mjs        # add --strict to exit non-zero on high findings
```

Run it from the MasterMind clone. A per-project isolated brain ships no `scripts/` — if that's where you
are, say so and run Pass B alone rather than hand-counting.

Counting is not judgment, so it shouldn't depend on a model remembering to do it — and a hand-count
drifts between runs, which makes two reports incomparable. The script reports every item below, sorted
by severity, with the always-loaded vs on-demand token budget at the top:

- **Negative-framing density** — `never`, `don't`, `do not`, `avoid`, `must not` per file. Flag files
  well above the corpus median. (A negative measurably loads the concept it forbids, so each one should
  be paying for itself.)
- **Cross-layer repetition** — the same normalized sentence in kernel ↔ core ↔ skill ↔ agent. Two layers
  is a smell, three is where contradictions come from.
- **Near-duplicates within a file** — the same rule said twice in different words.
- **Size and budget** — lines and characters per file, split by always-loaded vs on-demand, with a token
  estimate. The always-loaded number is the one that matters.
- **Stale references** — `~/.mastermind/…` paths, and skill/agent names, that no longer exist on disk.

## The six ways instruction text goes bad

Pass A finds candidates; these are the names for what's wrong with them. Use them as the vocabulary in
your findings — a named failure is arguable, "this feels bloated" is not.

| Failure | What it looks like |
| --- | --- |
| **No-op** | A line the model already obeys by default. You pay context to say nothing. |
| **Negation** | *Don't think of an elephant* names the elephant. State the wanted behavior instead. |
| **Sediment** | Stale layers that settled because adding felt safe and removing felt risky. |
| **Sprawl** | One skill quietly grew a second job; the description no longer predicts the body. |
| **Duplication** | The same rule in two layers. Today they agree; after the next edit they won't. |
| **Premature completion** | The text stops before the hard part — "verify it works" with no way to. |

Two budgets are in tension and both are real: **context load** (every always-loaded line is paid on
every turn) and **cognitive load** (a rule nobody can find is a rule nobody follows). Cutting a line
that carries a decision trades one for the other rather than saving anything.

## Match the form to the failure

Before proposing a rewrite, check the line's *shape* against the failure it guards — discipline,
wrong-shaped output, missing knowledge, and wrong default each want a different form, and picking wrong
makes the text worse than silence. The table and the reasoning: `~/.mastermind/skills/levelup/authoring.md`.

## Pass B — judgment, only on what Pass A flagged

**Skip every check the script already cleared.** A rule that returned zero findings has been verified;
re-reading those files by hand spends tokens to reach the same answer. Spend the judgment budget only
where a regex can't reach — whether a description says *when* rather than *what*, whether two layers
truly contradict, whether a guard is load-bearing.

This is the half a script can't do, and it's bounded to the script's output, so it stays cheap.
Expect many flagged files to be *correct as they are* — privacy, impersonation, verification and honesty
guards are exactly where a prohibition belongs, so the files carrying them score high by design. A high
density is a prompt to check, not a verdict to cut.

- **Is the guardrail load-bearing?** Does this rule guard a *demonstrable* failure mode, or is it a
  "never X" the model already handles? Keep the first, propose cutting the second.
- **Is it a real contradiction?** Two layers saying compatible things at different depth is fine —
  a skill mandating what the kernel forbids is not.
- **Derivable or essential?** A gotcha and a non-obvious convention earn their lines; anything the model
  can read off the repo does not.
- **Would the positive form carry the same force?** If yes, propose it with the reason attached.

## Output

1. **A findings report** — per finding: layer, `file:line`, category, severity, a one-line reason, and
   the rule it may be violating.
2. **A proposed diff per finding**, phrased as a suggestion to cut or merge.
3. **The budget line** — always-loaded size before and after, so the net effect is visible.

Order by severity: contradictions first (they actively degrade output), then cross-layer repetition,
then density and size.

## The guard that makes this safe

**Never auto-apply.** The realistic failure of a tool like this is deleting a rule that was holding
something up — reading *"never hand-roll crypto, auth, or date/timezone logic"* as negative-framing
noise and proposing it away. That single class of mistake is worse than every byte this skill could
save, so the human approves each change and the skill never writes to a file itself.

When a finding is borderline, say so and leave it in. A brain that stays slightly too long is
recoverable; a quietly removed guardrail is discovered in production.

## Gotchas

- **Lint checks MasterMind, `refactorer` edits your project.** Different targets, different risk.
- **Measure the always-loaded layer separately.** Trimming an on-demand skill barely moves the cost that
  matters; the kernel is where the budget is real.
- **A drop in the negative count is not the goal** — the goal is that every remaining rule earns its
  line. Report both numbers, and resist optimizing the metric.
