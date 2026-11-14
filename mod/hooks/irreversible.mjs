// Text classifier for shell commands that cannot be undone or that leave this machine.
// A safety net, not a firewall: README.md lists what gets past it.

const REGENERABLE = new Set(['node_modules', 'dist', 'build', '.next', 'coverage', '.turbo', 'target', 'out', '.cache', '__pycache__', '.pytest_cache', 'tmp'])
const LITTER = /(^|\/)(\.DS_Store|Thumbs\.db|[^/]*\.(pyc|pyo|log))$/
const TEMP = ['/tmp', '/private/tmp', '/var/tmp', '/private/var/tmp']
const KEYWORD = new Set(['then', 'do', 'else', 'elif', 'if', 'while', 'until', '!', '{', '}', 'time', 'command', 'exec', 'nohup', 'builtin'])
const ASSIGN = /^[A-Za-z_][A-Za-z0-9_]*=/
const SUDO_VALUE = new Set(['-u', '-g', '-C', '-D', '-h', '-p', '-r', '-t', '-T', '-U'])
const ENV_VALUE = new Set(['-u', '--unset', '-C', '--chdir', '-S', '--split-string'])
const NPX_VALUE = new Set(['-p', '--package', '-c', '--call'])
const GIT_VALUE = new Set(['-C', '-c', '--git-dir', '--work-tree', '--namespace', '--exec-path'])
const GH_VALUE = new Set(['-R', '--repo'])
const DOCKER_VALUE = new Set(['--context', '-c', '--config', '-H', '--host', '-l', '--log-level', '-f', '--file', '-p', '--project-name'])
const PACKAGE_VALUE = new Set(['--filter', '-F', '-w', '--workspace', '--registry', '--otp', '-C', '--dir', '--tag', '--access', '--cwd'])
const KUBECTL_VALUE = new Set(['-n', '--namespace', '--context', '--cluster', '--user', '-s', '--server', '--kubeconfig', '--token', '-v', '--v', '-l', '--selector', '-o', '--output', '-f', '--filename', '-c', '--container'])
const HELM_VALUE = new Set(['-n', '--namespace', '--kube-context', '--kubeconfig', '-f', '--values', '--set', '--version'])
const SSH_VALUE = new Set(['-b', '-c', '-D', '-E', '-e', '-F', '-I', '-i', '-J', '-L', '-l', '-m', '-O', '-o', '-p', '-Q', '-R', '-S', '-W', '-w', '-P'])
const SQL = /\b(drop\s+(table|database|schema|index|view|column|user|role|owned|extension|sequence|type|function)\b|truncate\b|delete\s+from\b|update\s+[\w."`]+\s+set\b|flushall\b|flushdb\b)/i
const MONGO = /\.(drop|dropDatabase|deleteMany|deleteOne|remove|drop[A-Z]\w*)\s*\(|\bflushall\b/i
const SQL_FILE = /(drop|delet|truncat|wipe|purge|reset|flush)/i
const SQL_CLIENTS = new Set(['psql', 'mysql', 'mariadb', 'sqlite3', 'sqlite', 'mongosh', 'mongo', 'redis-cli', 'cockroach', 'clickhouse-client'])
const RISKY = /\b(push|reset\b.*--hard|clean\s+-|rm\b|unlink|shred|truncate|mkfs|dd\s|publish|unpublish|deprecate|deploy|destroy|delete|drop|flush|prune|--prod|restore|checkout\s|switch\s|branch\s+-|stash\s+(drop|clear)|tag\s+-d|reflog|filter-(branch|repo)|update-ref|release\s+create|pr\s+merge|apply\b|scale\b|drain\b|rollout\b|uninstall\b|upgrade\b|crontab\s+-r|upload|-X\s*DELETE|scp\b|rsync\b|ssh\b|mv\s+-f|cp\s+-f|>)/i

const ASK = {
  push: 'ask before push, publish or deploy',
  delete: 'ask before deleting or overwriting what you did not create',
  outside: 'ask before writing outside the project',
}

const hit = (label, effect, rule, destructive) => ({ label, effect, rule, destructive })

// The backslash is kept out of the class, so each character has one way to match: no backtracking blow-up.
const HEREDOC = /^<<-?[ \t]*(['"]?)((?:\\.|[^\s;&|<>()'"\\])+)\1/
const markOf = (m) => m[2].replace(/\\(.)/g, '$1')

// Returns [the index after the heredoc bodies that start at `from`, their text], one per pending marker.
function skipBodies(src, from, marks) {
  let i = from
  let text = ''
  while (marks.length) {
    const mark = marks.shift()
    for (;;) {
      const end = src.indexOf('\n', i)
      const line = src.slice(i, end < 0 ? src.length : end)
      i = end < 0 ? src.length : end + 1
      if (line.replace(/^\t+/, '') === mark || end < 0) break
      text += line + '\n'
    }
  }
  return [i, text]
}

// The index just past the "))" that closes an arithmetic expansion opened at `from` (after "((").
function arithmeticEnd(src, from) {
  let depth = 2
  let i = from
  while (i < src.length && depth > 0) {
    if (src[i] === '(') depth += 1
    if (src[i] === ')') depth -= 1
    i += 1
  }
  return i
}

// Where a "${ ... }" ends, as bash reads it: only "${" nests, a "$( )" or backticks inside are skipped
// whole, and a plain "{" does not count. -1 when it never closes: then it is plain text.
function braceEnd(src, from) {
  let depth = 1
  let i = from
  while (i < src.length) {
    const c = src[i]
    if (c === '\\') { i += 2; continue }
    if (c === "'") { const end = src.indexOf("'", i + 1); i = end < 0 ? src.length : end + 1; continue }
    if (c === '"') { let j = i + 1; while (j < src.length && src[j] !== '"') j += src[j] === '\\' ? 2 : 1; i = j + 1; continue }
    if (c === '`') { const end = src.indexOf('`', i + 1); i = end < 0 ? src.length : end + 1; continue }
    if (c === '$' && src[i + 1] === '(') { i = substitutionEnd(src, i + 2); continue }
    if (c === '$' && src[i + 1] === '{') { depth += 1; i += 2; continue }
    if (c === '}' && --depth === 0) return i + 1
    i += 1
  }
  return -1
}

// Where a "$( ... )" inside double quotes ends: a quote in a heredoc body there does not close the string.
function substitutionEnd(src, from) {
  if (src[from] === '(') return arithmeticEnd(src, from + 1)
  const marks = []
  let depth = 1
  let i = from
  while (i < src.length && depth > 0) {
    const c = src[i]
    const m = c === '<' && src[i + 1] === '<' && src[i + 2] !== '<' ? HEREDOC.exec(src.slice(i)) : null
    if (c === '<' && src[i + 1] === '<' && src[i + 2] === '<') i += 3
    else if (m) {
      marks.push(markOf(m))
      i += m[0].length
    } else if (c === '\n' && marks.length) i = skipBodies(src, i + 1, marks)[0]
    else if (c === '\\') i += 2
    else if (c === '$' && src[i + 1] === '{' && braceEnd(src, i + 2) > 0) i = braceEnd(src, i + 2)
    else if (c === '$' && src[i + 1] === '(' && src[i + 2] === '(') i = arithmeticEnd(src, i + 3)
    else if (c === '#' && (i === from || /[\s;&|(]/.test(src[i - 1]))) {
      // A comment runs to the end of its line, and a quote inside it opens nothing.
      const end = src.indexOf('\n', i)
      i = end < 0 ? src.length : end
    } else if (c === "'") {
      const end = src.indexOf("'", i + 1)
      i = end < 0 ? src.length : end + 1
    } else if (c === '"') {
      let j = i + 1
      while (j < src.length && src[j] !== '"') j += src[j] === '\\' ? 2 : 1
      i = j + 1
    } else {
      if (c === '(') depth += 1
      if (c === ')') depth -= 1
      i += 1
    }
  }
  return i
}

// The text of $'...', where a backslash escapes the next character, the quote included.
function ansiQuoted(src, from) {
  let i = from
  let text = ''
  while (i < src.length && src[i] !== "'") {
    if (src[i] === '\\' && i + 1 < src.length) {
      text += src[i + 1]
      i += 2
    } else {
      text += src[i]
      i += 1
    }
  }
  return [i + 1, text]
}

// The commands an unquoted heredoc body runs: bash expands $( ) and backticks in it.
function substitutions(body) {
  const out = []
  for (let i = 0; i < body.length; i += 1) {
    if (body[i] === '\\') i += 1
    else if (body[i] === '$' && body[i + 1] === '(' && body[i + 2] !== '(') {
      const end = substitutionEnd(body, i + 2)
      out.push(...segments(body.slice(i + 2, end - 1)))
      i = end - 1
    } else if (body[i] === '`') {
      const end = body.indexOf('`', i + 1)
      if (end < 0) break
      out.push(...segments(body.slice(i + 1, end)))
      i = end
    }
  }
  return out
}

/**
 * Splits a command line into segments of words; quotes, heredoc bodies and comments are honoured.
 * Each segment: { words, writes, targets: [{ to, append }], body, piped }.
 */
export function segments(text) {
  const src = String(text ?? '')
  const out = []
  const nested = []
  const fresh = (piped) => ({ words: [], writes: false, targets: [], body: '', inputs: [], piped })
  let cur = fresh(false)
  let word = ''
  let open = false
  const heredocs = []
  const owners = []
  const expands = []
  const endWord = () => {
    if (open) cur.words.push(word)
    word = ''
    open = false
  }
  const endSegment = (piped = false) => {
    endWord()
    if (cur.words.length || cur.body || cur.targets.length) out.push(cur)
    cur = fresh(piped)
  }
  const redirectTarget = (from) => {
    const m = /^[ \t]*("[^"]*"|'[^']*'|[^\s;&|()<>]*)/.exec(src.slice(from))
    return [m[0].length, m[1].replace(/^["']|["']$/g, '')]
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
    } else if (c === '$' && src[i + 1] === "'") {
      const [end, quoted] = ansiQuoted(src, i + 2)
      word += quoted
      open = true
      i = end
    } else if (c === '$' && src[i + 1] === '(' && src[i + 2] === '(') {
      const end = arithmeticEnd(src, i + 3)
      word += src.slice(i, end)
      open = true
      i = end
    } else if (c === '$' && src[i + 1] === '{' && braceEnd(src, i + 2) > 0) {
      // One word: a "#" in it is not a comment, and a command inside it still runs.
      const end = braceEnd(src, i + 2)
      nested.push(...segments(src.slice(i + 2, end - 1)))
      word += src.slice(i, end)
      open = true
      i = end
    } else if (c === '(' && src[i + 1] === '(' && !open) {
      i = arithmeticEnd(src, i + 2)
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
          if (src[j + 2] !== '(') nested.push(...segments(src.slice(j + 2, end - 1)))
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
    } else if (c === '<' && src[i + 1] === '<' && src[i + 2] === '<') {
      endWord()
      const [len, to] = redirectTarget(i + 3)
      cur.body += to + '\n'
      i += 3 + len
    } else if (c === '<' && src[i + 1] === '<') {
      endWord()
      const m = HEREDOC.exec(src.slice(i))
      if (m) {
        heredocs.push(markOf(m))
        owners.push(cur)
        expands.push(!m[1] && !m[2].includes('\\'))
      }
      i += m ? m[0].length : 2
    } else if (c === '<') {
      if (/^\d+$/.test(word)) {
        word = ''
        open = false
      }
      endWord()
      const [len, from] = redirectTarget(i + (src[i + 1] === '&' ? 2 : 1))
      if (from) cur.inputs.push(from)
      i += (src[i + 1] === '&' ? 2 : 1) + len
    } else if (c === '>') {
      if (/^\d+$/.test(word)) {
        word = ''
        open = false
      }
      endWord()
      const m = /^(>{1,2})\|?(&?)[ \t]*("[^"]*"|'[^']*'|[^\s;&|()]*)/.exec(src.slice(i))
      const to = m[3].replace(/^["']|["']$/g, '')
      if (!(m[2] && /^[\d-]/.test(to)) && to !== '/dev/null') {
        cur.writes = true
        if (to) cur.targets.push({ to, append: m[1] === '>>' })
      }
      i += m[0].length
    } else if (c === '\n') {
      endSegment()
      const marks = heredocs.splice(0)
      const who = owners.splice(0)
      const live = expands.splice(0)
      let at = i + 1
      for (let k = 0; k < marks.length; k += 1) {
        const [end, body] = skipBodies(src, at, [marks[k]])
        who[k].body += body
        if (live[k]) nested.push(...substitutions(body))
        at = end
      }
      i = at
    } else if (c === '|') {
      const pipe = src[i + 1] !== '|' && src[i - 1] !== '|'
      endSegment(pipe)
      i += src[i + 1] === '&' ? 2 : 1
    } else if (c === ';' || c === '(' || c === ')' || c === '`') {
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
    const b = base(w)
    if (w === 'time') {
      rest.shift()
      while (rest[0]?.startsWith('-')) rest.shift()
    } else if (KEYWORD.has(w) || ASSIGN.test(w)) rest.shift()
    else if (b === 'sudo' || b === 'doas') {
      rest.shift()
      while (rest.length && rest[0].startsWith('-')) {
        const flag = rest.shift()
        if (flag === '--') break
        if (SUDO_VALUE.has(flag)) rest.shift()
      }
    } else if (b === 'env') {
      rest.shift()
      while (rest.length && rest[0].startsWith('-')) {
        const flag = rest.shift()
        if (flag === '--') break
        if (ENV_VALUE.has(flag)) rest.shift()
        else if (!/^(-i|--ignore-environment|-0|--null|-v|--debug|--unset=.*|--chdir=.*)$/.test(flag)) return null
      }
    } else if (b === 'timeout') {
      rest.shift()
      while (rest.length && rest[0].startsWith('-')) if (/^(-s|--signal|-k|--kill-after)$/.test(rest.shift())) rest.shift()
      rest.shift()
    } else if (b === 'nice' || b === 'ionice') {
      rest.shift()
      while (rest.length && rest[0].startsWith('-')) if (/^(-n|--adjustment|-c|-p)$/.test(rest.shift())) rest.shift()
    } else if (b === 'nohup' || b === 'caffeinate' || b === 'stdbuf') {
      rest.shift()
      while (rest.length && rest[0].startsWith('-')) rest.shift()
    } else if (b === 'npx' || b === 'bunx') {
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
const forced = (args) => args.some((a) => a === '--force' || cluster(a, 'f'))
const looksLikePath = (a) => a === '.' || a.endsWith('/') || a.includes('*') || (/\.[A-Za-z0-9]{1,6}$/.test(a) && !/^v?\d/.test(a))

function git(args) {
  let i = 0
  while (i < args.length && args[i].startsWith('-')) i += GIT_VALUE.has(args[i]) ? 2 : 1
  const sub = args[i]
  const rest = args.slice(i + 1)
  const any = (...names) => rest.some((a) => names.includes(a))
  const pos = rest.filter((a) => !a.startsWith('-'))
  if (sub === 'push') {
    if (any('--dry-run') || rest.some((a) => cluster(a, 'n'))) return null
    const refs = pos.slice(1)
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
    const dry = any('--dry-run') || rest.some((a) => cluster(a, 'n'))
    return forced(rest) && !dry ? hit('git clean -f', 'deletes untracked files, which git cannot bring back', 'delete', true) : null
  }
  if (sub === 'branch') {
    const deletes = any('--delete') || rest.some((a) => cluster(a, 'd'))
    if (rest.some((a) => cluster(a, 'D')) || (deletes && forced(rest))) return hit('git branch -D', 'deletes a branch even when its commits are merged nowhere else', 'delete', true)
    if (rest.some((a) => cluster(a, 'M') || cluster(a, 'C')) || (!deletes && forced(rest) && pos.length >= 1))
      return hit('git branch -f', 'moves or overwrites a branch, and commits only it pointed at are lost', 'delete', true)
    return null
  }
  if (sub === 'checkout') {
    if (rest.some((a) => cluster(a, 'B'))) return hit('git checkout -B', 'resets an existing branch to another commit', 'delete', true)
    if (rest.some((a) => cluster(a, 'b') || a === '--orphan')) return null
    const dashes = rest.indexOf('--')
    const named = rest.filter((a, n) => !a.startsWith('-') && (dashes < 0 || n < dashes))
    const discards = (dashes >= 0 && dashes < rest.length - 1) || any('.', '-f', '--force') || named.length >= 2 || named.some(looksLikePath)
    return discards ? hit('git checkout (discard)', 'overwrites uncommitted work in the working tree', 'delete', true) : null
  }
  if (sub === 'switch') {
    if (rest.some((a) => a === '-C' || a === '--force-create')) return hit('git switch -C', 'resets an existing branch to another commit', 'delete', true)
    if (any('--discard-changes', '-f', '--force')) return hit('git switch --discard-changes', 'throws away uncommitted work in the working tree', 'delete', true)
    return null
  }
  if (sub === 'restore') {
    const stagedOnly = any('--staged', '-S') && !any('--worktree', '-W')
    return !stagedOnly && pos.length ? hit('git restore', 'overwrites uncommitted work in the working tree', 'delete', true) : null
  }
  if (sub === 'stash' && (pos[0] === 'drop' || pos[0] === 'clear')) return hit('git stash ' + pos[0], 'deletes stashed work, which git keeps nowhere else', 'delete', true)
  if (sub === 'tag' && (any('-d', '--delete') || rest.some((a) => cluster(a, 'd')))) return hit('git tag -d', 'deletes a tag', 'delete', true)
  if (sub === 'tag' && forced(rest)) return hit('git tag -f', 'moves an existing tag to another commit', 'delete', true)
  if (sub === 'worktree' && pos[0] === 'remove' && forced(rest)) return hit('git worktree remove --force', 'deletes a worktree with its uncommitted work', 'delete', true)
  if (sub === 'reflog' && (pos[0] === 'expire' || pos[0] === 'delete')) return hit('git reflog ' + pos[0], 'drops the history that lets lost commits be recovered', 'delete', true)
  if (sub === 'gc' && rest.some((a) => /^--prune(=now)?$/.test(a))) return hit('git gc --prune', 'deletes unreachable commits for good', 'delete', true)
  if (sub === 'filter-branch' || sub === 'filter-repo') return hit('git ' + sub, 'rewrites the repository history', 'delete', true)
  if (sub === 'update-ref' && any('-d', '--delete')) return hit('git update-ref -d', 'deletes a ref', 'delete', true)
  if (sub === 'subtree' && pos[0] === 'push') return hit('git subtree push', 'publishes commits to a remote', 'push', false)
  return null
}

function tempVar(target, ctx) {
  const m = /^\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?(\/.*)?$/.exec(target)
  return Boolean(m && ctx.tempVars && ctx.tempVars.has(m[1]) && !String(m[2] ?? '').split('/').includes('..'))
}

function disposable(target, ctx) {
  const path = target.replace(/\/+$/, '')
  const parts = path.split('/')
  if (parts.includes('..')) return false
  if (tempVar(target, ctx)) return true
  const temp = [...TEMP]
  const own = String(ctx.tmpdir ?? '').replace(/\/+$/, '')
  if (own.startsWith('/')) temp.push(own, own.startsWith('/var/') ? '/private' + own : own)
  if (temp.some((t) => path.startsWith(t + '/') && path.length > t.length + 1)) return true
  if (/^(\$TMPDIR|\$\{TMPDIR\})\/./.test(path)) return true
  const root = String(ctx.root ?? '').replace(/\/+$/, '')
  const local = !/^[/~$]/.test(path) || /^(\$PWD|\$\{PWD\})\//.test(path) || (root !== '' && path.startsWith(root + '/'))
  return local && (parts.some((p) => REGENERABLE.has(p)) || LITTER.test(path))
}

const removes = (targets, ctx, label, ...why) => {
  const kept = targets.filter((t) => !disposable(t, ctx))
  return kept.length ? hit(label, (why[0] ?? 'deletes ') + kept.join(' ').slice(0, 120) + (why[1] ?? ' with no trash to restore from'), 'delete', true) : null
}

function rm(args, ctx) {
  const dashes = args.indexOf('--')
  const flags = args.filter((a, i) => a.startsWith('-') && a !== '--' && (dashes < 0 || i < dashes))
  const targets = args.filter((a, i) => a !== '--' && (!a.startsWith('-') || (dashes >= 0 && i > dashes)))
  if (!targets.length || flags.some((f) => f === '-i' || f === '--interactive')) return null
  const recursive = flags.some((f) => f === '--recursive' || cluster(f, '[rR]'))
  const label = recursive ? 'rm -r' : forced(flags) ? 'rm -f' : 'rm'
  return removes(targets, ctx, label)
}

const sensitive = (to) => /^(~|\$HOME|\$\{HOME\})\/\.[^/]/.test(to) || /^\/(private\/)?etc\//.test(to)

function overwrite(seg, ctx) {
  for (const t of seg.targets) {
    if (sensitive(t.to)) return hit('> ' + t.to, 'writes into a file outside the project that configures this machine', 'outside', true)
    if (!t.append && ctx.existing && ctx.existing.has(t.to) && !disposable(t.to, ctx))
      return hit('> ' + t.to, 'truncates an existing file before writing it, so its contents are gone', 'delete', true)
  }
  return null
}

const remote = (a) => /^([\w.-]+@)?[\w.-]+:(?!\/\/)/.test(a) && !/^[A-Za-z]:\\/.test(a)

function sqlText(seg, before) {
  const fed = seg.piped && before ? before.words.join(' ') + '\n' + before.body : ''
  return seg.words.slice(1).join(' ') + '\n' + seg.body + '\n' + fed
}

function sql(cmd, args, seg, before) {
  const text = sqlText(seg, before)
  const files = [...seg.inputs, ...args.filter((a, i) => args[i - 1] === '-f' || args[i - 1] === '--file').filter(Boolean)]
  const label = cmd + ' DROP/DELETE/TRUNCATE'
  if (SQL.test(text) || ((cmd === 'mongosh' || cmd === 'mongo') && MONGO.test(text)) || (cmd === 'redis-cli' && /\bflush(all|db)\b/i.test(text)))
    return hit(label, 'drops, deletes or overwrites data in the database', 'delete', true)
  if (files.some((f) => SQL_FILE.test(f.split('/').pop()))) return hit(label, 'runs a SQL file whose name says it drops or deletes data', 'delete', true)
  return null
}

function classify(words, raw, ctx, seg, before) {
  const cmd = base(words[0]).replace(/(.)@[^/]*$/, '$1')
  const args = words.slice(1)
  const has = (...names) => args.some((a) => names.includes(a))
  const pos = args.filter((a) => !a.startsWith('-'))
  const push = (label, effect) => hit(label, effect, 'push', false)
  const destroy = (label, effect) => hit(label, effect, 'delete', true)
  if (has('--help') || (args.length === 1 && (args[0] === '-h' || args[0] === '-help'))) return null
  if (has('--dry-run') && cmd !== 'git' && cmd !== 'kubectl') return null
  if (cmd === 'git') return git(args)
  if (cmd === 'rm') return rm(args, ctx)
  if (cmd === 'unlink') return removes(pos, ctx, 'unlink')
  if (cmd === 'shred') return removes(pos, ctx, 'shred', 'overwrites ', ' so it can never be read again')
  if (cmd === 'truncate' && args.some((a) => /^(-s|--size)/.test(a))) return removes(pos.filter((p, n) => args[args.indexOf(p) - 1] !== '-s'), ctx, 'truncate', 'empties ', '')
  if (cmd === 'dd') {
    const of = args.find((a) => a.startsWith('of='))
    return of && of !== 'of=/dev/null' && !disposable(of.slice(3), ctx) ? destroy('dd of=', 'writes raw bytes over ' + of.slice(3)) : null
  }
  if (/^mkfs(\.|$)/.test(cmd) || cmd === 'newfs' || cmd === 'wipefs') return destroy(cmd, 'erases a file system')
  if (cmd === 'diskutil' && /^(erase|zero|secureErase|partitionDisk)/i.test(pos[0] ?? '')) return destroy('diskutil ' + pos[0], 'erases a disk')
  if ((cmd === 'mv' || cmd === 'cp') && (forced(args) || sensitive(pos[pos.length - 1] ?? ''))) {
    const to = pos[pos.length - 1] ?? ''
    if (sensitive(to)) return hit(cmd + ' ' + to, 'writes into a file outside the project that configures this machine', 'outside', true)
    return pos.length >= 2 && !disposable(to, ctx) ? destroy(cmd + ' -f', 'overwrites ' + to + ' without asking') : null
  }
  if (cmd === 'tee' && pos.some(sensitive)) return hit('tee ' + pos.find(sensitive), 'writes into a file outside the project that configures this machine', 'outside', true)
  if (cmd === 'crontab' && args.some((a) => cluster(a, 'r'))) return destroy('crontab -r', 'deletes every scheduled job of this user')
  if (cmd === 'npm' || cmd === 'pnpm' || cmd === 'yarn' || cmd === 'bun') {
    let p = positionals(args, PACKAGE_VALUE)
    if (cmd === 'yarn' && p[0] === 'workspace') p = p.slice(2)
    if (cmd === 'yarn' && p[0] === 'npm') p = p.slice(1)
    if (p[0] === 'exec' || p[0] === 'x' || p[0] === 'dlx') return classifyWords(p.slice(1).filter((a) => a !== '--'), raw, ctx)
    if (p[0] === 'publish') return push(cmd + ' publish', 'publishes a package version, and a version number cannot be reused')
    if (p[0] === 'unpublish') return destroy(cmd + ' unpublish', 'removes a published version, and its number can never be used again')
    if (p[0] === 'deprecate') return push(cmd + ' deprecate', 'marks a published version deprecated for everyone who installs it')
    if (p[0] === 'dist-tag' && (p[1] === 'add' || p[1] === 'rm')) return push(cmd + ' dist-tag ' + p[1], 'moves what everyone installing the package gets')
    return null
  }
  if (cmd === 'changeset' && pos[0] === 'publish') return push('changeset publish', 'publishes package versions')
  if (cmd === 'lerna' && pos[0] === 'publish') return push('lerna publish', 'publishes package versions')
  if ((cmd === 'cargo' || cmd === 'poetry' || cmd === 'uv' || cmd === 'flit' || cmd === 'hatch') && pos[0] === 'publish') return push(cmd + ' publish', 'publishes a package version, and a version number cannot be reused')
  if (cmd === 'cargo' && pos[0] === 'yank') return push('cargo yank', 'withdraws a published crate version')
  if (cmd === 'twine' && pos[0] === 'upload') return push('twine upload', 'publishes a package version, and a version number cannot be reused')
  if (cmd === 'gem' && (pos[0] === 'push' || pos[0] === 'yank')) return push('gem ' + pos[0], 'publishes or withdraws a gem version')
  if (cmd === 'vercel') {
    const prod = args.some((a, i) => /^--prod(uction)?(=true)?$/.test(a) || a === '--target=production' || (a === '--target' && args[i + 1] === 'production'))
    if (prod) return push('vercel --prod', 'deploys to production, live to users at once')
    if (pos[0] === 'remove' || pos[0] === 'rm') return destroy('vercel remove', 'deletes deployments or a project')
    if (pos[0] === 'promote' || pos[0] === 'rollback') return push('vercel ' + pos[0], 'changes what production serves')
    return null
  }
  if (cmd === 'netlify' && pos[0] === 'deploy' && has('--prod', '-p', '--prodIfUnlocked')) return push('netlify deploy --prod', 'deploys to production, live to users at once')
  if (cmd === 'firebase' && pos[0] === 'deploy') return push('firebase deploy', 'deploys to the live project')
  if ((cmd === 'fly' || cmd === 'flyctl') && (pos[0] === 'deploy' || (pos[0] === 'apps' && pos[1] === 'destroy'))) return push(cmd + ' ' + pos.slice(0, 2).join(' '), 'changes the live app')
  if (cmd === 'wrangler' && (pos[0] === 'deploy' || pos[0] === 'publish' || pos[0] === 'delete')) return push('wrangler ' + pos[0], 'changes the live worker')
  if (cmd === 'gcloud' && pos.includes('deploy')) return push('gcloud ' + pos.slice(0, pos.indexOf('deploy') + 1).join(' '), 'deploys to the live project')
  if (cmd === 'gcloud' && pos.includes('delete')) return destroy('gcloud delete', 'deletes cloud resources')
  if (cmd === 'aws') {
    const verb = pos[1] ?? ''
    if (pos[0] === 's3' && (verb === 'rm' || verb === 'rb' || ((verb === 'sync' || verb === 'mv') && has('--delete')))) return destroy('aws s3 ' + verb, 'deletes objects in the bucket')
    if (/^(delete|terminate|remove|deregister|purge|destroy)-/.test(verb)) return destroy('aws ' + pos[0] + ' ' + verb, 'deletes cloud resources')
    if (/^(deploy|update-function-code|publish-)/.test(verb)) return push('aws ' + pos[0] + ' ' + verb, 'changes what is live')
    return null
  }
  if (cmd === 'heroku' && /^(apps:destroy|destroy|pg:reset|apps:delete)$/.test(pos[0] ?? '')) return destroy('heroku ' + pos[0], 'deletes the app or its data')
  if (cmd === 'pulumi' && (pos[0] === 'up' || pos[0] === 'update' || pos[0] === 'destroy')) return pos[0] === 'destroy' ? destroy('pulumi destroy', 'destroys live infrastructure') : push('pulumi ' + pos[0], 'changes live infrastructure')
  if (cmd === 'cdk' && (pos[0] === 'deploy' || pos[0] === 'destroy')) return pos[0] === 'destroy' ? destroy('cdk destroy', 'destroys live infrastructure') : push('cdk deploy', 'changes live infrastructure')
  if ((cmd === 'serverless' || cmd === 'sls') && (pos[0] === 'deploy' || pos[0] === 'remove')) return pos[0] === 'remove' ? destroy(cmd + ' remove', 'destroys the deployed service') : push(cmd + ' deploy', 'deploys the service')
  if (cmd === 'railway' && (pos[0] === 'up' || pos[0] === 'deploy' || pos[0] === 'down')) return push('railway ' + pos[0], 'changes the live service')
  if (cmd === 'gh') {
    const p = positionals(args, GH_VALUE)
    if (p[0] === 'release' && p[1] === 'create') return push('gh release create', 'publishes a release and its tag')
    if (p[0] === 'pr' && p[1] === 'merge') return push('gh pr merge', 'merges the pull request into its base branch on the remote')
    if (p[1] === 'delete' && ['repo', 'release', 'issue', 'gist', 'secret', 'variable', 'label', 'cache', 'run', 'ruleset'].includes(p[0])) return destroy('gh ' + p[0] + ' delete', 'deletes it on GitHub')
    if (p[0] === 'repo' && (p[1] === 'archive' || (p[1] === 'create' && has('--push')))) return push('gh repo ' + p[1], 'changes a repository on GitHub')
    if (p[0] === 'api' && args.some((a, i) => /^(-X|--method)$/.test(args[i - 1] ?? '') ? /^delete$/i.test(a) : /^(-XDELETE|--method=DELETE)$/i.test(a))) return destroy('gh api DELETE', 'deletes something through the GitHub API')
    return null
  }
  if (cmd === 'docker' || cmd === 'docker-compose' || cmd === 'podman') {
    const p = cmd === 'docker-compose' ? ['compose', ...positionals(args, DOCKER_VALUE)] : positionals(args, DOCKER_VALUE)
    if (p[0] === 'push' || (p[0] === 'image' && p[1] === 'push') || (p[0] === 'compose' && p[1] === 'push')) return push('docker push', 'publishes an image to the registry')
    if ((p[0] === 'buildx' && p[1] === 'build') || p[0] === 'build') return has('--push') ? push('docker build --push', 'publishes an image to the registry') : null
    if (p[0] === 'volume' && (p[1] === 'rm' || p[1] === 'prune')) return destroy('docker volume ' + p[1], 'deletes volumes and the data in them')
    if (p[0] === 'system' && p[1] === 'prune') return destroy('docker system prune', 'deletes images, containers and possibly volumes')
    if (p[0] === 'compose' && p[1] === 'down' && args.some((a) => a === '-v' || a === '--volumes')) return destroy('docker compose down -v', 'deletes the volumes and the data in them')
    return null
  }
  if (cmd === 'terraform' || cmd === 'tofu' || cmd === 'terragrunt') {
    const p = positionals(args, new Set())
    if (p[0] === 'apply' && has('-destroy')) return destroy(cmd + ' apply -destroy', 'destroys live infrastructure')
    if (p[0] === 'apply' || p[0] === 'run-all' && p[1] === 'apply') return push(cmd + ' apply', 'changes live infrastructure')
    if (p[0] === 'destroy' || (p[0] === 'run-all' && p[1] === 'destroy')) return destroy(cmd + ' destroy', 'destroys live infrastructure')
    if (p[0] === 'state' && (p[1] === 'rm' || p[1] === 'push' || p[1] === 'mv')) return destroy(cmd + ' state ' + p[1], 'rewrites the state of live infrastructure')
    return null
  }
  if (cmd === 'kubectl' || cmd === 'oc') {
    if (args.some((a) => /^--dry-run(=(client|server))?$/.test(a))) return null
    const p = positionals(args, KUBECTL_VALUE)
    const sub = p[0]
    if (sub === 'exec') {
      const at = args.indexOf('--')
      const inner = at >= 0 ? classifyWords(args.slice(at + 1), raw, {}) : null
      return inner && { ...inner, label: 'kubectl exec ' + inner.label, effect: inner.effect + ', inside a live container' }
    }
    if (sub === 'apply' || sub === 'replace' || sub === 'patch' || sub === 'set') return push('kubectl ' + sub, 'changes live cluster resources')
    if (sub === 'delete') return destroy('kubectl delete', 'deletes live cluster resources')
    if (sub === 'drain' || sub === 'cordon') return push('kubectl ' + sub, 'takes a node out of service')
    if (sub === 'rollout' && (p[1] === 'restart' || p[1] === 'undo')) return push('kubectl rollout ' + p[1], 'restarts or rolls back live workloads')
    if (sub === 'scale' && args.some((a, i) => a === '--replicas=0' || (a === '--replicas' && args[i + 1] === '0'))) return destroy('kubectl scale --replicas=0', 'stops every pod of a live workload')
    return null
  }
  if (cmd === 'helm') {
    const p = positionals(args, HELM_VALUE)
    if (p[0] === 'upgrade' || p[0] === 'install' || p[0] === 'rollback') return push('helm ' + p[0], 'changes a live release')
    if (p[0] === 'uninstall' || p[0] === 'delete') return destroy('helm uninstall', 'deletes a live release')
    return null
  }
  if (SQL_CLIENTS.has(cmd)) return sql(cmd, args, seg, before)
  if (cmd === 'dropdb' || cmd === 'dropuser') return destroy(cmd, 'deletes a database or role')
  if (cmd === 'prisma' && ((pos[0] === 'migrate' && pos[1] === 'reset') || (pos[0] === 'db' && pos[1] === 'push' && has('--accept-data-loss')))) return destroy('prisma ' + pos.slice(0, 2).join(' '), 'drops or loses data in the database')
  if ((cmd === 'rails' || cmd === 'rake') && /^db:(drop|reset|purge|schema:load|truncate_all)/.test(pos[0] ?? '')) return destroy(cmd + ' ' + pos[0], 'drops or wipes the database')
  if (/^python[\d.]*$/.test(cmd) && /manage\.py$/.test(pos[0] ?? '') && (pos[1] === 'flush' || pos[1] === 'reset_db')) return destroy('manage.py ' + pos[1], 'deletes every row in the database')
  if (cmd === 'supabase' && pos[0] === 'db' && pos[1] === 'reset') return destroy('supabase db reset', 'drops and recreates the database')
  if (cmd === 'curl' || cmd === 'http' || cmd === 'xh') {
    const method = args.find((a, i) => /^(-X|--request)$/.test(args[i - 1] ?? '')) ?? (args.find((a) => /^-X[A-Z]+$/.test(a)) ?? '').slice(2)
    if (/^(DELETE)$/i.test(method) || (cmd !== 'curl' && /^delete$/i.test(pos[0] ?? ''))) return destroy(cmd + ' DELETE', 'deletes something on a remote server')
    return null
  }
  if (cmd === 'scp' && pos.length >= 2 && remote(pos[pos.length - 1])) return push('scp', 'copies files to another machine')
  if (cmd === 'rsync') {
    if (args.some((a) => /^--(delete|remove-source-files)/.test(a))) return destroy('rsync --delete', 'deletes files at the destination that the source does not have')
    return pos.length >= 2 && remote(pos[pos.length - 1]) ? push('rsync', 'copies files to another machine') : null
  }
  if (cmd === 'ssh') {
    const p = positionals(args, SSH_VALUE)
    const inner = p.length >= 2 ? irreversible(p.slice(1).join(' '), {}) : null
    return inner && { ...inner, label: 'ssh ' + inner.label, effect: inner.effect + ', on another machine' }
  }
  return null
}

function classifyWords(words, raw, ctx) {
  const w = unwrap(words)
  if (!w || !w.length) return null
  return classify(w, raw, ctx, { words: w, targets: [], body: '', inputs: [], piped: false }, null)
}

/**
 * The first irreversible step of a shell command, or null.
 * ctx: { root, tmpdir } widen what `rm` may delete without a hold; existing: the redirect
 * targets that already exist, so a `>` onto one of them is held.
 */
export function irreversible(command, ctx = {}) {
  const raw = String(command ?? '')
  const tempVars = new Set(ctx.tempVars ?? [])
  for (const m of raw.matchAll(/(?:^|[\s;&|(])([A-Za-z_][A-Za-z0-9_]*)=["']?\$\(\s*mktemp\b/g)) tempVars.add(m[1])
  const local = { ...ctx, tempVars }
  const all = segments(raw)
  for (let n = 0; n < all.length; n += 1) {
    const segment = all[n]
    const found = overwrite(segment, local)
    if (found) return found
    const words = unwrap(segment.words)
    if (!words || !words.length) continue
    const risk = classify(words, raw, local, segment, all[n - 1])
    if (risk) return risk
  }
  return null
}

/** Where the command truncates a file with `>`, so the caller can say which of them exist. */
export const redirectTargets = (command) => segments(command).flatMap((s) => s.targets.filter((t) => !t.append).map((t) => t.to))

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
