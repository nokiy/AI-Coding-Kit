# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`docs/context/CONTEXT.md`** — always the entry point
- Multi-context repos: `CONTEXT.md` is the business overview + domain index — read the relevant
  **`docs/context/<domain>.md`** for your topic
- **`docs/adr/`** — read ADRs that touch the area you're about to work in

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest
creating them upfront. `loki-pm:domain-modeling` (reached via `grill-with-docs` /
`improve-codebase-architecture`) creates them lazily when terms or decisions actually get resolved.

## File structure

```
docs/
├── context/
│   ├── CONTEXT.md      ← entry point: single context = the whole glossary lives here;
│   │                      multi-context = business overview + domain index
│   └── <domain>.md     ← multi-context only, one per domain (file name = the module
│                          name from architecture.md §3)
└── adr/
    ├── 0001-event-sourced-orders.md
    └── 0002-postgres-for-write-model.md
```

Single grows into multi with zero migration: `CONTEXT.md` becomes the overview + index in place,
domain files grow beside it, no reference path changes. No separate MAP file.

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis,
a test name), use the term as defined in `CONTEXT.md`. Don't drift to synonyms the glossary
explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal — either you're inventing
language the project doesn't use (reconsider) or there's a real gap (note it for
`loki-pm:domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders) — but worth reopening because…_
