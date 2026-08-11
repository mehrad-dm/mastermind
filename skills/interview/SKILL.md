---
name: interview
description: Use when the ask is ambiguous, the scope is unclear, terms are being used inconsistently, the work spans multiple files, or it will be handed to another session: and whenever the user wants to be interviewed about it: "interview me", "ask me what you need", "question me on this", "tear this PRD/spec/plan apart", "what would kill this?". Symptoms: "make it better", "add the thing", or disagreement about what's in scope. Skip for a clear one-line change.
---

# MasterMind: Interview

A precise spec is cheaper than a wrong build. Time spent making the spec exact pays off more than time
watching the implementation (`~/.mastermind/engineering/core/product-sense.md`, `~/.mastermind/engineering/core/agent-loop.md`). This produces the *what*,
not the code.

## First, say what you think they're asking for

Lead with your reading of the ask and how sure you are: **a wrong guess gets corrected faster than a
blank question gets answered.** One or two lines, then proceed or ask:

```text
Reading it as: a way to see which jobs failed overnight, so the morning starts with a fix not a search.
~70% sure: what I'm missing is whether "failed" includes timeouts.
```

**If you do have to ask: one question at a time, and answer it yourself first.** A batch of questions
hands your job back and makes the user do technical work; asking blind makes them generate an answer
from nothing. Ask the single question that unblocks the next decision, with your recommendation
attached, people correct a wrong guess far faster than they compose an answer:

```text
Q: Should a failed import roll back the whole batch, or keep the rows that parsed?
   I'd keep the good rows and report the failures: a 5,000-row file failing on row 4,900
   is the case people actually hit. Say the word if you'd rather it be all-or-nothing.
```

Look facts up rather than asking for them: the stack, the conventions, what the code already does are
yours to find. Only the *decisions* are theirs.

Two things to catch, because both hide a wrong build behind an apparent agreement:

- **The out-of-scope half.** Most misalignment is silent disagreement about what is *not* being built,
  which is why step 2 below names it explicitly rather than leaving it implied.
- **A hollow yes.** "Whatever you think," "sounds good," and silence are not confirmations; they're
  delegation, politeness, and fatigue. Restate the ask concretely and get a real one, or decide it
  yourself and say plainly that you did.

## Interrogate the ask, when they want to be asked

Say what you think they mean *first*: that stays the default, and it is faster than any interview.
But when the user hands you the wheel: **"interview me"**, "ask me what you need", "question me",
"here's the PRD, tear it apart": switch modes and get everything a build needs before a line is written.

- **One question at a time, each carrying your recommended answer**, so a tired user can say "yes" and
  still get a good decision. Never a numbered list of ten: that hands your job back.
- **Ask only what you cannot resolve yourself.** Anything the repo, the lockfile, or the doc can answer
  is not a question, it is a lookup you skipped.
- **Stop the moment you can write the acceptance criteria.** The interview is not the deliverable; the
  scope is. Five sharp questions is a lot; ten means you are stalling.
- **Aim at what changes the build:** the outcome behind the request · the boundary (what is explicitly
  *not* in this) · the one edge case that decides the data model · what "done" looks like to them ·
  what must not break.

**With a document** ("interview me on this spec/PRD/ticket"), read it in full first, then raise only what
the document itself cannot settle: contradictions between two sections, requirements with no acceptance
criteria, assumptions stated as facts, and the silent gaps: errors, empty states, permissions, migration
of what already exists. Quote the line you are challenging; a challenge without a citation is an opinion.

**The deeper pass: red-team the document (offer it, do not default to it).** For a plan someone will
bet real time or money on:

1. **List the assumptions the plan stands on**: the claims that sink it if false. Usually 3–6.
2. **Steelman before you attack.** State the strongest honest case *for* each first; attacking a weak
   version of the plan proves nothing about the real one.
3. **Attack, then rank** survivors by **impact if wrong × how likely wrong × how cheap to test**. The
   ranking is the deliverable, twelve flat worries are noise wearing rigor's clothes.
4. **For the top 2–3, name the cheapest real test and a kill criterion**: "we believe X; a day of Y
   checks it; if Z happens, X is false and the plan changes." An assumption with no kill criterion is
   a belief, not a plan.

This attacks a *document*, deciding what to build. Attacking a finished claim ("the bug is fixed") is
`double-check`, after the work.

Close the interview by writing the scope contract below and getting one real confirmation. Everything
you noticed but were not asked for goes under **Suggested (not done)**: never folded into the build.

## Write the spec

1. **Problem & outcome**: the real user/business outcome, in one or two lines (not the literal request
   if they differ). *What outcome, for whom, why now?*
2. **Scope**: what's **in**, and explicitly what's **out** (deferred as follow-ups). A coherent slice.
3. **Name the key terms (glossary).** List the domain nouns actually in use; define each in one sentence
   **+ what NOT to call it** (synonyms to avoid); resolve any word that means two things (or two words
   that mean one). One concept, one name: then use these exact names in the spec, types, and code. Names
   are the data model in disguise; muddled naming is a bug waiting to happen.
4. **Interfaces & data**: the files/modules touched, the key types, the API/data contracts.
5. **Acceptance criteria**: observable behavior that means "done," from the user's view (not "compiles").
   Write each one in a shape that already contains its trigger, so QA can execute it without guessing:

   - **When** `<event>`, the system **shall** `<response>`: *when the upload finishes, the row count is shown*
   - **While** `<state>`, the system **shall** `<response>`: *while a sync is running, the button stays disabled*
   - **If** `<failure>`, **then** the system **shall** `<response>`: *if the token expires, then re-auth happens silently once*
   - **Where** `<feature is present>`, the system **shall** `<response>`: for anything behind a flag

   Four sentence shapes, and between them they force the trigger into the criterion. *"Handles errors
   gracefully"* has no trigger and no observable, so nobody can tell you whether it happened.
6. **Edge cases & failure modes**: null/empty/loading/error/many/offline/unauthorized/malformed.
7. **Verification**: the end-to-end check that proves it works.

## Break it into slices that can actually be finished

A slice should fit one working session and be **verifiable on its own**: vertical (a thin path through
every layer) rather than horizontal (a whole layer with nothing to run). Two signals that one is too
big, both cheap to check:

- **You can't state its acceptance in three bullets.** More than that means it's several pieces
  wearing one name.
- **Its title needs an "and".** *"Add the import endpoint and the retry queue"* is two slices; name
  them separately and sequence them.

For anything spanning more than a couple of slices, put a checkpoint between them, the small set of
things that must be true before the next one starts:

```text
Checkpoint after slices 1–3
  · suite green · build clean · one row imports end to end and shows in the UI
  · reviewed with a human before continuing
```

The point is to make "halfway" a real state rather than a feeling, so a wrong direction costs one
slice instead of the whole batch.

## Rules
Decide everything technical yourself; surface only genuine product trade-offs to the user (one line each).
Keep it self-contained: a fresh session should be able to build from it alone.

## Interview vs. the `architect` agent
Spec is the **what**; `architect` (`~/.mastermind/agents/architect.md`) is the **how**. Spec produces the
problem, scope, glossary, acceptance criteria, and edge cases; architect produces module/interface
boundaries, the data model, key types, and the technical decisions behind them.

- Ask is *fuzzy* → run `interview` first. Ask is *clear but the design isn't* → go straight to `architect`.
- **Handoff:** feed the finished spec to `architect` as its input, it restates the problem from the spec's
  scope and acceptance criteria instead of re-deriving them. Non-trivial work usually wants both, in that
  order; a small, well-understood change needs neither.
- Spec's "Interfaces & data" step stays at the level the spec needs (files touched, contracts the
  acceptance criteria depend on). Stop at the *what*; module design is architect's output, not spec's.

## Output
A short `SPEC.md` (or inline): problem, scope, interfaces, acceptance, edge cases, verification. Decisive,
not a menu, the blueprint an implementer follows without second-guessing.
