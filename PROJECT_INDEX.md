# Project Index

Navigation only — not a status report. For details, read the named
project's own `PROJECT_STATUS.md` (or `HANDOVER.md` for `reference-client`,
which predates this convention). Update this file's `Latest`/`Next` line
when either project's state changes; do not grow this file beyond that.

**Core rule (why this file and the per-project status files exist):**
A task is not complete until its state is verified, recorded, and committed.

## Active

### ai-control-plane
- Path: `<ai-control-plane-repo>`
- Status: 2026-07-14 reusability audit's P1-P5 hardening landed
- Latest: `2868539` (P1-P5), `dbdc776` (PROJECT_STATUS.md)
- Next: none open — P6 (real second-client attach test) and the
  test-harness environment fix are deferred, see its `PROJECT_STATUS.md`

### reference-client
- Path: `<client-repo>`
- Status: Reliability Hardening sprint complete (skill routing, hook
  fixes, session-close); privacy/export-boundary docs added same day
- Latest: `10d2807` (privacy: information registry + export-boundary
  checklist)
- Next: portfolio/career packaging — not further infrastructure work,
  see `HANDOVER.md`

## Archived

(none yet)
