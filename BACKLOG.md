# Backlog

What is actually still open. Everything that was here from the v0.24.0 documentation pass — the
unroutable field-pack template, the ui-ux-pro-max paths and stats, the hardcoded counts, and the ten
design fixes across `lab`, `debug`, `spike`, `signature`, `levelup`, `route`, `spec`, `qa`, `perf`,
`explain`, `code-reviewer`, `refactorer`, and `tech-scout` — **shipped in v0.24.1 and v0.24.2**. See
`CHANGELOG.md` rather than re-deriving it here.

---

## Bugs in vendored `ui-ux-pro-max` code — **FIXED locally (v0.24.3)**

Found by the characterization suite added in v0.24.2 (`scripts/tests/`). All three were **upstream's
code**. All three are now fixed in `scripts/design_system.py` and recorded as deliberate local
overrides in that directory's `SOURCE.md`, so a re-vendor cannot silently reintroduce them. Each fix
is marked in the source with a `MASTERMIND LOCAL OVERRIDE` comment and pinned by a test that was
flipped from asserting the bug to asserting the correct behavior.

1. **Path traversal in `persist_design_system`** — *security, highest severity here.* `project_name`
   and `page` were only lowercased and space-hyphenated before being joined onto the output path, so
   `-p "../../escaped" --page "../../pwned"` wrote outside the `design-system/` tree. **Fixed:**
   slug sanitising plus a realpath containment check.
2. **`_find_reasoning_rule`'s keyword pass was far too loose.** It split `UI_Category` on `/` and `-`,
   so `"E-commerce"` yielded the token `"e"` — a substring of nearly every string. Any unrecognized
   category containing an "e" silently inherited the **E-commerce** rule, making the documented
   "no rule → neutral defaults" branch near-unreachable. **Fixed:** whole-token matching, minimum
   token length 3, best score wins. All 161 real categories still resolve unchanged.
3. **`_select_best_match` compared names bidirectionally** (`priority in name` OR `name in priority`),
   so a short style name could beat the intended target. **Fixed:** directional match only.

**Still open:** these fixes have *not* been submitted upstream. Doing so is the durable fix — until
then MasterMind carries the diff.

## Dead weight

- **`data/design.csv`** (~104KB) is never read: it is in no config, has no domain key, and its first
  line is a content row rather than a header, so it could not be parsed even if wired up. Its sibling
  `draft.csv` was deleted in v0.24.2 on the same evidence. Its prose is in Chinese, which is moot while
  nothing reads it. Deleting it is the obvious call — left pending only because it is vendored.

## Checks — **ADDED in v0.24.3**

`check-integrity.mjs` went from 7 checks to 10. Each was proven to fail before being kept.

- **8 — `active-field.md` points at a pack that exists** and is well-formed. A typo'd pointer used to
  pass every check while the model silently loaded no field pack at all.
- **9 — a `SOURCE.md` preserve list is honored.** Partial by necessity: detecting "a vendored file was
  edited but never listed" needs a diff against upstream, impossible offline. It catches a preserved
  path that no longer exists, and drift between the list and the re-vendor procedure in both
  directions. **Still open:** a content-hash manifest recorded at vendor time would close the rest.
- **10 — `.githooks/` matches `skills/lab/assets/`.** v0.24.2 fixed a leak in the shipped `pre-push`
  and left this repo's own copy vulnerable, while the CHANGELOG and `SECURITY.md` both said otherwise.
- **Index parity is no longer vacuous.** `skills/README.md` was checked with a bare substring match, so
  deleting the row for `qa`, `build`, `report`, `route`, `learn`, or `debug` passed clean — their names
  appear in ordinary prose. Now parses the actual table rows and compares sets both ways.

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
