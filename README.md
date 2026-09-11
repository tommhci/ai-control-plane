# AI Control Plane

[![verify](https://github.com/tommhci/ai-control-plane/actions/workflows/verify.yml/badge.svg)](https://github.com/tommhci/ai-control-plane/actions/workflows/verify.yml)

Reusable AI collaboration infrastructure for product repositories.

## What This Is

A control plane for AI-assisted software development. It provides:

- **Session state**: append-only JSONL log, ownership file, effectiveness log
- **Protected-path hooks**: pre-commit and write-guard hooks block accidental edits to governance files
- **Workflow skills**: reusable skill scripts (`session-close`, `plan-freeze`, `verify-task`, etc.)
- **Protocols**: Darwin check charter, multi-agent workflow, failure recovery, worktree policy
- **Adapter system**: thin per-project config so the control plane generalizes across repos

## Who This Is For

Teams or individuals using AI coding agents (Claude Code, Codex, Cursor, Kiro, or similar) who want:

- consistent session governance across AI tools
- protected-path enforcement at commit time
- reusable cross-tool skill library
- audit trail for AI-driven decisions

## Adopting This Control Plane

Use `installers/attach-project.ps1` for existing projects and
`installers/init-project.ps1` for new projects. These are the productized
entrypoints; they create the thin local files AI tools can discover from the
client repo root, then wire `.control-plane/adapter.json` back to this shared
control plane.

Attach an existing project:

```powershell
& "<ai-control-plane-repo>\installers\attach-project.ps1" `
  -ClientRoot "C:\path\to\existing-project" `
  -Profile claude-code `
  -Tier minimal
```

Initialize a new project:

```powershell
& "<ai-control-plane-repo>\installers\init-project.ps1" `
  -ProjectRoot "C:\path\to\new-project" `
  -Profile claude-code `
  -Tier minimal `
  -GitInit
```

Tiers:

| Tier | Use when | Local files created |
|------|----------|---------------------|
| `minimal` | Course projects, small repos, early prototypes | `AGENTS.md`, `AI_BOOTSTRAP.md`, `PROJECT_STATUS.md`, `CLAUDE.md`, `ACTIVE_CONTEXT.md`, `.control-plane/`, `.agents/` |
| `standard` | Repos that need queue/handover/governance workflow | Minimal files plus `HANDOVER.md`, `NODE_QUEUE.md`, `PROJECT_GOVERNANCE_TIERS.md`, `SETUP_CHECKLIST.md`, `governance/` |

`adapters/README.md` remains the lower-level adapter reference. Use it when
debugging or extending the attach protocol, not as the normal first command.

`adapters/reference-client/` is a worked example adapter (contains no private data).

Profile behavior:

| Profile | Status | What attach/init does |
|---------|--------|-----------------------|
| `claude-code` | verified | Creates discovery files, installs `.claude/settings.local.json`, git hooks, repo-local hook wrappers, syncs shared skills, then runs the full installer health check |
| `codex` | experimental | Creates discovery files and `.control-plane/` adapter files, then runs lightweight attach health; hook integration is not claimed |
| `cursor` | experimental | Creates discovery files and `.control-plane/` adapter files; Cursor-specific permission behavior is not verified |
| `generic` | stub | Creates portable Markdown/adapter files only |
| `opencode` | experimental | Creates discovery files and `.control-plane/` adapter files; AGENTS.md and `.agents/skills/` discovery are native OpenCode mechanisms; permission/hook integration not wired |

Do not claim cross-tool hard enforcement for profiles marked experimental or
stub. They still benefit from local discovery files (`AGENTS.md`,
`AI_BOOTSTRAP.md`) and shared project state, but hook behavior is not verified.

## What Is an Adapter?

An adapter is a thin JSON config that tells the control plane:

- where your project's state files live
- which paths are protected from AI writes
- what verification commands apply to your repo
- how to wire local hooks back to the shared scripts

The control plane reads the adapter; your product repo stays product-focused.

## What Is Intentionally Not Included

- Product-specific queues, handovers, or governance documents
- Real decisions, variables, evidence, or personal workflow data
- Project-specific seed data or domain configuration

These live in your product repo. The control plane provides the infrastructure layer only.

## Skills

Shared reusable skills are in `skills/`. Each skill is a markdown procedure file:

| Skill | Purpose |
|-------|---------|
| `session-close` | End-of-session snapshot and effectiveness log |
| `plan-freeze` | Commit to a bounded change plan before editing |
| `verify-task` | Confirm scope, diff, and test/build outcome |
| `publish-safe` | Pre-commit / pre-push gate |
| `node-intake` | Confirm active node and worktree state |
| `evidence-check` | Verify factual or evaluative claims |
| `challenge-review` | Structured challenge to AI-generated proposals |
| `handoff` | Cross-session and cross-tool state transfer |

## Protocols

Shared protocol documents are in `protocols/`:

- `AIS_charter.md` — Darwin check trigger (constitutional AI quality layer)
- `pre-task-decision-flow.md` — pre-task mode and node confirmation
- `failure-recovery-flow.md` — unified failure and recovery decision tree
- `route-based-continuous-execution.md` — route authorization and auto-continue rules; reduces per-step interruptions within a bounded scope
- `multi_agent_workflow.md` — when and how to fan out to multiple agents
- `worktree-first-policy.md` — isolation policy for parallel AI agents
- `permissions-ask-mode.md` — Claude Code permissions baseline rationale

### Task Specification

- `protocols/task-specification-layer.md` - adaptive contract depth, risk
  routing, lifecycle, and consumer rules
- `protocols/task-contract.schema.json` - machine-checkable Task Contract structure
- `protocols/task-spec-adapters.md` - the bounded v1 adapter set

## Tests

```powershell
# Verify a client attachment is healthy (comprehensive — 9 check categories,
# ~17 individual checks: adapter fields, resolver, hooks, git hooks, Claude
# settings, protected paths, .agents/ dir, shared-skill sync, write-guard smoke
# test). This is the recommended health check for verifying an attach:
.\installers\health-check.ps1 -RepoRoot <your-repo>

# Run from repo root
.\tests\test_permissions_profile.ps1
.\tests\test_git_protected_paths.ps1
.\tests\test_drift_scanner.ps1
.\tests\test_worktree_helpers.ps1
.\tests\test_task_specification_layer.ps1
.\tests\test_project_attach_init.ps1

# Requires a real session_log.jsonl from a client repo:
.\tests\test_state_store_migration.ps1 -InputPath <path-to-session_log.jsonl>
```

**Resolved — test harness LF-warning handling (2026-08-23):** Test scripts that
invoke `powershell -File ...` as a subprocess no longer exit 1 when inner git
commands emit LF→CRLF warnings to stderr. The write-guard negative-control in
`installers/health-check.ps1` now passes `-NoProfile` to the inner child, which
prevents PS 5.1 hosts from consuming the stdin pipe during profile lookup (the
root cause of the PBR-TestHarness class). Verified 2026-08-23: both
`test_project_attach_init.ps1` (25/25) and `test_dummy_client_attach.ps1`
(PASS) across 3 consecutive runs on PS 5.1 and pwsh7 hosts; a mutated
protected-paths list still hard-stops health-check (exit 1, negative control).

## License

Apache-2.0. See [LICENSE](LICENSE) for details.

Copyright 2026 tommhci and contributors.

## Current Status

Published deliberately as a portfolio and reference implementation (owner decision,
2026-09-11). It is not a supported production release.

- Initial extraction: complete
- Public-boundary audit: last full audit 2026-06-28; an AI-assisted re-screen on
  2026-09-11 found no credentials, no personal data, and no content from the private
  working repositories, and flagged a small number of cosmetic disclosures (client
  project names, one local dev path) for cleanup
- Release-readiness: reference implementation only — no release artifact is published
- Example adapter: `adapters/reference-client/` (worked example; contains no private data)

## Health Check (lightweight)

`scripts/check-attach-health.ps1` is a narrower, faster check (7 checks:
adapter presence/parse/fields, `controlPlaneRepo` resolution, protected-paths
presence/parse, ownership file presence, deprecated-repo-name leakage). It is
what `AGENTS.md`'s own internal Attach Workflow uses for a quick pass/fail
signal. For full attach verification use `installers/health-check.ps1` above.

```powershell
& "C:\path\to\ai-control-plane\scripts\check-attach-health.ps1" -ClientRoot "C:\path\to\client-repo"
```

Exits 0 if all checks pass. Run after attach and after any adapter.json changes.

## Security Scanner

These scanners target attached client repositories. Do not use `ai-control-plane` itself as `-ClientRoot`; it intentionally does not have a client adapter or client hooks, so that produces false HIGH findings.

Scan a client repo for security issues (exposed secrets, missing hooks, invalid config):

```powershell
& "C:\path\to\ai-control-plane\security\scan_client_security.ps1" -ClientRoot "C:\path\to\client-repo"

# Machine-readable output:
& "...\scan_client_security.ps1" -ClientRoot "C:\path\to\client-repo" -OutputJson ".\scan-result.json"

# Fail with exit 1 if any HIGH findings:
& "...\scan_client_security.ps1" -ClientRoot "C:\path\to\client-repo" -FailOnHigh
```

Checks: `.env` file detection (path reported, content never read), invalid adapter JSON, missing pre-commit hook, dangerous `settings.local.json` permission patterns, prompt-injection phrases in markdown, secrets in config files. Score: 100 − (HIGH×25 + MEDIUM×10 + LOW×3).

Run the scanner test suite:

```powershell
.\tests\test_security_scanner.ps1
```
