# MasterMind Mod

An optional add-on for Claude Code 2.1.287 or newer. The MasterMind brain is plain Markdown and works
without it. The Mod adds the things Markdown cannot do: it stops and asks at the moment an irreversible
action is about to run, it shows the state of the brain without spending a model turn, and it tells
you when an answer claims more than the turn did.

It is a separate plugin on purpose. A Markdown plugin cannot run code. This one does, inside Claude
Code, with your permissions. Read "Security" below before you install it.

## What it does

| Part | What you see |
| --- | --- |
| Hold | The permission dialog opens before `git push`, a publish, a deploy, a destructive delete, or a write outside the project, even when a permission rule or auto mode would have let it through. The dialog carries one line saying what the command does and which kernel rule applies. |
| Status | One dim line above the prompt: field pack, logged misses and the date of the last one, the next spec step, running subagents, context used. Where there is no band (VS Code) a status line appears only when something needs attention. |
| Slash commands | `/mm-status`, `/mm-wrong-log` (last 10), `/mm-next`, `/mm-check`, `/mm-evidence`. Each answers at once, with no model turn. |
| Handoff hint | One toast when the context window passes the threshold (70% by default), again only after it has fallen below. |
| Verdict notice | One line for you, never for the model, when a turn changed something, the answer says it is finished, and there is no `not checked:` line. |
| Evidence receipt | One line when the answer reports a check ("tests pass", "verified", "37/37") and no test, typecheck, lint, build or preflight command has run since the last change. |
| Delegation | Running subagents are counted in the status line with their model, or `fork`. A review handed to a fork gets one line: a fork inherits the context that wrote the work, so it is not a clean-context review. |
| Kernel presence | "kernel not loaded: run npx mastermind-brain" when no loaded instruction file, and no session hook, delivered the kernel. The Mod never injects the kernel itself. |

The notices cost no tokens: they are drawn for you and are not sent to the model. The output of a
slash command is different: like any command output, it is part of the conversation from the next
request on.

## Install

In a terminal session of Claude Code:

```
/plugin marketplace add mehrad-dm/mastermind
/plugin install mastermind-mod@mastermind
```

Or in one line, from a shell: `claude plugin install mastermind-mod --marketplace mehrad-dm/mastermind`.

`npx mastermind-brain` does not install the Mod and never will: a mod is code, and you opt into code
separately. On Claude Code older than 2.1.287 the plugin loads and does nothing.

To try it from a checkout without installing: `claude --plugin-dir /path/to/mastermind/mod`.

## Settings, and how to turn each part off

Set them in the `/config` menu, or in `~/.claude/settings.json` under `pluginConfigs`
(`mastermind-mod@mastermind` when installed from the marketplace, `mastermind-mod@inline` with
`--plugin-dir`):

```json
{ "pluginConfigs": { "mastermind-mod@mastermind": { "options": { "hold": "destructive-only" } } } }
```

| Setting | Values | Default | Effect |
| --- | --- | --- | --- |
| `hold` | `all`, `destructive-only`, `off` | `all` | `destructive-only` lets plain push, publish and deploy through and still asks for force pushes, deletes, discarded work and writes outside the project. `off` turns the hold off. |
| `headless` | `defer`, `deny` | `defer` | What the hold does when nobody can be asked (`claude -p`, the SDK). `defer` leaves the decision to your permission rules, so a pipeline you allowed to push still pushes. `deny` refuses the action and tells the model why. |
| `handoffAt` | 0 to 100 | 70 | Context percent for the handoff hint. `0` turns the hint off. |
| `nudge` | `on`, `off` | `on` | `off` silences the verdict notice, the evidence receipt and the fork-review line. |

The status line has no setting: collapse the band with ctrl+x ctrl+a, or disable the plugin. The
slash commands do nothing until you type one. To turn everything off, disable or uninstall the plugin
in `/plugin`.

## What the hold catches

`git push` (plain, forced with `-f`, `--force`, `--force-with-lease` or `+ref`, deletes, tags; not
`--dry-run`), `git reset --hard`, `git clean -f` (not `-n`), `git branch -D`, `git checkout -- <path>`
and `git restore <path>`, `rm` with `-r` or `-f`, `npm`, `pnpm`, `yarn` and `bun publish`,
`vercel --prod`, `gh release create`, `gh pr merge`, `docker push`, `terraform apply` and `destroy`,
`kubectl apply` and `delete`, and `DROP` or `TRUNCATE` passed to `psql` or `mysql`. It reads through
`&&`, `;`, `|`, new lines, subshells, `VAR=value` prefixes, `env VAR=value`, `sudo` and `npx`.

`rm` is not held for `node_modules`, `dist`, `build`, `.next`, `coverage` or `.turbo` inside the
project, or for a path under the system temp directory.

Writes by Edit, Write, MultiEdit and NotebookEdit are held when the file resolves outside the project
and outside the system temp directory, symbolic links followed. Claude Code's own plan files and
memory files are left alone. A directory added with `--add-dir` counts as outside.

The hold only tightens. It never approves anything, it returns a refusal from your rules untouched,
and it applies to subagents as well as the main conversation.

## What the hold does not catch

The hold reads the text of the command. It does not run it, expand it or follow it. These get past
it, by design, and each one is asserted as a known miss in `tests/classifier.test.ts`:

- command substitution that builds the command: `$(echo git) push`
- shell aliases and functions: `gp origin main`
- `make` targets and scripts: `make release`, `./scripts/release.sh`, `npm run deploy`
- `eval "git push"`
- `bash -c "git push"`, and any other shell given a command string
- `xargs rm`
- `find -delete`
- wrappers the classifier does not open, such as `timeout 30 git push`, `doas rm -rf dir`, `env -i git push`
- SQL in a file: `psql -f drop.sql`
- MCP tools, and any tool other than Bash and the four file-writing tools
- spending a one-use credential, which no command line reveals

Two more limits. A relative path that contains a regenerable folder name is trusted wherever the shell
happens to be, so `cd ~/elsewhere && rm -rf build` is not held. And text matching can hold a harmless
command that merely quotes a risky one in an unusual way.

This is a safety net under the kernel's rule, not a replacement for it and not a security boundary.
Keep your own permission rules.

## Behaviour worth knowing

- In the dialog for a shell command the reason is shown. In the dialog for a file write, Claude Code
  2.1.323 shows its own file prompt and not the reason; the reason is in the debug log.
- In auto mode, when the classifier is unavailable, Claude Code refuses a held action instead of
  asking.
- `/mm-check` runs `bash <brain>/install.sh --check` directly. It never runs `mastermind check`,
  which can fetch or sync the brain first. In a plugin-only install there is no installer, and the
  command says so.
- The status facts come from one call, `mastermind status --json`, made when the session starts and
  after a turn that changed something. Never on a timer. If the CLI is missing or too old to know
  `status`, the line says "status unavailable" and nothing fails.
- Under `claude -p` the hooks run and nothing is drawn.
- Where an organization runs Claude Code's managed guard, a user's mod cannot observe the instruction
  files or session hook context, so the kernel line stays silent there. Everything else works.

## Security

A mod is code that runs inside Claude Code with your account's permissions. It is not sandboxed.
Claude Code loads it only after you accept workspace trust for the folder.

What this mod hooks, as `claude plugin validate` reports it:

```
hooks: session.start, tool.check{tool=Bash}, tool.check{tool=Edit|Write|MultiEdit|NotebookEdit},
       tool.call, turn.start, turn.complete, agent.spawn, session.measure, prompt.context,
       session.append{door=hook-context}, command.run{command=mm-status|mm-wrong-log|mm-next|mm-check|mm-evidence},
       ui.render{component=AbovePrompt}
calls: $.command.register, $.env.get, $.fs.exists, $.fs.stat, $.process.run, $.session.root,
       $.session.surfaces, $.ui.invalidate, $.ui.log, $.ui.resolve, $.ui.status, $.ui.toast
env reads: HOME, TMPDIR        env writes: nothing
```

What that means:

- No network access. No file writes. No model calls. It never submits a prompt and never changes one.
- It never answers `allow` to a permission check.
- `prompt.context` and `session.append` are read to see whether the kernel was loaded. Both are
  passed on unchanged.
- `tool.call`, `turn.*` and `agent.spawn` are observed after the fact, to know whether a turn changed
  something, which check commands ran and how they exited, and which subagents are running. Command
  text is kept in memory for the current turn only and is shown only by `/mm-evidence`.
- It runs two programs, and only these: the MasterMind CLI at `<project>/.mastermind/bin/mastermind`,
  or `~/.mastermind/bin/mastermind` when the project has none, with `status --json`, `status`, `next`
  or `wrong-log`; and `bash <brain>/install.sh --check` when you type `/mm-check`. The project copy is
  code from the repository you opened, the same trust you give its other hooks.
- It reads file metadata (`$.fs.stat`) to resolve where a write would land. It reads no file contents.

Check it yourself: `claude plugin validate mod/.claude-plugin/plugin.json --strict` prints the lines
above from the source, and `bash mod/tests/validate.sh` fails if any of them grows a network call, a
file write, a model call, a prompt submission or an environment write.

The Mod API is early access and may change between Claude Code releases. If a release breaks a hook,
Claude Code skips that hook and carries on; if the hold itself fails, a command that looks risky is
refused, not run.

## Tests

```
claude plugin test mod          # Claude Code 2.1.287 or newer
bash mod/tests/validate.sh      # the contract above, against the validator's own output
```
