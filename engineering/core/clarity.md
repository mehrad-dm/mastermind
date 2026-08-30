# Clarity: writing the reader can act on

Read this when you are about to explain something, when a reader says they did not follow, or when you
are authoring a skill, an agent brief, or an error message.

The reader is rarely a native speaker of your dialect. They may not be an engineer. Sometimes they are
a machine parsing an instruction with nobody to ask. Aerospace hit this in the 1980s: mechanics were
misreading safety-critical repair steps, and the industry answered with a controlled language,
ASD-STE100 Simplified Technical English. Its current issue is 53 writing rules and a dictionary of
about 900 approved words, one meaning per word.

We follow the discipline, not the certification. The standard is free to obtain from ASD and **not
free to redistribute**, so nothing here reproduces its dictionary or its rules verbatim. Say
"STE-informed" and never "STE-compliant".

## The rules that carry the weight

1. **One instruction per sentence.** Two verbs joined by "and" is two steps; split them.
2. **Short sentences.** Aim under twenty words in anything procedural.
3. **Active voice, simple tense.** "The installer writes the file", not "the file will have been written".
4. **One meaning per term.** Pick the word and keep it. Do not elegantly vary "brain", "kernel" and
   "instructions" for the same thing.
5. **No stacked nouns.** Three nouns in a row hide which one acts on which: "project field pack path".
6. **No hedging in a directive.** "Should", "consider", "where possible" and "try to" reopen a decision
   you meant to close. State the rule, then state the exception concretely, or drop the rule.
7. **Nothing dropped.** Keep the article and the relative pronoun. "The file you edit" beats "file edited".
8. **Plainest word that is still exact.** Never trade precision for simplicity: cut the decoration, keep
   the qualifier. If a fact has a condition, the condition survives.

## Two registers, and the difference matters

**Strict** for anything parsed without a human present: skill bodies, agent briefs, tool descriptions,
error messages, commit messages, the announce line. Every rule above applies.

**Plain** for prose to the user: explanations, reports, the reasoning behind a decision. Keep the
sentence discipline and drop the vocabulary restriction. A person reading an explanation can ask a
follow-up; a machine reading an instruction cannot.

## What this is not

Not a rule for how the user writes to you. They talk however they like and you work out the intent:
that is the first prime directive, and constraining their input would break it. This governs what
**you** write.
