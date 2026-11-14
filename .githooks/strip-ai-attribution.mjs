// Repo rule: no AI attribution in commit messages. Drops such lines before the commit is saved.
import { readFileSync, writeFileSync } from 'node:fs'

const AI = '(claude|anthropic|cursor ?agent|codex|openai|chatgpt|copilot|gemini)'
const attribution = [
  new RegExp(`^co-authored-by:.*\\b${AI}\\b`, 'i'),
  /^co-authored-by:.*@(anthropic|openai|cursor)\.com/i,
  /^\W*generated (with|by) \[?(claude|cursor|codex|chatgpt|copilot|gemini)\b/i,
]

export const strip = (text) =>
  text
    .split('\n')
    .filter((line) => !attribution.some((pattern) => pattern.test(line)))
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/\n+$/, '\n')

const file = process.argv[2]
if (file) writeFileSync(file, strip(readFileSync(file, 'utf8')))
