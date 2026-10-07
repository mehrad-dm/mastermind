# Spec: <feature name>

**Folder** specs/<NNN-name>/ · **Status** draft · **Updated** <YYYY-MM-DD>
**Amends** <specs/NNN-other/ when this changes a converged feature, else delete this line>
**Asked for**: "<the request, in the user's words>"

## User stories

### US1: <short title> (P1)

<The journey in plain language, from the user's side.>

**Why P1**: <the value, and why it comes first>
**Independent test**: <how someone sees this working with no other story built>

- **US1/AC1** When <event>, the system shall <observable response>.
- **US1/AC2** If <failure>, then the system shall <observable response>.

### US2: <short title> (P2)

<...>

## Requirements

- **FR-001** The system MUST <capability>.
- **FR-002** Users MUST be able to <action>.
- **FR-003** The system MUST <capability> [NEEDS CLARIFICATION: <the one question that decides it>]

## Key entities

- **<Entity>**: <what it represents and how it relates to others. No fields or types.>

## Success criteria

- **SC-001** <A user-side outcome with a number: "a returning user finds last week's report in under 10 seconds">

## Edge cases

- <What happens when the input is empty, huge, duplicated, malformed, or arrives twice?>
- <What happens when the user lacks permission, or loses connection mid-way?>

## Out of scope

- <What this feature deliberately does not do, and where that work would go>

## Assumptions

- <A default chosen because the request did not say, e.g. "exports are limited to the current workspace">

## Clarifications

<Filled by `interview`: one line per answered question, dated.>
