#!/usr/bin/env node
// Stands in for the CLI in the routing self-test. STUB_MODE: constant (hints ignore the request),
// drop / dropother (a skill missing from the table), wide (every skill hinted), honest (passes).
import { readdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const skills = readdirSync(join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'skills'), { withFileTypes: true })
  .filter((e) => e.isDirectory()).map((e) => ({ name: e.name }))
const mode = process.env.STUB_MODE
const gone = { drop: 'debug', dropother: 'roadmap' }[mode]
const request = process.argv[3] ?? ''
const WORDS = { performance: /slow|seconds/, debug: /fail|safari|causing/, build: /add|dark mode/, qa: /work\?|proof/,
  quarantine: /sensitive/, deprecate: /remove|drop/, 'double-check': /sure|wrong about/, init: /set up/, explain: /docs|new hire/,
  handoff: /pausing|laptop/, help: /what can you do/, clarify: /did not follow/, prompt: /prompt/, signature: /conventions/,
  prototype: /approach/, levelup: /remember/, deepen: /five files/ }
const honest = Object.entries(WORDS).filter(([, re]) => re.test(request)).map(([n]) => n).slice(0, 3)
console.log(JSON.stringify({
  skills: gone ? skills.filter((s) => s.name !== gone) : skills,
  hints: mode === 'honest' ? honest : mode === 'constant' ? ['build', 'debug', 'qa'] : skills.map((s) => s.name),
  agents: [],
}))
