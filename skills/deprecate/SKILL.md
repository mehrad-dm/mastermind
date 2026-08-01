---
name: deprecate
description: Use when something has to be removed or retired — a feature, endpoint, table column, config key, feature flag, package or whole service; migrating consumers off an old API or version; code that looks dead but might not be. Symptoms: "can we delete this?", "is anything still using this?", "we need everyone off v1", "kill the old one". Not for restructuring that keeps the interface — that's the `refactorer` agent.
---

# MasterMind — Deprecate

Every other skill adds or fixes. This one deletes, migrates and retires — the half of engineering where
the reward (a smaller system) arrives long after the risk, and where what breaks is whatever you
couldn't see was still reading it.

## The shape: expand → migrate → contract

Any removal that can't land in one atomic commit takes three phases, in this order, each shipped on its
own:

- **Expand** — add the new thing beside the old. Both work. Nothing has moved yet, and stopping here
  breaks nothing.
- **Migrate** — move consumers in batches sized by blast radius: one caller at a time where a mistake
  pages someone, a whole service where it doesn't. Verify each batch before starting the next.
- **Contract** — remove the old, once nothing reads it.

Renaming `users.email_addr` to `users.email` on a live system, as five deploys:

```text
1  add `email` · backfill · write both · still read `email_addr`   ← expand, fully reversible
2  read `email` · keep writing both                                ← the only behavior change; watch it
3  move every caller off `email_addr`, batch by service            ← migrate
4  stop writing `email_addr` · leave the column for one rollback window
5  drop the column                                                 ← contract
```

Each line deploys and reverts on its own; the sequence *is* the safety. Collapse any two and you get the
classic outage — during a rolling deploy **both versions run at once**, so the instance that hasn't
restarted yet is still writing to the column you just dropped.

## Prove it's unused — never assert it

**Never contract on a search you didn't run, and never treat one symbol search as the answer.** "Nothing
references it" is a claim about the whole system, and the places that break are the ones a symbol search
can't see: config and environment, infra and CI, docs, runbooks and dashboards, other repos and clients
you don't build, and every dynamic reference — a name assembled from a string, reflection, a container
registration, a route table, a serialized payload, a stored default, an analytics event name. Search for
the **spelling**, everywhere it could be written, not the identifier inside one tree.

The excuses to catch in yourself: *"it's obviously dead"* — obvious to you, not to the caller in
someone else's repo · *"the search came back empty"* — empty for that spelling, in that tree ·
*"we can always put it back"* — not for data, and not for whoever broke in between.

**When you can't prove it from the outside, measure it from the inside.** Ship a counter or a log line
on the old path, wait a real interval — one full business cycle, including the monthly job and the
quarterly report — then delete against recorded evidence instead of against absence of evidence.

## Advisory or compulsory — pick one out loud

A deprecation with no removal date is **advisory**, and advisory deprecations get ignored, correctly:
nothing happens to anyone who skips them. A date makes it **compulsory** — and the date is a promise you
now owe. Choose, and say which:

- **No date** → say plainly that it's a preference, and budget to maintain both paths indefinitely.
- **A date** → name it, name who moves each consumer, and hold it. A removal date that slips twice
  teaches everyone the next one is fiction.

## The churn rule

**If you own the thing being deprecated, you own migrating its users.** A deprecation notice doesn't
remove the work — it multiplies it by the number of teams and bills them for a decision they didn't
make. Where you can reach the code, do the migration. Where you can't, ship the codemod, the adapter or
the script: a tool, not an announcement.

## Zombie code — no owner, live consumers

The state worth naming, because most rot lives in it: code nobody maintains that something still calls.
It isn't dead (the traffic proves it) and it isn't alive (nobody will change it), and limbo protects it —
nobody dares delete it, nobody dares touch it, and every incident inside it opens with an archaeology dig.

**A zombie gets an owner or a removal date. There is no third state.** Write down which one it got.

## Deleting is a verified change like any other

The check proving nothing broke *is* the work — `~/.mastermind/engineering/core/rigor.md` governs the
verification, the evidence-backed report, and the "say first, then do" tier that already covers data
migrations and deleting files that aren't yours. Two things belong to removal specifically:

- **Keep the deletion its own commit.** Bundled with a refactor, the revert stops being one action.
- **The old path is the rollback path.** Contract after the rollback window closes, not before.

## Gotchas

- **Data outlives code.** Rows the old path wrote, queued jobs carrying the old shape, cached payloads, a
  mobile build from eight versions ago nobody can force-update. Consumers with no call site to find.
- **Removing a flag is a deprecation.** Delete the losing branch and the flag together; a flag deleted on
  its own leaves a branch nothing can reach and nobody will read.
- **Non-code consumers break too.** A metric name in a dashboard, an alert query, a runbook step, a
  documented example people copy-paste.
- **Deleting a feature's tests is right; deleting the coverage isn't.** If a test reached shared behavior
  *through* the deleted path, that behavior is now untested — move the test rather than dropping it.
