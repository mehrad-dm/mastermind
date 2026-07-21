# design_system.py tests

Characterization / regression tests for `../design_system.py`. Standard library
`unittest` only — this repo has no Python dependency management and must not gain one.

## Run

From the repo root:

```
python3 -m unittest discover -s engineering/fields/frontend/ui-ux-pro-max/scripts/tests -v
```

No network. Every test that persists anything writes to a `tempfile.TemporaryDirectory`
and cleans up; nothing is ever written into the repo.

## What these tests are

They pin what the code **does today**, not what it should do. Where current behavior
looks wrong, the test name ends in `_BUG` and its docstring says so — those tests pin
the bug deliberately so that fixing it is a conscious decision with a visible red test,
not a silent change.

Still pinned:

- `hex_to_ansi` — a 7-char string starting with `#` but containing non-hex digits
  (`"#GGGGGG"`) raises `ValueError`, while every other malformed value degrades to `""`.

**Fixed in v0.24.3 — these tests now assert the CORRECT behavior** and are
[local overrides of upstream](../../SOURCE.md), so a re-vendor that reintroduces the
bug turns them red:

- `_find_reasoning_rule` — the keyword pass split `"E-commerce"` into `["e", "commerce"]`
  and accepted a substring hit, so any otherwise-unmatched category containing the letter
  "e" resolved to the E-commerce rule. Now whole-token, min token length 3, best score wins.
  See `test_unrecognized_category_reaches_the_neutral_defaults_branch`.
- `_select_best_match` — the style-name match was bidirectional (`priority in name OR
  name in priority`), so a short style name that is a substring of the priority string
  beat the intended target. Now directional. See `test_substring_match_is_directional`.
- `persist_design_system` — `project_name` and `page` were only lowercased and
  space-hyphenated before being joined onto the output path, so `../` escaped the
  `design-system/` tree. Now slug-sanitised **and** containment-checked against the
  resolved output dir. See `test_project_name_and_page_cannot_traverse_out_of_the_output_dir`.

## Not covered

The suite targets selection logic, dial handling, determinism, no-match paths, and
persistence. It does **not** verify the exact rendered text of `format_ascii_box`,
`format_markdown`, or most of `format_master_md` (box-drawing alignment, checklist
blocks, component CSS), nor `_generate_intelligent_overrides`' branch coverage, nor
`core.py`'s BM25 ranking.

## Re-vendoring

`ui-ux-pro-max` is vendored from upstream (see `../../SOURCE.md`). The documented
update procedure `rm -rf`s the whole skill directory, which would delete this `tests/`
directory. Preserve it across a re-vendor: copy `scripts/tests/` aside first and restore
it after, then run the suite. Failures after a re-vendor are the signal to review — they
mean upstream changed selection behavior or the CSV data that drives it.
