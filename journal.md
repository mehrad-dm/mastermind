# Journal — what happened, dated, one line each

Episodic memory (`engineering/core/rigor.md`). Appended at each verdict; `· wrong ·` lines are the
calibration record, read back with `mastermind wrong-log` and distilled by `levelup`.

2026-08-04 · agent-callable brain (skills/skill/agents/agent/route/wrong-log) · Cursor and Codex had no native skill mechanism, so an agent inlined the library or guessed paths · ship — 19 assertions, live-verified on Claude Code, Cursor and Codex
2026-08-04 · wrong · claimed route-then-skill cost 97% less than reading the index · caught by evals/agent-surface-cost.mjs after route was redesigned to return the full table — it is ~41% MORE than the index path · measure the shipped design, never the prototype, before quoting a number
2026-08-04 · wrong · shipped keyword routing as a ranked shortlist and called it accurate · caught by evals/agent-surface-routing.mjs on organically-phrased requests: 0% top-1, 25% top-3 (it sent "the invoice screen takes nine seconds" to roadmap) · test with phrasing that does not reuse the trigger words the ranker scores against
2026-08-04 · wrong · a flag before the subcommand fell through to the install path, so `mastermind --json skills` would clone and write · caught by code-reviewer, reproduced with MASTERMIND_HOME=/nonexistent · parse the command anywhere in argv, and assert the read-only promise in a test
2026-08-04 · wrong · large piped output was truncated mid-string, producing invalid JSON · caught by evals/agent-surface-routing.mjs failing to parse at ~8KB · process.exit() discards unflushed async stdout — use writeSync when the process exits immediately
2026-08-04 · wrong · shipped the lookup shim only in the shared clone · caught by a live Claude Code session refusing to execute a path outside its sandbox · ship the runnable surface inside the project brain, where sandboxed agents actually run
2026-08-04 · wrong · the wrong-log was not discoverable — the kernel pointed at rigor.md without naming the command · caught by a live session that answered "check git log" instead · if a capability has a name, name it where the agent reads
2026-08-04 · wrong · wrong-log counted 7 misses when 6 were logged · caught by counting its output against the file — the unanchored filter matched the journal header's own sentence about `· wrong ·` lines · anchor a log filter to the entry format, and test it against a file containing prose about the format
