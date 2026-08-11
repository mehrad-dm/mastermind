# Security

MasterMind is a markdown knowledge base plus a few small, dependency-free scripts. It ships no server
and runs no service, which leaves two surfaces worth naming.

**Keeping private or client material out of this public repository and its history.** That is the one
this file is mostly about, and the quarantine below is how it is enforced.

**The installer reads files the project controls.** `install.sh` runs inside whatever repository you
point it at, and that repository supplies input: `.mastermind/routes.map` names directories to write
into, existing paths may be symlinks, and a `<file>.mm-backup` pointer names a file to restore. A
malicious or merely careless repository can therefore aim a write somewhere you did not intend. The
installer treats all of it as untrusted: every destination is resolved through its full symlink chain
and must land inside the project or the brain, files it writes content into may not be symlinks, and
it will only restore a backup pointer of the exact shape it writes itself. It refuses and exits rather
than guessing when a path cannot be resolved. If you find a path that escapes those checks, that is a
vulnerability, and the reporting instructions below apply.

## The Lab quarantine

Anything derived from a real, possibly-private codebase stays in `lab/`, which is gitignored. Two
`.githooks/` guards enforce it:

- **pre-commit / pre-push** block any staged change that contains a quarantined `lab/` path, a
  denylisted identifier, or a common secret pattern (keys, tokens).
- Distilled knowledge only leaves the Lab after every project, product, and person name is stripped:
  **patterns, not identities.**

To enable the guards after cloning: `git config core.hooksPath .githooks`.

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
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository rather than opening a public issue. This is an experimental, single-maintainer
project, so expect a best-effort response.
