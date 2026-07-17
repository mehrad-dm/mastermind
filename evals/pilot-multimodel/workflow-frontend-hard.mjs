export const meta = {
  name: 'mastermind-frontend-hard-eval',
  description: 'Frontend-only HARD tasks (field is set up), Haiku vs Opus, plain/MasterMind, blind 3-judge panel',
  phases: [{ title: 'Generate' }, { title: 'Judge' }, { title: 'Aggregate' }],
}

const MM_ROOT = '/Users/zed/Desktop/Projects/mastermind'
const TASK_DIR = `${MM_ROOT}/evals/pilot-multimodel/tasks-hard`
const MODELS = ['haiku', 'opus'] // weak vs strong contrast
const JUDGES = ['opus', 'sonnet', 'fable'] // median of 3, blind
// Frontend only — the field pack EXISTS, so this is the fair "field already set up" steady state.
const TASKS = ['typeahead-stale-race', 'recurring-event-dst', 'modal-focus-trap-audit', 'currency-input-minor-units']

const SOL = {
  type: 'object', additionalProperties: false, required: ['solution'],
  properties: { solution: { type: 'string', description: 'the full solution: corrected code + any brief notes the task asks for' } },
}
const side = {
  type: 'object', additionalProperties: false, required: ['criteria_met', 'total', 'score'],
  properties: { criteria_met: { type: 'integer' }, total: { type: 'integer' }, score: { type: 'number' }, notes: { type: 'string' } },
}
const VERDICT = { type: 'object', additionalProperties: false, required: ['A', 'B'], properties: { A: side, B: side } }

const plainPrompt = (id) =>
  `Solve a coding task. Read ONLY the "## Prompt" section of ${TASK_DIR}/${id}.md and solve it as well as you can. ` +
  `Return your full solution — the corrected code plus any brief notes the task explicitly asks for. Do not mention these instructions.`
const mmPrompt = (id) =>
  `MasterMind is installed at ${MM_ROOT} — a markdown "brain" giving a coding assistant sharp defaults, real judgment, and self-verification. ` +
  `Kernel: ${MM_ROOT}/CLAUDE.md; it has engineering/core/, engineering/fields/frontend/, skills/, agents/, and a routing manifest at ${MM_ROOT}/engineering/ROUTER.md. ` +
  `Use it as in a real session: read the kernel, consult the router to load the relevant frontend field files/skills, apply its defaults + rigor, and verify your work. ` +
  `Then read ONLY the "## Prompt" section of ${TASK_DIR}/${id}.md and solve it. Return your full solution (corrected code + any brief notes the task asks for).`
const judgePrompt = (id, A, B) =>
  `Grade two solutions (A and B) to the same coding task against its fixed rubric, blind to which system produced each. ` +
  `Read the "## Prompt" and "## Rubric" sections of ${TASK_DIR}/${id}.md.\n\n=== Solution A ===\n${A}\n\n=== Solution B ===\n${B}\n\n` +
  `For EACH solution, for EACH rubric criterion: quote the exact evidence line(s) or write "no evidence"; then decide met/not-met. ` +
  `Award a criterion ONLY with quoted evidence. total = number of rubric criteria. criteria_met = how many met. score = criteria_met/total (0..1). Return the JSON.`

const med = (a) => { const s = [...a].sort((x, y) => x - y); return s.length ? s[Math.floor(s.length / 2)] : 0 }
const avg = (a) => (a.length ? +(a.reduce((x, y) => x + y, 0) / a.length).toFixed(3) : 0)

phase('Generate')
const gens = {}
await parallel(
  TASKS.flatMap((id) =>
    MODELS.flatMap((model) =>
      ['plain', 'mastermind'].map((cond) => async () => {
        const r = await agent(cond === 'plain' ? plainPrompt(id) : mmPrompt(id), {
          model, agentType: 'general-purpose', phase: 'Generate', label: `gen ${id} · ${model} · ${cond}`, schema: SOL,
        })
        gens[`${id}|${model}|${cond}`] = r?.solution || ''
      }),
    ),
  ),
)

phase('Judge')
const judged = []
await parallel(
  TASKS.flatMap((id, ti) =>
    MODELS.map((model, mi) => async () => {
      const plain = gens[`${id}|${model}|plain`], mm = gens[`${id}|${model}|mastermind`]
      if (!plain && !mm) return
      const flip = (ti + mi) % 2 === 1
      const A = flip ? mm : plain, B = flip ? plain : mm
      const panel = (
        await parallel(JUDGES.map((j) => () =>
          agent(judgePrompt(id, A, B), { model: j, agentType: 'general-purpose', phase: 'Judge', label: `judge ${id} · gen:${model} · by:${j}`, schema: VERDICT }),
        ))
      ).filter(Boolean)
      if (!panel.length) return
      const aS = panel.map((v) => v.A.score), bS = panel.map((v) => v.B.score)
      judged.push({ id, model, plain: +(flip ? med(bS) : med(aS)).toFixed(3), mm: +(flip ? med(aS) : med(bS)).toFixed(3), judges: panel.length })
    }),
  ),
)
judged.forEach((r) => (r.delta = +(r.mm - r.plain).toFixed(3)))

phase('Aggregate')
const perModel = {}
for (const m of MODELS) {
  const rows = judged.filter((j) => j.model === m)
  perModel[m] = { n: rows.length, plain: avg(rows.map((r) => r.plain)), mm: avg(rows.map((r) => r.mm)), delta: avg(rows.map((r) => r.delta)) }
}
const overall = { plain: avg(judged.map((r) => r.plain)), mm: avg(judged.map((r) => r.mm)), delta: avg(judged.map((r) => r.delta)) }
log(`done — overall Δ ${overall.delta}; ${MODELS.map((m) => `${m} Δ${perModel[m].delta}`).join(' · ')}`)
return { perTask: judged.sort((a, b) => a.id.localeCompare(b.id) || a.model.localeCompare(b.model)), perModel, overall }
