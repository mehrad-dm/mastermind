---
name: checklist
description: "Use when a feature's requirements need testing for one concern before planning or building: \"make a security checklist for this spec\", \"are the UX requirements complete?\", \"review the API requirements\", \"what did the spec forget about accessibility?\", \"give me a requirements checklist for this feature\", \"does our spec cover abuse or partial failure?\", a spec that looks thin on one area such as security, access rules or error recovery, or a sensitive feature heading into `blueprint` or `build`. Not for testing code or QA steps (that's `qa`), not for checking documents against each other (that's `analyze`)."
---

# MasterMind: Checklist

A checklist here is a **unit test for the requirements' wording**: each item asks whether the spec says
enough, clearly enough, about one concern. It never asks whether the code works. Feature and concern:
**$ARGUMENTS**.

```text
Tests the code (wrong here):    Verify the logo shows on the home page.
Tests the requirement (right):  Does the spec say what is shown when the logo fails to load? [Gap, Edge cases]
```

## Write it

1. **Pick the concern.** From the request, or the riskiest one the spec touches: security, privacy, UX,
   accessibility, API, data, performance, localization. Ask only if two concerns are equally likely, and
   recommend one.
2. **Read the feature's** `spec.md`, plus `plan.md` and `tasks.md` if they exist, and the constitution.
3. **Write 10 to 30 items** to `specs/<feature>/checklists/<concern>.md`. Each item is a question about
   the requirements, ends with its quality dimension, and cites a spec ID or `[Gap]`:

```text
- [ ] CHK007 Are rate limits specified for every public endpoint? [Completeness, FR-009]
- [ ] CHK008 Is "secure session" defined with an expiry and a revocation rule? [Clarity, FR-012]
- [ ] CHK009 Does the spec say who may delete another user's export? [Gap, Coverage]
```

When a model's output drives an action, the security list asks whether the spec limits that action in
code. An instruction in a prompt is not a boundary.

Quality dimensions: **Completeness** · **Clarity** · **Consistency** · **Measurability** · **Coverage**
(edge, error, recovery, non-functional) · **Assumptions** · **Conflicts**.

## Rules

- **At least 80% of items cite a spec ID** or `[Gap]`. An item with no anchor is an opinion.
- **Never tick a box you generated.** `[x]` means a reviewer judged the requirement good enough. Mark
  only what the user asks you to evaluate, and say which you marked.
- **Append, never overwrite.** A second run on the same concern adds items with new IDs.
- **Items start with a question word**: Are, Is, Does, Do, Can. "Verify", "Test" and "Confirm" mean you
  slipped into testing code.

## Gotchas

- **The pull toward test cases is strong.** Every item that describes clicking, calling or rendering is
  in the wrong file. Rewrite it as a question about what the spec says.
- **One concern per file.** A checklist mixing security and copy-editing gets skimmed.
- **The built-in `checklists/requirements.md`** belongs to `specify` and checks general spec quality.
  Leave it to that skill.

## Report

The file path, the item count by dimension, the three gaps most likely to cause rework, and whether
they need `interview` before `blueprint` proceeds.
