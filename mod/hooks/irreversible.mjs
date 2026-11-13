// Text classifier for shell commands that cannot be undone or that leave this machine.
// A safety net, not a firewall: README.md lists what gets past it.

const REGENERABLE = new Set(['node_modules', 'dist', 'build', '.next', 'coverage', '.turbo'])
const TEMP = ['/tmp', '/private/tmp', '/var/tmp', '/private/var/tmp']
const KEYWORD = new Set(['then', 'do', 'else', 'elif', 'if', 'while', 'until', '!', '{', '}', 'time', 'command', 'exec', 'nohup', 'builtin'])
const ASSIGN = /^[A-Za-z_][A-Za-z0-9_]*=/
const SUDO_VALUE = new Set(['-u', '-g', '-C', '-D', '-h', '-p', '-r', '-t', '-T', '-U'])
const NPX_VALUE = new Set(['-p', '--package', '-c', '--call'])
const GIT_VALUE = new Set(['-C', '-c', '--git-dir', '--work-tree', '--namespace', '--exec-path'])
const GH_VALUE = new Set(['-R', '--repo'])
const DOCKER_VALUE = new Set(['--context', '-c', '--config', '-H', '--host', '-l', '--log-level'])
const PACKAGE_VALUE = new Set(['--filter', '-F', '-w', '--workspace', '--registry', '--otp', '-C', '--dir', '--tag', '--access', '--cwd'])
const KUBECTL_VERB = new Set(['get', 'describe', 'logs', 'exec', 'create', 'apply', 'delete', 'edit', 'patch', 'scale', 'rollout', 'config', 'top', 'port-forward', 'explain', 'diff', 'label', 'annotate', 'run', 'expose', 'cp', 'auth', 'version', 'wait'])
const SQL = /\b(drop\s+[a-z]|truncate\b)/i
const RISKY = /\b(push|reset\b.*--hard|clean\s+-|rm\s+-|publish|--prod|restore|checkout\s+(--|\.|-f)|branch\s+-|release\s+create|pr\s+merge|terraform\s+(apply|destroy)|kubectl\b.*\b(apply|delete)|drop\s|truncate)/i

const ASK = {
  push: 'ask before push, publish or deploy',
  delete: 'ask before deleting or overwriting what you did not create',
  outside: 'ask before writing outside the project',
}

const hit = (label, effect, rule, destructive) => ({ label, effect, rule, destructive })

const HEREDOC = /^<<-?[ \t]*(['"]?)([^\s;&|<>()'"]+)\1/

// Returns the index after the heredoc bodies that start at `from`, one per pending marker.
function skipBodies(src, from, marks) {
  let i = from
  while (marks.length) {
    const mark = marks.shift()
    for (;;) {
      const end = src.indexOf('\n', i)
      const line = src.slice(i, end < 0 ? src.length : end)
      i = end < 0 ? src.length : end + 1
      if (line.replace(/^\t+/, '') === mark || end < 0) break
    }
  }
  return i
}

// Where a "$( ... )" inside double quotes ends: a quote in a heredoc body there does not close the string.
function substitutionEnd(src, from) {
  const marks = []
  let depth = 1
  let i = from
  while (i < src.length && depth > 0) {
    const c = src[i]
    const m = c === '<' ? HEREDOC.exec(src.slice(i)) : null
    if (m) {
      marks.push(m[2])
      i += m[0].length
    } else if (c === '\n' && marks.length) i = skipBodies(src, i + 1, marks)
    else {
      if (c === '(') depth += 1
      if (c === ')') depth -= 1
      i += 1
    }
  }
  return i
}

/** Splits a command line into segments of words; quotes, heredoc bodies and comments are honoured. */
export function segments(text) {
  const src = String(text ?? '')
  const out = []
  let words = []
  let word = ''
  let open = false
  let writes = false
  const heredocs = []
  const nested = []
  const endWord = () => {
    if (open) words.push(word)
    word = ''
    open = false
  }
  const endSegment = () => {
    endWord()
    if (words.length) out.push({ words, writes })
    words = []
    writes = false
  }
  let i = 0
  while (i < src.length) {
    const c = src[i]
    if (c === '\\') {
      if (src[i + 1] !== '\n') {
        word += src[i + 1] ?? ''
        open = true
      }
      i += 2
    } else if (c === "'") {
      const end = src.indexOf("'", i + 1)
      word += src.slice(i + 1, end < 0 ? src.length : end)
      open = true
      i = end < 0 ? src.length : end + 1
    } else if (c === '"') {
      let j = i + 1
      while (j < src.length && src[j] !== '"') {
        if (src[j] === '$' && src[j + 1] === '(') {
          const end = substitutionEnd(src, j + 2)
          nested.push(...segments(src.slice(j + 2, end - 1)))
          word += '$()'
          j = end
          continue
        }
        if (src[j] === '`') {
          const end = src.indexOf('`', j + 1)
          nested.push(...segments(src.slice(j + 1, end < 0 ? src.length : end)))
          j = end < 0 ? src.length : end + 1
          continue
        }
        if (src[j] === '\\' && j + 1 < src.length) j += 1
        word += src[j]
        j += 1
      }
      open = true
      i = j + 1
    } else if (c === '#' && !open) {
      while (i < src.length && src[i] !== '\n') i += 1
    } else if (c === '<' && src[i + 1] === '<' && src[i + 2] !== '<') {
      const m = HEREDOC.exec(src.slice(i))
      if (m) heredocs.push(m[2])
      i += m ? m[0].length : 2
    } else if (c === '>') {
      if (/^\d+$/.test(word)) {
        word = ''
        open = false
      }
      endWord()
      const m = /^>{1,2}\|?(&?)[ \t]*("[^"]*"|'[^']*'|[^\s;&|()]*)/.exec(src.slice(i))
      const to = m[2].replace(/^["']|["']$/g, '')
      if (!(m[1] && /^[\d-]/.test(to)) && to !== '/dev/null') writes = true
      i += m[0].length
    } else if (c === '\n') {
      endSegment()
      i = skipBodies(src, i + 1, heredocs)
    } else if (c === ';' || c === '|' || c === '(' || c === ')' || c === '`') {
      endSegment()
      i += 1
    } else if (c === '&') {
      if (src[i + 1] === '>') {
        endWord()
        i += 1
      } else {
        endSegment()
        i += 1
      }
    } else if (c === ' ' || c === '\t' || c === '\r') {
      endWord()
      i += 1
    } else {
      word += c
      open = true
      i += 1
    }
  }
  endSegment()
  return out.concat(nested)
}

const base = (word) => String(word ?? '').replace(/^\\/, '').split('/').pop()

/** Drops what stands in front of the command proper; null where the rest cannot be read. */
export function unwrap(words) {
  const rest = [...words]
  for (;;) {
    const w = rest[0]
    if (w === undefined) return rest
    if (w === 'time') {
      rest.shift()
      while (rest[0]?.startsWith('-')) rest.shift()
    } else if (KEYWORD.has(w) || ASSIGN.test(w)) rest.shift()
    else if (base(w) === 'sudo') {
      rest.shift()
      while (rest.length && rest[0].startsWith('-')) if (SUDO_VALUE.has(rest.shift())) rest.shift()
    } else if (base(w) === 'env') {
      rest.shift()
      if (rest[0]?.startsWith('-')) return null
    } else if (base(w) === 'npx' || base(w) === 'bunx') {
      rest.shift()
      while (rest.length && rest[0].startsWith('-')) if (NPX_VALUE.has(rest.shift())) rest.shift()
    } else return rest
  }
}

function positionals(args, valued) {
  const out = []
  for (let i = 0; i < args.length; i += 1) {
    if (!args[i].startsWith('-')) out.push(args[i])
    else if (valued.has(args[i])) i += 1
  }
  return out
}

const cluster = (arg, letter) => new RegExp('^-[A-Za-z]*' + letter + '[A-Za-z]*$').test(arg)

function git(args) {
  let i = 0
  while (i < args.length && args[i].startsWith('-')) i += GIT_VALUE.has(args[i]) ? 2 : 1
  const sub = args[i]
  const rest = args.slice(i + 1)
  const any = (...names) => rest.some((a) => names.includes(a))
  if (sub === 'push') {
    if (any('--dry-run') || rest.some((a) => cluster(a, 'n'))) return null
    const refs = rest.filter((a) => !a.startsWith('-')).slice(1)
    if (rest.some((a) => a.startsWith('--force') || cluster(a, 'f')) || refs.some((r) => /^\+./.test(r)))
      return hit('git push --force', 'rewrites the remote branch, and commits that exist only there are lost', 'push', true)
    if (any('--delete', '--mirror', '--prune') || rest.some((a) => cluster(a, 'd')) || refs.some((r) => /^:./.test(r)))
      return hit('git push --delete', 'deletes a branch or tag on the remote', 'push', true)
    if (any('--tags', '--follow-tags') || refs.some((r) => r === 'tag' || /^v?\d+\.\d+/.test(r) || r.includes('refs/tags/')))
      return hit('git push (tags)', 'publishes a tag, which anything watching the repository treats as a release', 'push', false)
    return hit('git push', 'publishes commits to the remote, where others and CI see them', 'push', false)
  }
  if (sub === 'reset' && any('--hard')) return hit('git reset --hard', 'discards every uncommitted change in tracked files', 'delete', true)
  if (sub === 'clean') {
    const forced = any('--force') || rest.some((a) => cluster(a, 'f'))
    const dry = any('--dry-run') || rest.some((a) => cluster(a, 'n'))
    return forced && !dry ? hit('git clean -f', 'deletes untracked files, which git cannot bring back', 'delete', true) : null
  }
  if (sub === 'branch') {
    const deletes = any('--delete') || rest.some((a) => cluster(a, 'd'))
    const forced = rest.some((a) => cluster(a, 'D')) || (deletes && (any('--force') || rest.some((a) => cluster(a, 'f'))))
    return forced ? hit('git branch -D', 'deletes a branch even when its commits are merged nowhere else', 'delete', true) : null
  }
  if (sub === 'checkout') {
    const dashes = rest.indexOf('--')
    const discards = (dashes >= 0 && dashes < rest.length - 1) || any('.', '-f', '--force')
    return discards ? hit('git checkout (discard)', 'overwrites uncommitted work in the working tree', 'delete', true) : null
  }
  if (sub === 'restore') {
    const stagedOnly = any('--staged', '-S') && !any('--worktree', '-W')
    const paths = rest.filter((a) => !a.startsWith('-'))
    return !stagedOnly && paths.length ? hit('git restore', 'overwrites uncommitted work in the working tree', 'delete', true) : null
  }
  return null
}

function disposable(target, ctx) {
  const path = target.replace(/\/+$/, '')
  const parts = path.split('/')
  if (parts.includes('..')) return false
  const temp = [...TEMP]
  const own = String(ctx.tmpdir ?? '').replace(/\/+$/, '')
  if (own.startsWith('/')) temp.push(own, own.startsWith('/var/') ? '/private' + own : own)
  if (temp.some((t) => path.startsWith(t + '/') && path.length > t.length + 1)) return true
  if (/^(\$TMPDIR|\$\{TMPDIR\})\/./.test(path)) return true
  const root = String(ctx.root ?? '').replace(/\/+$/, '')
  const local = !/^[/~$]/.test(path) || /^(\$PWD|\$\{PWD\})\//.test(path) || (root !== '' && path.startsWith(root + '/'))
  return local && parts.some((p) => REGENERABLE.has(p))
}

function rm(args, ctx) {
  const dashes = args.indexOf('--')
  const flags = args.filter((a, i) => a.startsWith('-') && a !== '--' && (dashes < 0 || i < dashes))
  const targets = args.filter((a, i) => a !== '--' && (!a.startsWith('-') || (dashes >= 0 && i > dashes)))
  const recursive = flags.some((f) => f === '--recursive' || cluster(f, '[rR]'))
  const forced = flags.some((f) => f === '--force' || cluster(f, 'f'))
  if ((!recursive && !forced) || !targets.length) return null
  const kept = targets.filter((t) => !disposable(t, ctx))
  if (!kept.length) return null
  return hit(recursive ? 'rm -r' : 'rm -f', 'deletes ' + kept.join(' ').slice(0, 120) + ' with no trash to restore from', 'delete', true)
}

function classify(words, raw, ctx) {
  const cmd = base(words[0]).replace(/(.)@[^/]*$/, '$1')
  const args = words.slice(1)
  const has = (...names) => args.some((a) => names.includes(a))
  if (has('--help') || (args.length === 1 && (args[0] === '-h' || args[0] === '-help'))) return null
  if (cmd === 'git') return git(args)
  if (cmd === 'rm') return rm(args, ctx)
  if (cmd === 'npm' || cmd === 'pnpm' || cmd === 'yarn' || cmd === 'bun') {
    let pos = positionals(args, PACKAGE_VALUE)
    if (cmd === 'yarn' && pos[0] === 'workspace') pos = pos.slice(2)
    const publishes = pos[0] === 'publish' || (cmd === 'yarn' && pos[0] === 'npm' && pos[1] === 'publish')
    return publishes && !has('--dry-run') ? hit(cmd + ' publish', 'publishes a package version, and a version number cannot be reused', 'push', false) : null
  }
  if (cmd === 'vercel') {
    const prod = args.some((a, i) => /^--prod(uction)?(=true)?$/.test(a) || a === '--target=production' || (a === '--target' && args[i + 1] === 'production'))
    return prod ? hit('vercel --prod', 'deploys to production, live to users at once', 'push', false) : null
  }
  if (cmd === 'gh') {
    const pos = positionals(args, GH_VALUE)
    if (pos[0] === 'release' && pos[1] === 'create') return hit('gh release create', 'publishes a release and its tag', 'push', false)
    if (pos[0] === 'pr' && pos[1] === 'merge') return hit('gh pr merge', 'merges the pull request into its base branch on the remote', 'push', false)
    return null
  }
  if (cmd === 'docker') {
    const pos = positionals(args, DOCKER_VALUE)
    return pos[0] === 'push' || (pos[0] === 'image' && pos[1] === 'push') ? hit('docker push', 'publishes an image to the registry', 'push', false) : null
  }
  if (cmd === 'terraform') {
    const sub = positionals(args, new Set())[0]
    if (sub === 'apply') return hit('terraform apply', 'changes live infrastructure', 'push', false)
    if (sub === 'destroy') return hit('terraform destroy', 'destroys live infrastructure', 'delete', true)
    return null
  }
  if (cmd === 'kubectl') {
    const sub = args.find((a) => KUBECTL_VERB.has(a))
    if (args.some((a) => /^--dry-run(=(client|server))?$/.test(a))) return null
    if (sub === 'apply') return hit('kubectl apply', 'changes live cluster resources', 'push', false)
    if (sub === 'delete') return hit('kubectl delete', 'deletes live cluster resources', 'delete', true)
    return null
  }
  const fed = /\||<</.test(raw) ? raw : ''
  if ((cmd === 'psql' || cmd === 'mysql') && SQL.test(args.join(' ') + ' ' + fed)) return hit(cmd + ' DROP/TRUNCATE', 'drops or truncates data in the database', 'delete', true)
  return null
}

/**
 * The first irreversible step of a shell command, or null.
 * ctx: { root, tmpdir } widen what `rm` may delete without a hold.
 */
export function irreversible(command, ctx = {}) {
  const raw = String(command ?? '')
  for (const segment of segments(raw)) {
    const words = unwrap(segment.words)
    if (!words || !words.length) continue
    const found = classify(words, raw, ctx)
    if (found) return found
  }
  return null
}

/** One line for the permission dialog, in the kernel's words. */
export const reasonFor = (risk) =>
  ('MasterMind hold: ' + risk.label + ' ' + risk.effect + '. The kernel says ' + ASK[risk.rule] + '; approval once is not approval again.').replace(/\s+/g, ' ')

/** For the error path: the classifier's answer, or a cheap pattern if the classifier is what failed. */
export function looksRisky(command) {
  try {
    return irreversible(command)
  } catch {
    return RISKY.test(String(command ?? '')) ? hit('this command', 'may not be undoable', 'delete', true) : null
  }
}
