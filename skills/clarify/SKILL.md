---
name: clarify
description: Use the moment the user signals your last answer did not land: "I did not follow that", "I don't understand", "say it simply", "simpler please", "more simply", "you lost me", "what does that mean", "too long", "explain again", "show me", a confused question repeating something you already answered. Re-pitch what you just said, in plain words or as a picture. Not for a new question, and not for documenting a package: that is explain.
---

# MasterMind: Clarify

Your last answer failed. That is the fact to accept before writing anything else. Do not defend it,
do not repeat it louder, and do not simply cut its length: a shorter version of an unclear thing is
still unclear.

Read `~/.mastermind/engineering/core/clarity.md` for the register. Use the project's own terms from
`.mastermind/brief.md` if it exists.

## Work out what actually failed

One of four things went wrong. The repair differs for each, so name it before you rewrite.

| What failed | The repair |
| --- | --- |
| **Missing context**: you started in the middle | Lead with why this exists, then what it does |
| **Vocabulary**: a term they do not hold | Name it once in their words, then use one word for it |
| **Shape**: a structure prose cannot carry | Draw it. See below |
| **Volume**: correct, and too much at once | One claim, then stop and ask what they want next |

## Two forms. Pick, do not offer a menu

**Words.** Lead with the point. Short sentences, active voice, one instruction each, no hedging. State
what you would do and why, in the order they need it, not the order you discovered it.

**A picture**, when the thing has a shape: how parts connect, what calls what, what changed, what a
sequence does, what the data looks like. Reach for the lightest form that carries it:

- a **file layout**: a shallow tree, one line of responsibility per entry, for where things live
- a **call stack**: an indented call tree, for what happens in what order
- a **component tree**: the same for a UI, keeping the state and the boundaries, dropping the rest
- **types and signatures**: the shape of the data, which is often the whole answer
- **pseudocode**: for an algorithm, where real code carries noise the reader does not need
- a **table**: for a comparison or a set of options
- a **diff**, and not only of code: mark a call tree, a file layout or a state machine with `+` and
  `-` to show a change against a shape the reader already holds
- a **mermaid diagram**: state and sequence diagrams, only when the relationships genuinely need one

Plain text beats a rendered diagram: it works in every terminal and every tool, and it is faster to
read. Reach for HTML only when the user asks for it.

**Then stop.** End with one short question that finds the next gap: *"is it the X part or the Y part?"*
A second wall of text is the same failure again.

## Close the loop

Each time this fires you have found a place MasterMind writes badly, and that is worth more than the
one repair. When the trigger was your own writing rather than a genuinely hard subject, add a line to the
brain's own `.mastermind/journal.md`, the file `mastermind wrong-log` reads: what you said, what did
not land, and the shorter form that worked.

## Gotchas

- **Do not fire on a new question.** "What does that mean" about *your last answer* is this skill.
  "What does CORS mean" is a question: answer it.
- **Do not lose a qualifier while simplifying.** Dropping "only on the first install" makes a sentence
  shorter and wrong. Cut decoration, never conditions.
- **Do not restate the same structure in fewer words.** If the first attempt was prose, the second one
  probably should not be.
- **Never say "as I said above".** They read it. It did not work.
