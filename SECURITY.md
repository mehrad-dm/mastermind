# Security

MasterMind is a markdown knowledge base plus a few small, dependency-free scripts. It ships no server
and executes no untrusted input, so the security surface that matters here is a specific one:
**keeping private or client material out of this public repository and its history.**

## The Lab quarantine

Anything derived from a real, possibly-private codebase stays in `lab/`, which is gitignored. Two
`.githooks/` guards enforce it:

- **pre-commit / pre-push** block any staged change that contains a quarantined `lab/` path, a
  denylisted identifier, or a common secret pattern (keys, tokens).
- Distilled knowledge only leaves the Lab after every project, product, and person name is stripped —
  **patterns, not identities.**

To enable the guards after cloning: `git config core.hooksPath .githooks`.

## Reporting a vulnerability

If you find leaked private data in the repo or history, a way to bypass the guards, or any other
security issue, please **report it privately** via GitHub's
[private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
on this repository rather than opening a public issue. This is an experimental, single-maintainer
project — expect a best-effort response.
