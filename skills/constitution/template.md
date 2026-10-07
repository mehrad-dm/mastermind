<!--
Amendments (newest first)
- <old> → <new> · <YYYY-MM-DD> · <who decided> · <what changed and why>
  Rippled: <docs updated> · Pending: <docs not yet updated, and why>
-->
# <Project> constitution

The rules every change to this project is checked against. Specs, plans, tasks and code all yield to
this file. Amend it on purpose, never by drift.

## Principles

### I. <Short name>

- <Subject> MUST <observable behavior>.
- <Subject> MUST NOT <observable behavior>.

Rationale: <the cost of breaking it, in one line>.

### II. <Short name>

- <Subject> MUST <observable behavior>.

Rationale: <one line>.

## Constraints

<Hard limits that are not principles: required platforms, compliance regimes, budgets such as bundle
size or latency, data residency. Each one measurable.>

## How work is checked

<The gates a change passes before it merges: the commands that must be green, who reviews, what counts
as done here. Point to CI rather than copying it.>

## Governance

- This file outranks every spec, plan and task in `specs/`.
- A change to it bumps the version below and adds an entry to the amendment block at the top.
- MAJOR removes or redefines a principle. MINOR adds or widens one. PATCH changes no obligation.

**Version** <0.1.0> · **Ratified** <YYYY-MM-DD> · **Last amended** <YYYY-MM-DD>
