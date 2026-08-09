# Releasing MasterMind

Users execute this repository. `~/.mastermind` is a clone of `master`, and `git pull` there gets
whatever was pushed last. So `master` being red is not an untidy badge, it is a broken product for
anyone who updates that day. Everything below follows from that.

Four consecutive external audits found real defects while the test suite was green. The rule that
came out of it, and the one this process exists to enforce:

> **A check that can pass by failing is not a check.**

A skipped test that exits 0. A doctor that infers state from artifacts that were deleted. A site
gate that passes because the site is not checked out. A verifier whose answer inverts on long
input. Each of those shipped, each looked green.

---

## Day to day

Work on a branch, open a pull request, let the checks run, merge.

```
git checkout -b fix/whatever
# ... work ...
git push -u origin fix/whatever
gh pr create --fill
gh pr merge --auto --squash        # merges itself once the checks are green
```

`master` requires a pull request and three passing checks (`check`, `analyze`, `shellcheck`). No
approval is required, so you are never blocked waiting on yourself. The PR exists so CI runs
**before** the code is on `master`, and so the diff gets read once outside the context that wrote
it.

`pre-push` runs the installer and agent-surface suites locally whenever the push touches
`install.sh`, `cli/`, `bin/`, `tests/`, `hooks/` or `scripts/`, so you find breakage in seconds
rather than in a CI queue. `MM_SKIP_TESTS=1 git push` overrides it and says so out loud.

## Fixing a bug

Every bug fix ships with a test, and **the test has to fail against the release that had the bug**:

```
scripts/prove-regression.sh v0.30.1              # the whole suite against that release
scripts/prove-regression.sh v0.30.1 'symlink'    # only assertions matching a pattern
```

A test written after a fix passes against the fix by construction. Pointing it at the build that
shipped the defect is the only way to learn whether it detects anything. If a new assertion passes
there, it is decoration: rewrite it until it fails, or delete it.

---

## Cutting a release

### 1. Write the changelog entry first

`CHANGELOG.md` needs a `## [X.Y.Z]` section before anything else runs. It is not paperwork: the
GitHub Release is generated from it, and `release.sh` refuses to proceed without it.

Say what broke and what it cost the user. Never name who found it or how the review was run.

### 2. Move the version

```
scripts/release.sh 0.31.0 --dry-run    # show what would change
scripts/release.sh 0.31.0
```

The version lives in **six** places across **two** repositories: `VERSION`, `cli/package.json`,
both `.claude-plugin` manifests, the README badge, and the site's footer and homepage. Every
release that drifted did so because one was updated by hand and another was not. The script moves
all six, then greps for anything still carrying the old number and tells you about it.

It runs `preflight.sh` and stops if anything fails. It does not commit, tag, push or publish.

### 3. Commit, tag, push

```
git commit -am "release: v0.31.0"
git -C ../mastermind-site commit -am "v0.31.0"
git tag -a v0.31.0 -m "v0.31.0 — <the changelog's opening line>"
git push
git push origin v0.31.0        # this is what publishes
git -C ../mastermind-site push # this is what deploys the site
```

Pushing the tag is the only irreversible step. Nothing reaches npm before it.

### 4. What CI does with the tag

`publish.yml` will not publish unless, on that exact commit:

- the tag matches `VERSION`
- both suites, integrity, router, library, links, brain lint and the routing eval all pass
- the packed tarball contains exactly `README.md`, `bin/mastermind.mjs`, `package.json`
- **every** platform passes: Linux on Node 18 and 22, macOS, Alpine, WSL, the native-Windows
  refusal guard, and an install from the actual stamped tarball

Then it stamps the commit SHA into the published `package.json`, re-verifies the stamped package
(contents, version against the tag, a real 40-character SHA matching this run), publishes with
provenance, and creates the GitHub Release from the changelog.

The stamp matters: the tarball ships the CLI only, and the brain is cloned at install time. The
stamp is what ties a published version to one commit of this repository, and the CLI refuses a
clone whose `HEAD` does not match it. That is what closes the moved-tag hole.

### 5. Verify all three surfaces agree

```
scripts/verify-release.sh 0.31.0
```

Checks the tag and the six version locations, that npm serves that version, that the published
package is stamped with the commit the tag points at, that the site shows it, that the site's CSP
still allows the embedded map, and that a Release object exists. Read-only.

"Keep the repo, npm and the site in sync" used to mean remembering to open three tabs. Every part
of it is a question a command can answer, so this asks them.

---

## When something is wrong

**A published version is broken.** Do not move the tag. The CLI pins a commit and will refuse a
clone that does not match, so a moved tag breaks every install rather than fixing any. Cut a patch
release.

**The site drifted from the repo.** `verify-release.sh` names which surface disagrees. The site
deploys on push to its own repository; the repo does not deploy it.

**`preflight` reports checks it could not run.** That is not the same as passing, and it says so.
A missing site checkout or an absent Claude CLI both land here. Decide whether shipping without
that evidence is acceptable, and if it is, set the documented override so the gap is on the record.

**A test fails only on macOS.** That is bash 3.2 and the `/tmp` and `/var` symlinks, which caused
four separate path defects. Always resolve both sides of a path comparison before comparing them.
