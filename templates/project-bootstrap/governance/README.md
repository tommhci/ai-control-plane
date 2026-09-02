# Governance

This directory is the canonical home for project instructions, status, and decision records.

## What lives here

- `agent-constitution.md` — project definition + absolute constraints + inviolable rules
- `product-vision.md` — positioning anchor (create when needed; load on-demand only)
- `decisions/` — Architecture Decision Records (ADR-*.md)
- `README.md` — this file

## Reading order

For the complete canonical reading order, see [`AI_BOOTSTRAP.md`](../AI_BOOTSTRAP.md).

Short form:
1. `README.md` (project root)
2. `NODE_QUEUE.md`
3. `AGENTS.md`
4. `governance/` ← you are here

## Rules

- `governance/` is authoritative for rules and records.
- If a tool adapter (CLAUDE.md, .cursor/rules/, etc.) conflicts with governance/, assume the adapter is stale.
- Modifying `governance/` files is a HARD STOP in CONTINUOUS mode — always requires user confirmation.

## Decision Records

Format for ADR files: `ADR-XXX-short-title.md`

Each ADR must include:
- Context: why this decision was needed
- Decision: what was decided
- Why rejected alternatives: with reopening conditions
- Status: open / closed / superseded
