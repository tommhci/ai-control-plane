---
infra_version: 1.0
version_note: bump when a promoted cross-project workflow rule changes the template
---

# Project Bootstrap Template

Use this to bootstrap a brand-new project's AI collaboration governance layer
from zero — before or alongside attaching `templates/project-adapter/` (which
wires the *technical* machinery: hooks, ownership file, adapter config). This
directory provides the *content* machinery: the starter governance files
themselves.

## How to use

1. Copy this entire `project-bootstrap/` directory into the new project root.
2. Search for every `TODO:` marker and replace it with project-specific content.
3. Copy `skills/` from this repo (`ai-control-plane/skills/`) into the new
   project's `.agents/skills/`. The skills are generic and do not depend on
   the current project's domain.
4. Also attach `templates/project-adapter/` (see its own README) for the
   technical wiring — adapter.json, protected-paths.json, hooks.
5. Copy the tool adapters for the AI systems you actually use: `.cursor/` and
   `.kiro/` are optional but supported.
6. Delete this file after bootstrapping.

## File map and what to customize

| File | Action |
|------|--------|
| `AGENTS.md` | Keep the Session Quality Layer; replace the project stack and core file constraints in "How to work here". |
| `AI_BOOTSTRAP.md` | Update the canonical source list if the new project uses a different root structure. |
| `CLAUDE.md` | Thin adapter; keep the `@AGENTS.md` / `@AI_BOOTSTRAP.md` imports. |
| `HANDOVER.md` | Start from empty; keep the same format. |
| `NODE_QUEUE.md` | Clear the nodes; keep the same format. |
| `governance/agent-constitution.md` | Rewrite: project definition, architecture, invariants, and hard constraints. |
| `governance/README.md` | Light edits are enough. |
| `PROJECT_GOVERNANCE_TIERS.md` | Read before trimming the template; choose Lite / Standard / High-Governance before deleting files. |
| `SETUP_CHECKLIST.md` | Work through this checklist first — under 10 minutes. |
| `ACTIVE_CONTEXT.md` | Copy as-is; it bootstraps the active-task checkpoint surface. |

## What you do not need to copy

- `governance/decisions/ADR-*.md` — create new ADRs only when the new project needs them.
- `governance/product-vision.md` — create only if the new project needs a positioning anchor.
- Any code under `src/`.
- High-Governance-tier files when you chose `Lite` or `Standard` — remove them rather than leaving stale unused protocol docs (see `PROJECT_GOVERNANCE_TIERS.md`).

## Skills copy method

```bash
# Copy the shared skills from this control plane
cp -r /path/to/ai-control-plane/skills /path/to/new-project/.agents/skills
```

Two known adaptation points for non-Node.js projects:
- `session-close` and `node-intake` reference `npm test` by default — replace with your project's test command (or use `.control-plane/verification.json`'s `verificationCommand`, which several skills already check for first).
- Any skill referencing `governance/product-vision.md` is safe to run without it; it degrades gracefully.

## Minimal usable package

If you only have 5 minutes, copy these files first:

1. `AGENTS.md` — Session Quality Layer + execution mode rules
2. `AI_BOOTSTRAP.md` — cross-tool handover protocol
3. `HANDOVER.md` — session snapshot template
4. `NODE_QUEUE.md` — node ledger template
5. `PROJECT_GOVERNANCE_TIERS.md` — tells you what to keep vs trim before first use

That package captures most of the collaboration value.

## Recommended bootstrap order

1. Run `SETUP_CHECKLIST.md`.
2. Read `PROJECT_GOVERNANCE_TIERS.md` and choose `Lite`, `Standard`, or `High-Governance`.
3. Delete files above the chosen tier before the first AI session.
4. Attach `templates/project-adapter/` for the technical wiring.
