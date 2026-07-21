# Vendored skill — attribution & updates

**`ui-ux-pro-max`** is a third-party skill vendored into MasterMind (not authored here).

- **Author:** NextLevelBuilder — MIT License (see `LICENSE`).
- **Repo:** https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
- **Site:** https://ui-ux-pro-max-skill.nextlevelbuilder.io/
- **Vendored version:** 2.6.2 (design-intelligence database: UI styles, color palettes,
  font pairings, UX guidelines, chart types across many stacks).

## Updating
Re-vendor from upstream when it releases:

```
P=~/.mastermind/engineering/fields/frontend/ui-ux-pro-max
git clone --depth 1 https://github.com/nextlevelbuilder/ui-ux-pro-max-skill /tmp/uupm
cp -R "$P/scripts/tests" /tmp/uupm-tests            # MasterMind-authored
cp "$P/data/motion.csv" /tmp/uupm-motion.csv        # carries MasterMind duration overrides
cp "$P/scripts/design_system.py" /tmp/uupm-ds.py    # carries MasterMind bug fixes
rm -rf "$P"
cp -R /tmp/uupm/.claude/skills/ui-ux-pro-max "$P"
cp /tmp/uupm/LICENSE "$P/LICENSE"
cp -R /tmp/uupm-tests "$P/scripts/tests"
# Re-apply the overrides. Do NOT blindly restore the old files — diff each against
# upstream's new one first, so genuine upstream additions aren't dropped:
diff /tmp/uupm-motion.csv "$P/data/motion.csv"
diff /tmp/uupm-ds.py "$P/scripts/design_system.py"
python3 -m unittest discover -s engineering/fields/frontend/ui-ux-pro-max/scripts/tests
# keep this SOURCE.md; bump the version above; commit.
```

**Three things here are MasterMind's, not upstream's, and must survive the `rm -rf`:**

- **`scripts/tests/`** — a characterization suite we wrote. A failure after a re-vendor means
  upstream changed design-selection behavior: a signal to review, not to delete the test.
  See `scripts/tests/README.md`.
- **`data/motion.csv`** — re-tiered to obey the single duration policy in
  `engineering/fields/frontend/web-animations.md` (small/local 100–200ms · medium 200–350ms ·
  large 350–500ms). Upstream's durations contradict that policy, so a clean re-vendor silently
  reintroduces the contradiction. Re-apply the overrides and keep the two files in agreement.
- **`scripts/design_system.py`** — carries **three bug fixes to upstream's code** (v0.24.3).
  A clean re-vendor silently reintroduces all three, including a **security** bug. Each fix
  is marked in the file with a `MASTERMIND LOCAL OVERRIDE` comment pointing back here, and
  each is covered by a test in `scripts/tests/` that goes red if the bug returns. Re-apply
  them after any re-vendor:

  1. **Path traversal in `persist_design_system` (security).** Upstream only lowercased and
     space-hyphenated `project_name` and `page` before joining them onto the output path, so
     `-p "../../escaped" --page "../../pwned"` wrote files *outside* the `design-system/`
     tree. Fixed with `_safe_path_slug()` (neutralises `/`, `\`, `:`, NUL, dot-runs and
     leading dots; sanitising to empty falls back to `"default"`, consistent with the
     existing empty-name behavior) plus a `_contained()` realpath containment check that
     refuses the write if the resolved target is not inside the intended directory.
     Legitimate names are untouched: `"My Project"` -> `my-project`.
     Test: `test_project_name_and_page_cannot_traverse_out_of_the_output_dir`.
  2. **`_find_reasoning_rule`'s keyword pass was far too loose.** Upstream split `UI_Category`
     on `/` and `-` and accepted a *substring* hit from any token; `"E-commerce"` yields the
     token `"e"`, a substring of nearly every string, so every unrecognized category silently
     inherited the E-commerce rule and the documented "no rule -> neutral defaults" branch in
     `_apply_reasoning` was near-unreachable. Fixed with whole-token matching
     (`_tokenize_category`), a `MIN_CATEGORY_TOKEN_LEN` of 3, and best-score-wins instead of
     first-graze-wins. All 161 rows in `data/ui-reasoning.csv` still resolve to themselves.
     Tests: `test_unrecognized_category_reaches_the_neutral_defaults_branch`,
     `test_every_real_ui_category_resolves_to_itself`.
  3. **`_select_best_match` compared style names bidirectionally.** Upstream matched
     `priority in name OR name in priority`, so a style whose name merely happened to be a
     substring of the priority string beat the style the priority actually named. Now
     directional (`priority in name` only), which preserves the intended feature — a priority
     string still matches a longer real style name containing it.
     Test: `test_substring_match_is_directional`.

  All three were found by the characterization suite. They should also go upstream; until they do, this file is the only thing standing between a
  re-vendor and their silent return.

MasterMind pairs this (the *what* — design data & recommendations) with the `build`
loop and `engineering/fields/frontend/` (the *how* — rigor, states, a11y, verification).
