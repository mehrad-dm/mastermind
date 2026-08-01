---
title: Lint — keeping the brain from quietly getting worse
blurb: What MasterMind does when its own instructions have accumulated — finding the rules that stopped earning their place, and proposing cuts you approve.
---

## The problem this solves

Instruction files decay in a way code doesn't. Nothing breaks. Nothing fails a test. A rule gets added
after a bad day, another one restates it in a different file, a third contradicts it in a corner nobody
re-reads — and the whole thing still *looks* fine. Meanwhile the model reading it is spending its
attention reconciling the contradictions instead of doing the work.

Anthropic measured this on their own product: they deleted roughly 80% of Claude Code's system prompt
with no measurable loss on their coding evaluations, and identified why the bloat hurt — accumulated
guardrails had started conflicting with each other.

**Lint is the pass that finds that drift in MasterMind itself**, before it costs you output quality.

## What goes wrong without it

- **The same rule in three layers.** Kernel, core, and a skill each state it slightly differently. Today
  they agree. After the next edit to one of them, they don't.
- **Prohibitions that outlived their reason.** A "never do X" written for a weaker model, still spending
  context — and still nudging the model toward X, since a negative instruction loads the very concept it
  forbids.
- **An always-on layer that crept.** Depth belongs in files that load on demand. When it leaks into the
  always-loaded kernel, every future session pays for it.
- **References to things that no longer exist.** A path or a skill name that was renamed months ago,
  quietly pointing at nothing.

## How it actually works

Two passes, cheap one first. The **deterministic pass** just counts: negative-framing density per file,
sentences repeated across layers, near-duplicates within a file, size split by always-loaded versus
on-demand, and references that no longer resolve. No judgment, no cost.

The **judgment pass** looks only at what the first pass flagged, which is what keeps it affordable. For
each candidate it asks whether the rule guards a failure mode that's actually been demonstrated, whether
two layers genuinely contradict or merely elaborate, whether a line states something the model could
read off the repo anyway, and whether the positive form would carry the same force.

You get a findings report — layer, file and line, severity, and the one-line reason — plus a proposed
diff for each, ordered with contradictions first because those degrade output the most. It closes with
the number that matters: always-loaded size, before and after.

## The rule it never breaks

**It proposes; you decide. It never edits a file.**

The realistic way a tool like this does damage is by being right about the pattern and wrong about the
instance — reading *"never hand-roll crypto, auth, or date/timezone logic"* as negative-framing noise and
tidying it away. One such deletion costs more than every byte the skill could ever save. So findings come
back as suggestions, borderline calls are left standing and flagged as borderline, and nothing changes
without you.

## When it fires

> *"the brain feels bloated"*
> *"check MasterMind for contradictions before I release"*
> *"is anything in here repeating itself?"*

```
🧠 MasterMind ▸ checking my own instructions for drift
   └ lint · count → judge the flagged → propose, never apply
```

## When it does *not* fire

- **Restructuring your project's code** — that's `refactorer`. Lint only ever looks at MasterMind.
- **Adding knowledge** — that's `levelup`. This pass removes and merges; it never writes new guidance.
- **A quick edit to one skill.** This is a periodic sweep, not something to run on every change.

## What you get

An honest inventory of what your brain is spending context on, which rules stopped earning their place,
and where two layers have started to disagree — with the cuts written out for you to approve, and the
uncertain ones left alone on purpose.
