# Skills

This directory holds reusable cross-project workflow skills for the control plane.

Current extraction policy:

- copy in low-coupling skills first
- copy adapter-aware skills second
- refactor project assumptions only when a real client pressure appears

## Current buckets

- low-coupling:
  - `evidence-check`
  - `challenge-review`
  - `handoff` (behaviorally unvalidated — see the skill's own "Status /
    validation gap" section; no real handoff has exercised it yet)
  - `skill-review`

- adapter-aware — synced, review before reuse on a client with a different product line:
  - `verify-task`
  - `publish-safe`
  - `node-intake`
  - `session-close`
  - `plan-freeze`

These five are already in every adapter's `sharedSkills` and are copied by
`sync-shared-skills.ps1` on attach — they are not held back. `verify-task` and
`publish-safe` read `.control-plane/verification.json` for the client's
verification command instead of hardcoding `npm test`; `plan-freeze` reads
`.control-plane/protected-paths.json` for stop-condition file paths. Before
relying on `node-intake` or `session-close` on a client with a different
product line, review
them for product-line-shaped assumptions (e.g. `session-close`'s localStorage/D7
sections) that only self-limit gracefully rather than being fully generic.

## Local-only (do not extract)

- `doc-sync` — layered-doc status reader for the client line it came from; overlaps `node-intake` and is
  intentionally repo-specific.
- `strategic-alignment` — depends on the source client's product vision, NODE_QUEUE, D7/D9
  history, and sprint cadence; keep local until a generic strategy-audit
  interface exists.

## Rule

Do not turn this into a blind mirror of any single client project's `.agents/skills/`.
Only extract skills that either:

- already generalize cleanly, or
- are under active adapter refactor.
