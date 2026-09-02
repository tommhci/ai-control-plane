# New Project Setup Checklist

Copy this template into a new repo, then fill in every `TODO` before the first AI session.
Target: under 10 minutes. If it takes longer, the TODO is too vague.

---

## Step 1 — Fill in project identity (2 min)

- [ ] `governance/agent-constitution.md` → replace every `TODO` with one sentence each
  - Project name + what it is NOT
  - Core data flow (or delete the section if not applicable)
  - Tech stack
  - Single-user vs multi-user; local-first vs cloud-first
  - Core files that must not be touched without explicit node authorization
  - Four inviolable rules (or three if you only have three)

- [ ] `AGENTS.md` → fill in:
  - `## How to work here` → tech stack + core protected files
  - `## After Every Change` → the test/build command (e.g., `npm test`, `pytest`, `cargo test`)
  - `## Execution Modes / CONTINUOUS` → the gate command (same as above)

- [ ] `AI_BOOTSTRAP.md` → no TODOs in template; verify it points to the right files for YOUR repo.
- [ ] `PROJECT_GOVERNANCE_TIERS.md` → choose `Lite`, `Standard`, or `High-Governance` before first use.

---

## Step 2 — Choose governance tier and trim (2 min)

- [ ] Pick one tier from `PROJECT_GOVERNANCE_TIERS.md`
  - `Lite` = minimal solo package
  - `Standard` = normal repeated-session project
  - `High-Governance` = audit-heavy / multi-agent / high-drift-risk project
- [ ] Delete files above the chosen tier now, before the first AI session.
- [ ] If you are not planning multi-agent review, delete:
  - `.agents/protocols/MULTI_AGENT_TRIGGER.md`
  - `.agents/MULTI_AGENT_ROI_LOG.md`

---

## Step 3 — Seed the work queue (2 min)

- [ ] `NODE_QUEUE.md` → replace the placeholder with your first 2–3 real nodes
  - One ACTIVE node (what you're doing right now)
  - One or two ARMED nodes (next up, unblocked)
  - Any known GATE (external dependency that must clear before you proceed)

---

## Step 4 — Create the HANDOVER snapshot (1 min)

- [ ] `HANDOVER.md` → fill in:
  - Last updated date
  - Test status (e.g., "no tests yet" is fine)
  - Head commit (run `git log --oneline -1`)

---

## Step 4b — Create the workspace pointer (1 min, required for multi-worktree)

The active-workspace guard (see `AI_BOOTSTRAP.md` Session Contract) reads a
pointer file to know which worktree is the current one. It is client-local and
gitignored by design, so it MUST be created on first start — a fresh clone or
new worktree has no pointer and the guard silently disables.

- [ ] Run `git rev-parse --show-toplevel` and write the absolute repo root into
      the pointer file `<workspace-pointer>` (e.g. `.agents/current-workspace.txt`,
      path defined by your project's AI_BOOTSTRAP). No machine paths are
      hardcoded in the template — the file's CONTENT is the real path.
- [ ] Verify it reads back non-empty: `Get-Content <workspace-pointer>`
- [ ] Add the pointer to `.gitignore` (it is per-worktree state, not repo history)
- [ ] Confirm the pointer is checked at session start: see `AI_BOOTSTRAP.md`
      Session Contract, "verify the workspace pointer" step.

> Why: without this, a session started in an archived or stale worktree has no
> signal to stop — the exact failure class of the 2026-08-17 wrong-root incident
> (cross-repo findings register, finding 1 / P2).

---

## Step 5 — Verify tool adapters (2 min)

Run through this list — each item should take 30 seconds:

| Tool | What to check | Done? |
|------|--------------|-------|
| **Claude Code** | `CLAUDE.md` exists and has `@AGENTS.md` + `@AI_BOOTSTRAP.md` imports | [ ] |
| **Codex** | `AGENTS.md` exists at repo root (Codex auto-loads it) | [ ] |
| **Cursor** | `.cursor/rules/project.mdc` exists and points to `AI_BOOTSTRAP.md` | [ ] |
| **Kiro** | `.kiro/steering/bootstrap.md` exists and points to `AI_BOOTSTRAP.md` | [ ] |

If you're not using a tool, skip its row.

---

## Step 6 — Smoke test (3 min)

Open your primary AI tool and give it this prompt:

> "Read AI_BOOTSTRAP.md and tell me: what is the active node, what files are protected, and what is the test command?"

Expected: the tool answers all three correctly from the files, without you repeating them.
If it can't: the canonical sources have a gap — fix the file, not the prompt.

---

## Step 7 — Release Flow smoke test (3 min)

Confirm the first real handoff path works before calling the template complete:

- [ ] `verify-task` can confirm the current node or task and the modified files.
- [ ] `session-close` can update `HANDOVER.md` and capture the session snapshot.
- [ ] `handoff` can produce a clean transition brief for another AI tool or agent.
- [ ] `publish-safe` can decide whether the staged change is safe to commit, push, or PR.

Expected: each step knows where its source of truth lives and does not depend on ad hoc memory.
If any step fails, the template is missing a coordination file or the adapter chain is stale.

---

## What NOT to do

- Do not copy project-specific rules (Decision OS node names, seed data paths, etc.) into the new repo. The template is the structure; your project fills it.
- Do not add tool-specific rules that duplicate `AGENTS.md`. Adapters are thin pointers, not parallel rule sets.
- Do not skip the smoke test. It catches gaps you won't notice until mid-session.
