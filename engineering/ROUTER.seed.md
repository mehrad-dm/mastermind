# ROUTER — task → the exact files to load

**No routes yet.** The router is a prebuilt index over *this project's* field pack — and this
project has no field yet. Until one exists, there is nothing to route: load the kernel, and use a
field's own `field.md` load-on-demand map once you have one.

The router is **never a dependency** — it only ever speeds things up. When it's missing or a
`hash` no longer matches its file, ignore it and fall back to `field.md`.

## How this file gets filled

`init` builds the field for this project's stack (from `engineering/fields/_template/`). After a
field exists, regenerate this index from it so each task loads only the one or two files it needs:

```bash
node scripts/build-router.mjs   # in the MasterMind source clone
```

It's deterministic — no AI, no network — and self-invalidates on any file change, so it can never
silently point at stale content.
