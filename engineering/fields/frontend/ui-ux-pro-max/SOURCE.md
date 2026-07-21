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
rm -rf "$P"
cp -R /tmp/uupm/.claude/skills/ui-ux-pro-max "$P"
cp /tmp/uupm/LICENSE "$P/LICENSE"
cp -R /tmp/uupm-tests "$P/scripts/tests"
# Re-apply the duration overrides. Do NOT blindly restore the old file — diff it against
# upstream's new one first, so genuine upstream additions aren't dropped:
diff /tmp/uupm-motion.csv "$P/data/motion.csv"
python3 -m unittest discover -s engineering/fields/frontend/ui-ux-pro-max/scripts/tests
# keep this SOURCE.md; bump the version above; commit.
```

**Two things here are MasterMind's, not upstream's, and must survive the `rm -rf`:**

- **`scripts/tests/`** — a characterization suite we wrote. A failure after a re-vendor means
  upstream changed design-selection behavior: a signal to review, not to delete the test.
  See `scripts/tests/README.md`.
- **`data/motion.csv`** — re-tiered to obey the single duration policy in
  `engineering/fields/frontend/web-animations.md` (small/local 100–200ms · medium 200–350ms ·
  large 350–500ms). Upstream's durations contradict that policy, so a clean re-vendor silently
  reintroduces the contradiction. Re-apply the overrides and keep the two files in agreement.

MasterMind pairs this (the *what* — design data & recommendations) with the `build`
loop and `engineering/fields/frontend/` (the *how* — rigor, states, a11y, verification).
