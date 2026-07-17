export const meta = {
  name: 'router-honor-test',
  description: 'Measure whether MasterMind actually consults ROUTER.md and loads only the matched files (honor-system check)',
  phases: [{ title: 'Probe' }],
}

const MM = '/Users/zed/Desktop/Projects/mastermind'

const REPORT = {
  type: 'object', additionalProperties: false,
  required: ['consulted_router', 'files_read'],
  properties: {
    consulted_router: { type: 'boolean', description: 'did you actually Read engineering/ROUTER.md?' },
    files_read: { type: 'array', items: { type: 'string' }, description: 'every file path under ~/.mastermind you actually Read while handling this task' },
    notes: { type: 'string', description: 'one line on how you decided what to load' },
  },
}

// 4 tasks that SHOULD route to different frontend files (animation→web-animations,
// review→audit-rules, refactor→stack-defaults/lessons/improve-ui, datafetch→stack-defaults/curriculum)
const tasks = [
  { id: 'animation', model: 'opus', p: 'Build a smooth slide-in drawer animation for a mobile menu in React, respecting reduced-motion.' },
  { id: 'review', model: 'opus', p: 'Review this React snippet for correctness + a11y issues:\n<ul>{items.map(i => <li onClick={()=>sel(i)}>{i.name}</li>)}</ul>' },
  { id: 'refactor', model: 'opus', p: 'Refactor a messy 200-line React component with duplicated fetch/loading/error logic into something clean.' },
  { id: 'datafetch', model: 'opus', p: 'What is the best data-fetching setup for a Next.js App Router page showing a paginated list?' },
  // weak-model contrast on the same animation task — does Haiku over/under-read?
  { id: 'animation-haiku', model: 'haiku', p: 'Build a smooth slide-in drawer animation for a mobile menu in React, respecting reduced-motion.' },
]

phase('Probe')
const results = await parallel(
  tasks.map((t) => () =>
    agent(
      `You have MasterMind installed at ${MM} — kernel ${MM}/CLAUDE.md, plus engineering/core/, engineering/fields/frontend/, skills/, agents/, and a routing manifest ${MM}/engineering/ROUTER.md. ` +
      `Follow MasterMind properly to handle this task: load whatever MasterMind knowledge you would genuinely use, exactly as in a real session. ` +
      `Do the task briefly (a short answer/sketch is fine — the point is your loading behavior, not a full solution). ` +
      `Then, being scrupulously honest (MasterMind's own rule), report every file you actually Read from under ${MM} and whether you consulted ROUTER.md.\n\nTask: ${t.p}`,
      { model: t.model, agentType: 'general-purpose', phase: 'Probe', label: `probe:${t.id} (${t.model})`, schema: REPORT },
    ).then((r) => ({ id: t.id, model: t.model, ...(r || {}) })),
  ),
)
return results.filter(Boolean)
