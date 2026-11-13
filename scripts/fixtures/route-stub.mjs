#!/usr/bin/env node
// Stands in for the CLI in the routing self-test: every skill listed but hints that ignore the
// request (STUB_MODE=constant), or one skill missing from the table (STUB_MODE=drop).
import { readdirSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const skills = readdirSync(join(dirname(fileURLToPath(import.meta.url)), '..', '..', 'skills'), { withFileTypes: true })
  .filter((e) => e.isDirectory()).map((e) => ({ name: e.name }))
const drop = process.env.STUB_MODE === 'drop'
console.log(JSON.stringify({
  skills: drop ? skills.filter((s) => s.name !== 'debug') : skills,
  hints: drop ? skills.map((s) => s.name) : ['build', 'debug', 'qa'],
}))
