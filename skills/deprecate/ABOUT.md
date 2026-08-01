---
title: Deprecate — removing things without breaking whatever still uses them
blurb: What MasterMind does when the job is to delete, retire, or move everyone off something — the one kind of change that often has no undo.
---

## The problem this solves

Software grows by addition. Everyone — every person, every AI — knows what to do when something needs
building. Almost nobody has a routine for taking something away.

So things don't get taken away. The old endpoint stays. The renamed column keeps its predecessor around.
The feature flag from two years ago is still there, still branching, still something every future change
has to not break. A system's real size isn't what it does — it's everything it still supports, and that
number only ever goes up unless someone deliberately brings it down.

The reason people avoid it isn't difficulty. It's that the cost of being wrong is lopsided. Building the
wrong feature wastes a week. Deleting something that was still in use takes production down, or corrupts
data that has no revert. Faced with that asymmetry, the rational move is to leave everything where it is
— which is exactly how systems become impossible to change.

**Deprecate is the routine that makes removal safe enough to actually do.**

## What goes wrong without it

- **The big-bang delete.** Search for the name, find nothing, delete it. What actually got searched was
  one spelling, in one repository. The name assembled from a string at runtime, the config key, the
  client another team maintains, the dashboard query — none of those turn up, and all of them break.
- **Deleting during a deploy.** For the minutes a rolling deploy takes, the old code and the new code are
  both running. Anything removed in the same release that stopped using it gets used by a server that
  hasn't restarted yet.
- **The notice that *is* the plan.** A deprecation warning ships, and the actual migration becomes
  everyone else's problem. Nothing moves. The warning is ignored, correctly — nothing happens to anyone
  who ignores it.
- **Zombies.** Code with no owner but real live traffic. It can't be deleted, because nobody can say
  what depends on it; it can't be improved, because nobody owns it. It just sits there accumulating,
  and it is where most of the rot in an old system lives.

## How it actually works

The core move is to stop treating removal as one event. Almost nothing risky can be removed atomically,
so MasterMind splits it into three phases that each ship separately: **expand, migrate, contract.**

*Expand* means adding the new thing next to the old one, with both working. Nothing has been taken away
yet, so nothing can break; if the work stops here, the system is merely slightly redundant.

*Migrate* means moving the things that use the old one across, in batches sized by what happens if a
batch is wrong. If a mistake wakes someone at 3am, the batch is one caller. If it doesn't, the batch can
be a whole service. Each batch is verified before the next one starts, so a wrong assumption costs one
batch instead of everything.

*Contract* is the deletion — and it happens last, after the rollback window has passed, because until
then the old path is how you get back.

Renaming a database column on a live system is the clean illustration: add the new column and write to
both, switch reads over, move every caller, stop writing the old one, and only then drop it. Five
deploys, each reversible on its own. Collapse any two of them and you have an outage.

Underneath the phases sit four rules that decide whether the removal is real.

**Prove it's unused; don't assert it.** "Nothing references this" is a claim about an entire system, and
the search that usually backs it only covers one way of writing the name in one place. When proof from
the outside isn't available, MasterMind adds a counter to the old path, waits a real interval — long
enough to include the monthly job and the quarterly report — and then deletes against recorded evidence
rather than against silence.

**If you own the thing, you own moving its users.** Shipping a deprecation notice and leaving the work
to everyone downstream doesn't remove the cost; it multiplies it by the number of teams and bills them
for a decision they didn't make. Where the code is reachable, MasterMind does the migration. Where it
isn't, it produces the tool — a script, an adapter, an automated rewrite — not an announcement.

**A deprecation with no removal date is advisory, and advisory means ignored.** Attaching a date turns it
into a commitment: the work gets scheduled and the thing genuinely goes away. Either choice is
defensible; making it silently is not, so MasterMind states which one this is. A date that slips twice
teaches everyone the next one is fiction.

**Zombies get an owner or a date.** Code with no owner and live consumers can't be left in limbo, because
limbo is self-perpetuating. It gets one or the other, written down.

## When it fires

You don't type a command. Say any of these and MasterMind reaches for `deprecate`:

> *"can we delete this? I'm pretty sure nothing uses it"*
> *"we need to get everyone off the v1 API"*
> *"there's a feature flag in here from 2023 — is it safe to remove?"*

You'll see it engage in your terminal:

```
🧠 MasterMind ▸ retiring the old one without breaking anything still calling it
   └ deprecate · expand → migrate → contract · prove-then-delete
```

## When it does *not* fire

- **Restructuring that keeps the interface.** Reshaping code so it reads better while everything that
  used it keeps working unchanged is `refactorer`. The distinction is whether anything outside has to
  move: if the callers don't notice, it's a refactor; if they have to change, it's a deprecation.
- **Something broken rather than obsolete.** That's `debug`. Deprecate removes things that work and are
  no longer wanted; debug fixes things that are wanted and don't work.
- **A genuinely trivial deletion.** A file created an hour ago, a leftover variable with no consumers.
  Five phases for that is ceremony, and MasterMind skips it — effort matches stakes.

## What you get

Either the removal actually happens — in reversible steps, with evidence that nothing was still reading
it — or you get an honest *"this is still in use, and here's who's calling it"* instead of an outage. The
second outcome is the one worth paying for: it's the answer you can't get by looking.
