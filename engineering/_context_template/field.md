---
field: <field>
---

# Context: <name>

This context uses the **`<field>`** field pack. The field holds the *stack baseline* —
defaults, mentors, audit rules, the design database — shared by every app on that stack.
This file holds only what is **specific to this app/package**: its conventions, and any
deliberate deviation from a field default.

Keep it small. If a rule here would be true for every app on this stack, it belongs in the
field's `stack-defaults.md`, not here — promote it up via `levelup`.

## Conventions
<!-- What this app/package does differently. One line each. Delete this comment when filled. -->

## Deviations from the field default
<!-- Only genuine overrides, each with the reason. A context reads *after* the field, so a
     rule here refines the baseline for this app alone. Leave empty if there are none. -->
