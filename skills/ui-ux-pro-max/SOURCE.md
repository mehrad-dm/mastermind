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
git clone --depth 1 https://github.com/nextlevelbuilder/ui-ux-pro-max-skill /tmp/uupm
rm -rf ~/.mastermind/skills/ui-ux-pro-max
cp -R /tmp/uupm/.claude/skills/ui-ux-pro-max ~/.mastermind/skills/ui-ux-pro-max
cp /tmp/uupm/LICENSE ~/.mastermind/skills/ui-ux-pro-max/LICENSE
# keep this SOURCE.md; bump the version above; commit.
```

MasterMind pairs this (the *what* — design data & recommendations) with the `mastermind-build`
loop and `engineering/fields/frontend/` (the *how* — rigor, states, a11y, verification).
