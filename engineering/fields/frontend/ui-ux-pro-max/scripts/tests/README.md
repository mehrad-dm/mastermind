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
not a silent change. Currently pinned bugs:

- `_find_reasoning_rule` — the keyword pass splits `"E-commerce"` into `["e", "commerce"]`,
  so any otherwise-unmatched category containing the letter "e" resolves to the E-commerce
  rule, making the neutral-defaults branch in `_apply_reasoning` near-unreachable.
- `_select_best_match` — the style-name match is bidirectional (`priority in name OR
  name in priority`), so a short style name that is a substring of the priority string
  wins over the intended target.
- `persist_design_system` — `project_name` and `page` are only lowercased and
  space-hyphenated before being joined onto the output path, so `../` escapes the
  `design-system/` tree.

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
