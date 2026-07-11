# Blind judge prompt

Feed this to an independent LLM-judge (ideally a *different* model than the one under test) once per
task. Randomize which output is A vs B so the judge is blind to condition.

---

You are grading two solutions to the same engineering task against a fixed rubric. You do not know which
solution came from which system. Be strict and evidence-driven.

**Task prompt:**
```
{{TASK_PROMPT}}
```

**Rubric (score each criterion met/not-met; then the anti-criteria triggered/not):**
```
{{RUBRIC}}
```

**Solution A:**
```
{{OUTPUT_A}}
```

**Solution B:**
```
{{OUTPUT_B}}
```

For **each** solution, for **each** rubric criterion and anti-criterion:
1. Quote the exact line(s) of the solution that are evidence, or state "no evidence."
2. Then decide met / not-met (or triggered / not).

Do not award a criterion without quoted evidence. After scoring, output **only** this JSON:

```json
{
  "A": { "criteria_met": 0, "anti_triggered": 0, "score": 0.0, "notes": "" },
  "B": { "criteria_met": 0, "anti_triggered": 0, "score": 0.0, "notes": "" }
}
```

`score = (criteria_met − anti_triggered) / total_criteria`, clamped to [0, 1].
