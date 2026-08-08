# mastermind-brain

The trusted installer for [MasterMind](https://mastermind.mehrad.me) — a genius-builder brain
for Claude Code, Cursor and Codex.

```bash
cd my-project
npx mastermind-brain            # install into this project (all your AI tools)
npx mastermind-brain --global   # Claude Code in every project
npx mastermind-brain check      # doctor — is this project wired?
npx mastermind-brain update     # refresh the brain + repair links
npx mastermind-brain uninstall  # clean removal
```

## Commands an agent calls for itself

Cursor and Codex have no native skill mechanism, so an agent there either pastes the whole
library into context or guesses a path. These lookups answer from whichever brain the current
directory belongs to — the project's own `.mastermind/` first, then the shared clone:

```bash
mastermind skills                    # the routing table: every skill, one line each
mastermind skill performance         # one skill's full instructions
mastermind agents                    # the isolated-context roles
mastermind route "why is this slow?" # the table again, with keyword matches arrowed
mastermind wrong-log                 # every time MasterMind was wrong, and what caught it
mastermind conflicts                 # what else is installed, and where it overlaps us
```

Add `--json` to any of them for structured output. They are read-only: no install, no
network, no writes — if no brain is installed they say so and exit non-zero. Without a global
install, call the shim in the clone: `~/.mastermind/bin/mastermind skills`.

Most machines end up with several skill packs installed. `conflicts` lists the foreign skills it
can see and where their triggers overlap ours; it reports rather than resolves, because measured
routing barely moves in a crowded install (7/8 either way). Precedence when they disagree: your
project's own skills → installed packs → MasterMind defaults, and on a *rule* conflict the stricter
rule wins.

`route` deliberately does not shortlist. Keyword overlap picks the right skill for requests
phrased like the descriptions, but only hints correctly for 2 of 8 requests phrased the way
people actually talk ("the invoice screen takes nine seconds to open"), so it marks candidates
and always returns every option — hiding the right skill behind a confident guess would be
worse than not guessing. The model routes; this just puts the table in front of it.

Why npx over `curl | bash`: every release is a versioned, immutable, provenance-signed npm
artifact, and fresh installs pin the brain to the matching git tag — you always know exactly
what ran. The brain lives at `~/.mastermind` (a plain git repo you can read end to end);
projects get their own committed copy in `<project>/.mastermind/`.

MIT · [source](https://github.com/mehrad-dm/mastermind)
