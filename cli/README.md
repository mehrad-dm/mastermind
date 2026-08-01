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

Why npx over `curl | bash`: every release is a versioned, immutable, provenance-signed npm
artifact, and fresh installs pin the brain to the matching git tag — you always know exactly
what ran. The brain lives at `~/.mastermind` (a plain git repo you can read end to end);
projects get their own committed copy in `<project>/.mastermind/`.

MIT · [source](https://github.com/mehrad-dm/mastermind)
