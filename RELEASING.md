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

`master` requires a pull request and four passing checks (`check`, `suites`, `analyze`,
`shellcheck`). No
approval is required, so you are never blocked waiting on yourself. The PR exists so CI runs
**before** the code is on `master`, and so the diff gets read once outside the context that wrote
it.

`pre-push` runs the installer and agent-surface suites locally whenever the push touches
`install.sh`, `cli/`, `bin/`, `tests/`, `hooks/` or `scripts/`, so you find breakage in seconds
rather than in a CI queue. `MM_SKIP_TESTS=1 git push` overrides it and says so out loud.

## Tags are immutable once pushed

`.github/tag-ruleset.json` stops any `v*` tag being moved or deleted, by anyone, with no bypass.
Apply it once:

```
gh api --method POST repos/mehrad-dm/mastermind/rulesets --input .github/tag-ruleset.json
```

It deliberately does **not** restrict tag creation. Creating a tag is already gated by the
release workflow, which refuses a commit that is not on `master`, and a creation rule with a
mis-set bypass would lock releases out entirely. Moving a tag is the real damage: the CLI pins a
commit and refuses a clone that does not match it, so a moved tag breaks every install rather
than fixing any, and it makes the GitHub source archive disagree with what npm serves.

## What the website repository does not have

`mastermind-site` runs CI on pull requests, but nothing requires it to pass: rulesets and branch
protection are gated behind a paid plan for private repositories, and that repository is private.
A direct push to `main` therefore deploys without CI. This is a known and accepted gap, not an
oversight. Closing it means making the repository public or upgrading the plan. Until then, treat
`verify-release.sh` and the daily `site-live` run as the checks that actually cover the site.

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
git tag -a v0.31.0 -m "v0.31.0: <the changelog's opening line>"
git push
git push origin v0.31.0        # this is what publishes
git -C ../mastermind-site push # this is what deploys the site
```

Pushing the tag is the only irreversible step. Nothing reaches npm before it.

### 4. What CI does with the tag

`publish.yml` will not publish unless, on that exact commit:

- the tagged commit is an ancestor of `origin/master`. A ruleset protects the branch, not the
  tags, so without this a version bump that never saw a pull request or a required check could
  be tagged straight to npm
- the tag matches `VERSION`
- both suites, integrity, router, links, brain lint and the routing eval all pass
- the library pages match the skill and agent sources, when CI can read the site (see below)
- the packed tarball contains exactly `README.md`, `bin/mastermind.mjs`, `package.json`
- **every** platform passes: Linux on Node 18 and 22, macOS, Alpine, WSL, the native-Windows
  refusal guard, and an install from a tarball packed the way the release packs it: the same
  pinned npm, a commit stamp written the same way. That proves the packing recipe produces an
  installable package on this commit. It is not the published bytes: those are packed later, in
  the publish job, after the stamp is written, and are then installed and run there before the
  upload

Then it stamps the commit SHA into the published `package.json`, re-verifies the stamped package
(contents, version against the tag, a real 40-character SHA matching this run), publishes with
provenance, and creates the GitHub Release from the changelog.

The stamp matters: the tarball ships the CLI only, and the brain is cloned at install time. The
stamp is what ties a published version to one commit of this repository, and the CLI refuses a
clone whose `HEAD` does not match it. That is what closes the moved-tag hole.

**The library check needs the site repository, which is private.** It reads it with
`MASTERMIND_SITE_KEY`, a read-only deploy key on `mastermind-site`. If that key is missing or
revoked the checkout fails, and the gate fails with it: no release goes out. A check that
skips itself when its input disappears is a check that can pass by failing, which is the exact
failure this process exists to prevent. To ship anyway, set the repository variable
`MM_ALLOW_UNCHECKED_LIBRARY=1`; the job summary then records that the library pages were not
compared against the instructions behind them, so the gap is on the record rather than silent.

### The website is checked separately

`site-live.yml` runs daily and on demand against the deployed site, over HTTP, needing no
repository access. It checks the version it shows, the pages people land on, the security
headers, the content policy, and that every skill and agent we ship has a live page.

It deliberately does not run on the release tag. The site is deployed from its own repository
*after* the package tag is pushed, so running it then would test the previous deployment. The
release checks the site with `verify-release.sh`, after the site push.

### 5. Verify all three surfaces agree

```
scripts/verify-release.sh 0.31.0
```

Checks the tag and every version location, that npm serves that version, that the published
package is stamped with the commit the tag points at, that the site shows it, that the site's CSP
allows the origin the embedded map actually resolves to, and that a Release object exists.
Read-only.

Run it **after** pushing the site, not before: it reads the deployed site, so running it earlier
reports the previous deployment.

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

**The gate says the site repository could not be read.** `MASTERMIND_SITE_KEY` is missing,
revoked, or no longer valid on `mastermind-site`. Regenerate a read-only deploy key there and
set the secret again; releases are blocked until then. Setting the repository variable
`MM_ALLOW_UNCHECKED_LIBRARY=1` ships without that evidence, and while it is set the published
pages are not being compared against the skill and agent sources: only a person reading the
pages would notice a mismatch. Remove the variable once the key works again.

**A test fails only on macOS.** That is bash 3.2 and the `/tmp` and `/var` symlinks, which caused
four separate path defects. Always resolve both sides of a path comparison before comparing them.
