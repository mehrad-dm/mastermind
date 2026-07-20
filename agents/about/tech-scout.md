---
title: Tech scout — adopt it, or build it yourself
blurb: How MasterMind decides whether to bring in an outside tool or write the few lines you own, and why the answer comes back as a verdict rather than a list.
---

## The problem this solves

Every project runs into the same fork constantly. There's a piece of functionality you need — dates,
charts, forms, payments, authentication — and you can either pull in something someone else built, or
write it yourself. Both choices are defensible. Both have a bad version.

Pull in too much and your project becomes a pile of other people's decisions: dependencies that break on
upgrade, packages that get abandoned, security advisories in code you never read. Write too much yourself
and you spend three weeks rebuilding, badly, something a well-maintained library already got right.

Asking an AI cold makes this worse, not better. It will recommend whatever was popular when it was
trained, describe features that shipped in a version from two years ago, and speak with total confidence
about a project that was abandoned last spring.

**Tech scout is the discipline that turns this into a checked, evidence-backed decision.**

## What goes wrong without it

- **Adopting from memory.** A recommendation based on what was popular a while ago, not what is healthy
  now. Popularity and health are different things, and only one of them is checkable.
- **Believing the marketing.** Landing pages and star counts describe how a project wants to be seen. The
  commit history, open issues and release cadence describe what it actually is.
- **Never considering building it.** Some problems are genuinely twenty lines you understand completely.
  Reaching for a dependency there buys you a permanent maintenance obligation to avoid an afternoon.
- **A survey instead of an answer.** Five options with pros and cons for each, and the decision handed
  back to you. That's the work, not the deliverable.

## How it actually works

Tech scout is an **agent**, not a skill. A skill is guidance the main conversation follows; an agent runs
in its own **isolated context window**, seeing only the question it was handed. It doesn't inherit any
enthusiasm already expressed in the chat, or a tool someone mentioned three messages ago. That isolation
keeps the recommendation from being a reflection of the conversation's momentum — it starts from the
constraints and the evidence, not from what everyone had already half-decided.

It starts by checking whether a sensible default is already documented for this kind of work — often the
decision was made once and doesn't need remaking. Then each candidate goes through the same test.

**Fit** — does it actually solve *this* problem under *these* constraints? A great tool for the wrong
problem is the wrong tool. **Health** — is it maintained? Release cadence, the ratio of open issues to
resolved ones, the last commit, how many people could keep it alive. This gets verified against the real
repository and package registry, never a landing page. **Longevity** — real adoption, credible
alternatives, and an honest guess at whether it will exist in three years. **Cost** — not just size, but
the ongoing cost of owning it. **Security and license** — known advisories, supply-chain exposure,
compatibility with how you're distributing your work.

And running through all of it, the baseline candidate that gets forgotten: **build it yourself.** Is a few
lines you own and fully understand cheaper and safer than the dependency? Sometimes the best library is
none.

## When it fires

> *"should I use a library for this or just write it?"*
> *"what's the best way to handle payments in this app?"*
> *"is this package still maintained? should I switch?"*
> *"everyone says to use X — is that right for us?"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ tech-scout · fit → health → cost → vs. build it → verdict
```

## When it does *not* fire

- **When the tool is already chosen and you need to understand it** — that's the `learn` skill. This is
  the distinction people mix up. Tech scout answers *should we use this?* and hands back a decision.
  Learn answers *how does this work?* and teaches you the thing, reading the current documentation so the
  next step is grounded in fact rather than half-memory. Deciding then learning is a normal sequence;
  they're just different jobs.
- **When you want a broad written report** on a subject — that's deeper research. Tech scout is
  deliberately narrow: one bounded question, one answer.
- **When the real question is whether an approach will work at all** — build a rough throwaway and find
  out. That's a `spike`.

## What you get

A verdict. The recommended choice — or "build it" — with a one-line reason, the runner-up and the
circumstance that would flip you to it, and the risks that actually carry weight. Every claim about
activity, downloads or advisories is checked with tools rather than asserted, and the assumptions behind
the recommendation are stated so you can tell when it stops applying.
