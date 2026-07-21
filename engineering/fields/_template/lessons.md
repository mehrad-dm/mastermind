---
field: <field>
route_when: [lesson, gotcha, pattern, review-finding, house-style]
---

# Lessons — <FIELD> (the leveling record)

Durable lessons from real usage and `code-reviewer` findings. Each is a one-line rule with the "why"
in brackets. Appended by `levelup`. When a lesson is general enough to be a default, also
promote it into `stack-defaults.md`.

**Pruning — a pack that only grows is a bug.** `levelup` reviews this file whenever it runs a refresh,
and always before appending once the list passes **40 lessons**. Delete a lesson when any of these is
true: (1) it has been promoted into `stack-defaults.md` — the default is now the rule, and the lesson is
a duplicate; (2) it is about a library, version, or tool this field no longer uses; (3) the framework
fixed it upstream, so the workaround is now wrong advice; (4) a newer lesson supersedes it — merge the
two, keep one. Deleting is the default when a lesson is merely *true but never load-bearing*; keep only
what would change a decision.

<!-- Example shape:
- **<The rule, stated as an imperative>.** <One line of how/detail.> [<why it earned a place — the
  failure it prevents>.]
-->

_(No lessons yet — this fills in as MasterMind does real work in this field.)_
