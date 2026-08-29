# Project brief

What this project actually is, so an agent stops making changes that are technically correct and
operationally wrong. `init` fills this in. Keep it under about 40 lines: it is read often, so every
line is paid for on every session. Delete a line before you add a fortieth.

## What this is

<one or two sentences: what it does, and for whom>

## Words we use here

The terms this codebase uses for its own ideas, so nobody re-explains them or invents a synonym.

- `<term>`: <what it means here, not in general>

## What breaks, and who feels it

- <the thing that goes down, and who notices first>

## Irreversible here

Anything that cannot be undone: a migration, a published artifact, a paid call, a customer email.
These need asking before doing, every time.

- <action>: <why it cannot be taken back>

## How it ships

<the deploy path in one line, and what gates it>

---

Add a decision only when writing it down would stop the same suggestion coming back. Everything else
belongs in the changelog or the pull request.
