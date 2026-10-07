# Tasks: <feature name>

**Spec** specs/<NNN-name>/spec.md · **Plan** specs/<NNN-name>/plan.md · **Updated** <YYYY-MM-DD>
**Tests** <required by C-<n> · requested in the spec · not required: verified by qa>

Format: `- [ ] T### [P] [US#] <action> in <exact path> (<spec IDs>)`. `[P]` = parallel-safe.

## Phase 1: Setup

- [ ] T001 <action> in <path>

## Phase 2: Foundation

Blocks every story. Keep it to what no single story can deliver.

- [ ] T002 <action> in <path>

## Phase 3: US1 <story title> (P1)

**Independent test**: <copied from the spec>

- [ ] T003 [P] [US1] <action> in <path> (FR-001)
- [ ] T004 [US1] <action> in <path> (US1/AC1)

**Checkpoint**: <the independent test passes; what you run and what you see>

## Phase 4: US2 <story title> (P2)

- [ ] T005 [US2] <action> in <path> (FR-003)

**Checkpoint**: <...>

## Phase 5: Polish

- [ ] T006 [P] <cross-cutting action> in <path>
