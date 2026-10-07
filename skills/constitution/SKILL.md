---
name: constitution
description: Use when a project needs rules every feature must obey, or those rules change: "set up our principles", "write a constitution", "these are our non-negotiables", "from now on every feature must...", "we never allow X in this codebase", "amend the rules", starting spec-first work on a project with no specs/constitution.md. Not for MasterMind's own engineering defaults, and not for one feature's requirements (that's `specify`).
---

# MasterMind: Constitution

A constitution is the short list of rules this project refuses to break, written so a reviewer can
check a change against each one. It outranks every spec, plan and task (`~/.mastermind/engineering/core/spec-driven.md`).
Request: **$ARGUMENTS**.

## Write it

1. **Read what the project already says.** README, CI config, lint and type settings, `.mastermind/brief.md`,
   existing `specs/`. Rules the repo already enforces are facts to record, not questions to ask.
2. **Start from the template.** Use `specs/.templates/constitution.md` if it exists, else
   [`template.md`](template.md) beside this file. Write to `specs/constitution.md`.
3. **Draft at most seven principles.** One is enough when the project has one rule. Each is a name, a few
   `MUST` or `MUST NOT` statements, and one line of rationale. More than seven means some are preferences.
4. **Ask only for what the repo cannot tell you.** One question at a time, each with your recommended
   answer (`interview`). Privacy stance, compliance, and what the product will never do are the usual ones.
5. **Leave no placeholder behind.** A value nobody knows yet stays as `TODO(<what>): <why it is unknown>`
   and is listed in your report.

## Amend it

- **Version every change** in the footer line, semver:
  - MAJOR: a principle is removed or redefined so that old work may now violate it.
  - MINOR: a principle or section is added, or its guidance materially widens.
  - PATCH: wording, typos, clarifications that change no obligation.
- **Record the amendment** as a comment block at the top of the file: the version change, what changed
  and why, the date, and who decided it.
- **Ripple the change.** List every living doc, open spec, plan and template that now conflicts with the
  new rule. Update each one, or name it in the comment block as pending, with the reason.

## Write rules a reviewer can check

```text
Weak:   Code should be well tested.
Strong: Money arithmetic MUST have a failing test written before the code that makes it pass.
        Rationale: rounding bugs in payouts are invisible until a customer finds them.
```

A rule nobody can check produces an argument in every review. `SHOULD` is allowed only with the
condition under which it may be skipped, stated in the same line.

## Gotchas

- **Do not copy MasterMind's defaults in.** "Verify before done" and "no lazy placeholders" already hold
  everywhere. The constitution carries what is true of *this* project only.
- **Do not let a feature request sneak in.** "We need dark mode" is a spec. "Our surfaces are dark only"
  is a rule. Requests that arrive here go to `specify`, named in your report as deferred.
- **The constitution never edits code.** Amending a rule that existing code now breaks produces findings
  for `converge`, not a silent refactor.
- **A team's rules are the team's decision.** An unconfirmed draft is version 0.1.0. It becomes 1.0.0 on
  one real confirmation. A rule the user never agreed to is a rule they will route around.
- **Record who proposed each rule.** A `MUST` you added beyond what the user said is marked as your
  proposal in the amendment block until they confirm it. Never credit the user with your extension.
- **A gate that passes with nothing to check is hollow.** "The test suite MUST be green" holds with zero
  tests. Name the behavior that must be proven, or require the suite to cover it.

## Report

The version (old → new), the principles added, changed or removed, the documents rippled or still
pending, and any `TODO` left open.
