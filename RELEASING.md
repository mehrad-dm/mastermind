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

The second rule, which cost a version number:

> **A check that only ever runs in one environment has not been tested, it has been rehearsed.**

v0.32.0 passed all 22 local gates and could not publish. One script resolved the website as a
folder beside this repo, which is true on a developer's machine and false in every release run,
where the site is checked out under another name. It had never once run in the layout that
matters. When a check reads anything outside this repository, run it where the release runs it,
or accept that a green result says nothing about that path.

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

Dependabot opens its pull requests against the same checks. The two `github/codeql-action` steps
are grouped in `.github/dependabot.yml`, because they refuse to run at different versions and a
pull request that moves only one of them can never go green. `cross-os` is not a required check,
so a Dependabot pull request that touches it can be merged while one platform is red: read that
run before merging, because the release blocks on every platform.

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

## Releases are immutable too

Immutable Releases is enabled on the repository, so a published Release and its assets cannot be
edited or replaced afterwards. Combined with the tag ruleset, what a version points at is fixed
once it ships.

The publish job creates the Release **after** `npm publish`, and that order is deliberate under
immutability. If the Release step ever fails, npm has the version and GitHub does not, which one
command fixes:

```
gh release create vX.Y.Z --title "vX.Y.Z" --verify-tag --latest --notes-file <(
  awk -v v="## [X.Y.Z]" 'index($0, v) == 1 { on = 1; next } on && /^## \[/ { exit } on' CHANGELOG.md)
```

That prints the body of one section, the same way the publish job extracts it.

The reverse order would leave an immutable Release for a version that never reached npm, which
nothing can clean up.

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

### 2. Move the version, on a branch

`master` takes pull requests only, so the release commit is made on a branch like any other
change. `release.sh` refuses to run on `master`.

```
git checkout -b release/v0.34.0
scripts/release.sh 0.34.0 --dry-run    # show what would change
scripts/release.sh 0.34.0
```

The version is written in several files across **two** repositories: `VERSION`,
`cli/package.json`, `.claude-plugin/plugin.json`, every entry in `.claude-plugin/marketplace.json`,
`mod/.claude-plugin/plugin.json` (the optional Mod ships at the brain's version), the README badge,
and the site's `src/site.config.ts`. Every release that drifted did so because one was updated by
hand and another was not. The script moves all of them, then greps for anything still carrying the
old number and tells you about it. `scripts/check-versions.mjs` checks the ones in this repository
on every pull request, so a drift is found before the tag and not by it.

It also moves the version in the site's `public/llms.txt`, regenerates the library pages (which dates
each New badge), regenerates `architecture.json` and the site's copy of it
(`scripts/build-architecture.mjs`, the data behind the site's diagrams), and redraws the link card
and banners with the site's committed generator, because
those are the details a release kept missing: the link card carried an old version and `llms.txt`
fell two releases behind before anyone looked. `preflight.sh` fails when `llms.txt` lists a different
set of skills than the repo, and `verify-release.sh` checks the live `llms.txt` and that the live link
card is the one on the site's main branch.

It runs `preflight.sh` and stops if anything fails. It does not commit, tag, push or publish.

### 3. Pull request, merge, take the merge commit

```
# -a stages tracked files only, so a release that ADDS a file would ship without it.
git add -A && git commit -m "release: v0.34.0"
git -C ../mastermind-site add -A && git -C ../mastermind-site commit -m "v0.34.0"

git push -u origin release/v0.34.0
gh pr create --fill
gh pr merge --squash --auto          # merges once check, suites, analyze and shellcheck pass

git checkout master
git fetch origin && git reset --hard origin/master    # the squash commit, exactly as GitHub made it

git -C ../mastermind-site push       # the site goes FIRST: the gates check out the pushed site
```

The squash merge makes a **new** commit on `master`. The commit on your branch is not the release:
a tag on it is refused by `pre-push` and by the publish gate, because it is not on `master`.
`git reset --hard origin/master` is used, not `git pull`, because a local `master` that ever held
a commit of its own has diverged: `git pull --ff-only` then refuses, leaves you on the old commit,
and the next `git tag` silently tags the wrong thing.

**The site is pushed before the rehearsal and the tag, and that order is load-bearing.** Both gates
check out the published website and refuse if its version, skill counts, library pages or build
disagree with this repo. Tagging first means the gate reads yesterday's site and fails.

### 4. Rehearse the release on the merge commit, before the tag exists

```
gh workflow run pre-tag.yml --ref master
sleep 5
gh run watch "$(gh run list --workflow pre-tag.yml --limit 1 --json databaseId --jq '.[0].databaseId')" --exit-status
```

`pre-tag.yml` runs everything the publish gate runs, and the whole platform matrix (Linux on two
Node versions, macOS, Alpine, WSL, the native-Windows refusal, the packed tarball), on the commit
you are about to tag. It also runs the checks that need a download and so are kept out of the tag
itself: the gates' own self-tests, the claims check, the architecture data check (it runs a real
install), and Claude Code's plugin validator.

This step exists because the publish workflow runs **after** the tag is pushed, and a pushed tag
cannot be moved. Anything that first fails there burns the version: the only way forward is a new
patch release. The matrix is not a required check on pull requests (it is path-filtered, and a
required check that never runs blocks the merge forever), so a release commit can reach `master`
with a platform red. Here is where that is caught while it is still free.

Do not tag until this run is green. If it fails, fix it through another pull request and run it
again on the new merge commit.

### 5. Tag and push the tag

```
git tag -a v0.34.0 -m "v0.34.0: <the changelog's opening line>"
git push origin v0.34.0        # this is what publishes, and it is the irreversible step
```

Pushing the tag is the only irreversible step, and doubly so: the ruleset forbids moving it,
so a tag on the wrong commit burns that version. `pre-push` refuses a `v*` tag unless its commit
is on `origin/master` and that commit's `VERSION` and `CHANGELOG.md` match the tag.

### 6. What CI does with the tag

`publish.yml` will not publish unless, on that exact commit:

- the tagged commit is an ancestor of `origin/master`. A ruleset protects the branch, not the
  tags, so without this a version bump that never saw a pull request or a required check could
  be tagged straight to npm
- the tag matches `VERSION`
- both suites (with the release-to-release upgrade test required, not skipped), integrity, the
  version locations, router, brain lint, prose, comments, shell patterns, instruction clarity and
  the routing check all pass. Link liveness is deliberately absent: a page on someone else's
  server going down must not burn a version, so links are checked weekly (`freshness.yml`), on
  pull requests as a job that cannot fail the run, and by `preflight.sh` before the release commit
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

### 7. Verify all three surfaces agree

```
scripts/verify-release.sh 0.31.0
```

Checks the tag and every version location, that npm serves that version, that the published
package is stamped with the commit the tag points at, that the site shows it, that the site's CSP
allows no frame on the architecture page (it draws its own diagrams), and that a Release object exists.
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
A missing site checkout, an absent Claude CLI, a link check with no network and a live eval whose
account is out of quota all land here. Decide whether shipping without
that evidence is acceptable, and if it is, set the documented override so the gap is on the record.

**The gate says the site repository could not be read.** `MASTERMIND_SITE_KEY` is missing,
revoked, or no longer valid on `mastermind-site`. Regenerate a read-only deploy key there and
set the secret again; releases are blocked until then. Setting the repository variable
`MM_ALLOW_UNCHECKED_LIBRARY=1` ships without that evidence, and while it is set the published
pages are not being compared against the skill and agent sources: only a person reading the
pages would notice a mismatch. Remove the variable once the key works again.

**A test fails only on macOS.** That is bash 3.2 and the `/tmp` and `/var` symlinks, which caused
four separate path defects. Always resolve both sides of a path comparison before comparing them.
