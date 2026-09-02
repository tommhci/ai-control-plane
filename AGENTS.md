# AI Operator Guide — ai-control-plane

## What This Repo Is

- **ai-control-plane** is a cross-project AI collaboration platform
- This repo provides: adapter protocol, git hooks, installer scripts, healthcheck, session logging, skills lock
- Client repos install from here and use the platform (per-client adapters live in `adapters/` — see `adapters/README.md`)
- This is platform/infrastructure code — not a product

## Optional Cognitive Authority Layer

Some operators maintain a private, personal protocol repo that sits *above* this
runtime control plane — defining human judgment boundaries (judgment before
evidence, fact/assumption/inference distinction, explicit gap marking), what AI
may automate vs. what requires human-first, a success-criteria-definition gate
before execution, and session-drift/avoidance detection.

If such a layer exists for your setup, wire it in via your own adapter (a local,
untracked reference file — do not commit its path or content into this shared
repo). ai-control-plane enforces runtime boundaries (hooks, permissions,
protected paths) but does not — and should not — hard-code a dependency on any
operator's private layer here. Runtime automation should still stop at whatever
agency gates that private layer defines:
- AI may suggest but cannot write without human confirmation
- AI may execute engineering diagnostics but must stop for direction/priority changes
- AI may challenge but cannot substitute the human operator's judgment on capability-forming tasks

## Output Language

All output must be in English or Chinese. No Korean, Japanese, or other languages.

## Role Separation

| Context | Allowed actions |
|---------|----------------|
| Editing this repo | Platform improvements only — hooks, adapters, templates, scripts, tests |
| Editing a client repo | Client-specific attach files only (.control-plane/, .agents/) |
| Cross-repo | Read clients for reference; never copy private client data here | 

## Layering (G/R/L)

Content divides into three layers. Pointer direction is one-way: client
repos point up to G; G never references a client's internal structure.

| Layer | Where | Content | Boundary rule |
|-------|-------|---------|---------------|
| G — global canon | this repo | lessons registry, AGENTS.md contract, hooks/, installers/, protocols/ | Rule bodies carry no project names, no client-specific paths, no machine-absolute paths; provenance = date + event type only |
| R — control-plane records | this repo | PROJECT_STATUS.md, docs/audits/ | May name clients (working-log function); machine-absolute paths still de-identified to placeholder form |
| L — client-local | each client repo | project-specific lessons, findings, conventions | Client first-read chains point up one line to G; G never references L internals |

Enforcement is mechanical, not disciplinary: `scripts/boundary-lint.ps1`
(binary, exit 0/1) runs in CI and the monthly patrol. Reviewed exceptions
carry a `boundary-lint:allow` line marker.

## One-Writer Rule

Before writing any file in this repo:
1. Check .agents/ACTIVE_EDIT_OWNERSHIP.md for active locks
2. Only one agent may stage/commit/edit at a time
3. Release ownership in ACTIVE_EDIT_OWNERSHIP.md when done

## Attach Workflow

Normal entrypoints:

```powershell
& <ai-control-plane-repo>\installers\attach-project.ps1 -ClientRoot <existing-project> -Profile claude-code -Tier minimal
& <ai-control-plane-repo>\installers\init-project.ps1 -ProjectRoot <new-project> -Profile claude-code -Tier minimal -GitInit
```

Use `minimal` for course projects, prototypes, and product repos that only need
AI discovery/context files. Use `standard` when the client should also receive
queue, handover, and governance starter files.

The older manual steps (copy `templates/project-adapter/`, replace placeholders,
create `.agents/ACTIVE_EDIT_OWNERSHIP.md`, run `scripts/check-attach-health.ps1`)
are now the low-level fallback for debugging attach failures, not the default
human workflow.

Profile truth:
- `claude-code` is verified and attach/init must install hooks, settings, and
  shared skills, then run the full installer health check.
- `codex`, `cursor`, and `generic` are discovery/adapter profiles only until
  their hook/permission models are verified. Do not report them as hard
  enforcement surfaces.

## Release and Public Boundary

- This repo is private-by-default. Treat it as public-candidate only after a fresh boundary audit.
- **Never commit:** private credentials, absolute paths to private machines, client product data or documents, personal information
- **Never push** without explicit owner authorization
- **Never create** a GitHub release or change repo visibility without owner authorization

## Change Flow (risk-proportional, simplified 2026-08-28)

Process weight follows stakes (the repo's own "verify in proportion to the
stakes" principle, applied to process itself):

1. **Routine changes (default): direct push to main.** Docs, tests, scripts,
   bug fixes, register/status updates. CI (`verify` workflow) runs on every
   push and is the quality gate: green = landed, red = fix forward. No branch,
   no PR, no ceremony. Session-level "verified" claims are not acceptance
   evidence — CI green is.
2. **Governed paths (enforcement layer): owner approval before commit.**
   `hooks/`, `security/`, `protocols/`, `skills/`, `templates/`,
   `protected-paths.json`, `AGENTS.md` itself. These files change what the
   system enforces; they keep the existing `approve_governance_commit.ps1`
   flow regardless of push method.
3. **Authorization records: verifiable citation required.** Any
   "owner-authorized" claim in docs or commit messages must cite a verifiable
   owner-acted artifact (owner-merged PR, or an owner-executed commit).
   Without one, mark and treat as **authorization unconfirmed** — findings
   register maintenance rules (P1 rule, 2026-08-28). This applies to decision
   records only, not to routine commits.
4. **Branch + PR: optional.** Use when the owner asked to review before
   landing, or the change is large/ambiguous. Not the default path.

Rationale (2026-08-28): the blanket PR-only rule made every routine change a
multi-step ceremony for a solo operator. Quality is enforced by CI on every
push; authority is enforced by the governed-path approval flow; only
*decision records* need non-repudiable citations. Nothing else justifies the
tax.

Enforcement ceiling (2026-08-29): the client-side layer (git hooks, the
approval-token flow, boundary checks) is friction + audit trail, not a hard
security boundary. `--dangerously-skip-permissions`, `claude -p` pipe mode,
and simply uninstalling hooks silently disable all of it, and `git commit
--no-verify` is not recorded anywhere by git itself. The only
non-bypassable backstop is server-side: the verify workflow on every push
plus branch protection on main. Treat client-side enforcement as noise
reduction with an audit trail; trust CI green.

## Smoke Before Commit

- Run tests/ suite before committing platform changes
- Use scripts/check-attach-health.ps1 to validate client attach after platform changes
- Exit 0 = proceed; any failure = hard stop before commit

## Forbidden Actions

- Do not touch <sensitive-client-repo> or any unknown sensitive repo
- Do not perform broad platform redesign without a phase/node authorization
- Do not add SQLite, dashboard, MCP server, scheduler, or public demo without explicit owner decision
- Do not amend, rebase, or force-push

## Session Start Checklist

1. git status --short — classify dirty files
2. Read .agents/ACTIVE_EDIT_OWNERSHIP.md — check for conflicts
3. Identify active phase/node before writing
4. Before repair/deletion work: check the findings register (docs/audits/)
   and the lessons registry (docs/cross-tool-lessons.md) — never rebuild or
   delete while a clean source may exist (lessons L2/U4)
5. If this session touches governed paths or performs destructive /
   irreversible operations: read protocols/MULTI_AGENT_TRIGGER.md first
   (paired-audit gate: single writer + read-only auditor; capability
   saturation gate) (added 2026-08-29)
