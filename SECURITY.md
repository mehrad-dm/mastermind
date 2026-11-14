# Security

MasterMind is a markdown knowledge base plus a few small, dependency-free scripts. It ships no server
and runs no service, which leaves two surfaces worth naming, and a third for anyone who installs
the optional Mod.

**Keeping private or client material out of this public repository and its history.** That is the one
this file is mostly about, and the quarantine below is how it is enforced.

**The installer reads files the project controls.** `install.sh` runs inside whatever repository you
point it at, and that repository supplies input: `.mastermind/routes.map` names directories to write
into, existing paths may be symlinks, and a `<file>.mm-backup` pointer names a file to restore. A
malicious or merely careless repository can therefore aim a write somewhere you did not intend. The
installer treats all of it as untrusted, and every write and every delete passes through one
containment check, in every mode: install, update, check, uninstall, `--shared`, `--global`, and the
per-app anchors compiled from `routes.map`. That includes the files it seeds, the backups it makes
and restores, and the lines uninstall takes back out of your files.

The check is the same each time. A destination that is a symlink the installer did not make
itself, or whose fully resolved path
leaves the project (or your home directory, for `--global`), is refused with a message naming the
path and a non-zero exit. It is never followed, and a path that cannot be resolved is refused, not
guessed at. The same check covers the per-tool files: `.codex/hooks.json`, `.cursor/agents/` and
the kernel block in an `AGENTS.md` of your own. It will only restore a backup pointer of the exact shape it writes itself.

Outside the project, a per-project install creates one thing: the `~/.mastermind` link to the brain
it was run from, through the same check, scoped to your home directory. A `--shared` install also
writes its install record under `~/.mastermind-state/projects/`. A `~/.mastermind` that already
points at a different brain is refused, never repointed. If you find a
write or a delete that escapes this, that is a vulnerability, and the reporting instructions below
apply.

## The Lab quarantine

Anything derived from a real, possibly-private codebase stays in `lab/`, which is gitignored. Two
`.githooks/` guards enforce it:

- **pre-commit / pre-push** block any staged change that contains a quarantined `lab/` path, a
  denylisted identifier, or a common secret pattern (keys, tokens).
- Distilled knowledge only leaves the Lab after every project, product, and person name is stripped:
  **patterns, not identities.**

To enable the guards after cloning: `git config core.hooksPath .githooks`.

## The optional Mod

`mastermind-mod` is a separate, opt-in Claude Code plugin in `mod/`. Nothing installs it for you.
Everything else in this repository is text a model reads; the Mod is JavaScript that Claude Code
loads into your session, and Claude Code does not sandbox it. Read
[`mod/README.md`](mod/README.md) before installing it. What it does and does not do:

- It handles tool, turn, agent, session and render events.
- It runs only read-only MasterMind CLI commands and the installer's check.
- It makes no network request, writes no file and calls no model.
- It never approves a tool call. It can ask you, or leave the decision to your own permission rules.
- Its hold on irreversible actions matches the text of a command. A command hidden inside a script,
  an alias or a subshell passes it unseen, so it is a safety net and not a firewall.

## What the release pipeline can reach

Publishing runs on GitHub Actions and holds two credentials. Both are listed here because a
credential nobody has written down is one nobody audits.

**npm publishing** uses trusted publishing over OIDC. There is no npm token in this repository or
in its secrets: the workflow exchanges a short-lived identity for permission to publish, and only
the publish job requests it. Packages are published with provenance, and the exact commit is
stamped into the published `package.json` so a version can be traced to one commit of this
repository.

**`MASTERMIND_SITE_KEY`** is a read-only deploy key for `mastermind-site`, the private repository
holding the website. The release gate uses it to check that the published library pages still
match the skill and agent instructions behind them.

- It reads one repository and nothing else. A personal access token would have read every
  repository the account owns, which is why this is a deploy key.
- It cannot write. A push with it is refused by GitHub.
- It does not expire, so nothing breaks silently on a renewal date.
- To revoke: delete it from `mastermind-site` → Settings → Deploy keys, and delete the
  `MASTERMIND_SITE_KEY` secret from this repository. Releases then fail at the gate until a
  new key is set, or until the repository variable `MM_ALLOW_UNCHECKED_LIBRARY=1` is set to
  ship without the library check; the job summary records that the check did not run.

Actions are pinned to full commit SHAs rather than tags, so a moved tag upstream cannot change
what runs. `npm` itself is pinned in the publish job for the same reason.

## Reporting a vulnerability

If you find leaked private data in the repo or history, a way to bypass the guards, or any other
security issue, please **report it privately** via GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/how-tos/report-and-fix-vulnerabilities/report-privately)
on this repository rather than opening a public issue. This is an experimental, single-maintainer
project, so expect a best-effort response.
