# Plan: <feature name>

**Spec** specs/<NNN-name>/spec.md · **Updated** <YYYY-MM-DD>

## Summary

<The approach in three lines: what gets built, the central technical choice, and why.>

## Technical context

| | |
| --- | --- |
| Language / version | <from tech.md or the code> |
| Key dependencies | <existing ones first; new ones need a research.md entry> |
| Storage | <or n/a> |
| Testing | <the project's existing runner> |
| Platform | <where it runs> |
| Performance target | <a number, traced to an SC-### where possible> |
| Scale | <volume the design must hold> |

## Constitution gate

| Principle | Before design | After design | Note |
| --- | --- | --- | --- |
| I. <name> | pass · n/a · violates | pass · n/a · violates | <why> |

## Design

<From the architect agent: the boundaries and what each owns, the data flow, the contracts, the key
types. A diagram when prose cannot carry the shape. One line of reason per decision.>

## Structure

```text
<the real paths this feature creates (+) or changes (~)>
```

## Complexity accepted

Fill only for a gate violation or an addition no requirement asked for.

| What | Why it is needed | Simpler option rejected, and why |
| --- | --- | --- |

## Risks

- <Open clarification, unproven assumption, or external dependency, and what happens if it goes wrong>
