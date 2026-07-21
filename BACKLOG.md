# Backlog

What is actually still open. Everything that was here from the v0.24.0 documentation pass — the
unroutable field-pack template, the ui-ux-pro-max paths and stats, the hardcoded counts, and the ten
design fixes across `lab`, `debug`, `spike`, `signature`, `levelup`, `route`, `spec`, `qa`, `perf`,
`explain`, `code-reviewer`, `refactorer`, and `tech-scout` — **shipped in v0.24.1 and v0.24.2**. See
`CHANGELOG.md` rather than re-deriving it here.

---

## Bugs in vendored `ui-ux-pro-max` code

Found by the characterization suite added in v0.24.2 (`scripts/tests/`). All three are **upstream's
code**, so a fix should go upstream or be recorded as a deliberate local override in `SOURCE.md`.

1. **Path traversal in `persist_design_system`** — *security, highest severity here.* `project_name`
   and `page` are only lowercased and space-hyphenated before being joined onto the output path, so
   `-p "../../escaped" --page "../../pwned"` writes outside the `design-system/` tree. Reproduced.
   The test suite pins the behavior safely (nested temp dir) rather than asserting it is correct.
2. **`_find_reasoning_rule`'s keyword pass is far too loose.** It splits `UI_Category` on `/` and `-`,
   so `"E-commerce"` yields the token `"e"` — a substring of nearly every string. Any unrecognized
   category containing an "e" silently inherits the **E-commerce** rule, making the documented
   "no rule → neutral defaults" branch near-unreachable.
3. **`_select_best_match` compares names bidirectionally** (`priority in name` OR `name in priority`),
   so a short style name can beat the intended target. Latent with current data; fragile to any short
   name added upstream.

## Dead weight

- **`data/design.csv`** (~104KB) is never read: it is in no config, has no domain key, and its first
  line is a content row rather than a header, so it could not be parsed even if wired up. Its sibling
  `draft.csv` was deleted in v0.24.2 on the same evidence. Its prose is in Chinese, which is moot while
  nothing reads it. Deleting it is the obvious call — left pending only because it is vendored.

## Checks that would prevent a recurring class of bug

- **Nothing validates that `active-field.md` points at a pack that exists.** A wrong pointer passes
  every check silently.
- **Nothing enforces a `SOURCE.md` preserve list.** v0.24.2 edited a vendored file (`motion.csv`)
  whose own directory documents that edits are discarded on re-vendor; it was caught in review, not by
  a check. Teaching `check-integrity.mjs` to fail when a file inside a `SOURCE.md`-bearing directory is
  modified without being listed in that file's preserve list would close it mechanically.

## Bigger open work

- **Judge-panel evals.** The newest runs (Run M1) are **N=2 with no independent judge**, while
  `evals/README.md` demands ≥3 judges and N≥3. This is the blocker for putting a number on the
  website — it is why the results section was removed.
- **Apply skill-TDD to the 17 skills.** v0.24.0 added the method (`levelup` → "prove the skill changes
  behavior", now in `skills/levelup/authoring.md`) and applied it to **zero** skills. Each needs an
  agent watched failing *without* the skill before the skill is trusted.
- **Wire Codex's bootstrap.** Codex has `hooks/hooks.json` auto-discovery. Not wired.
- **Verify Cursor + Copilot re-injection in the real tools.** Wired to published schemas but never
  tested live. Cursor has **open upstream bug reports** where `additional_context` is accepted but
  never reaches the model — do not claim it works.
- **TOC sidebar** for the 21 library pages — the right answer to "the article page feels narrow". Do
  **not** widen the 768px prose column; that width is the readability optimum.
- **Kernel trim.** `CLAUDE.md` is ~2,100 tokens vs the ~500 recommended. Deferred deliberately: its
  damage is invisible in a diff. **Do it only after the eval work above**, so it can be measured.

---

## Decisions already made — do not relitigate

- **Per-project install is the default**; `--global` is opt-in.
- **The project always wins.** On a skill-name collision the user's file is never displaced; ours
  installs as `mastermind-<name>` and both work. If theirs is later removed, ours reclaims the plain
  name and the alias is pruned.
- **Skill descriptions state WHEN, never WHAT.** A description that summarizes its own workflow becomes
  a shortcut the model takes *instead of* reading the skill body.
- **Skills name actions, not tools** — this is what lets one body run on every harness.
- **Proportionality over ceremony.** We deliberately rejected superpowers' maximalism (mandatory TDD,
  `<EXTREMELY-IMPORTANT>` tone). Match effort to stakes.
- **Adopt patterns, never Claude-only machinery.** The JS workflow API, `/loop`, `ultracode`, and
  worktrees stay optional accelerators, never dependencies.
- **🧠 stays a literal emoji** in terminal announce lines and terminal-simulation blocks. Everything
  that is genuinely site UI uses the inline Phosphor `Icon` component.
- **Prose arrows stay text.** Only arrows acting as UI became SVG.
- **Prose column stays 768px.** Navigation may span the full container.
- **Site docs are generated, never hand-written** — `scripts/build-library.mjs` from `skills/*/ABOUT.md`,
  so a page cannot claim something the skill doesn't say.
