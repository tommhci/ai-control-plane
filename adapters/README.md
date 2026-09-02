# Adapters

Each client repository exposes a thin adapter surface to the control plane.

The client repo keeps:

- project queue
- project handover
- project governance
- project protected paths
- project verification commands

The control plane reads those as inputs instead of hardcoding product assumptions.

## Attaching a new project (3 steps)

**Step 1 — Copy and fill the adapter template:**

```powershell
mkdir <your-repo>\.control-plane
cp C:\path\to\ai-control-plane\adapters\generic\adapter.json <your-repo>\.control-plane\adapter.json
# Edit adapter.json: set controlPlaneRepo to the absolute path of your ai-control-plane checkout
```

Also create two required companion files:

`.control-plane/protected-paths.json` — list of paths AI must not edit without governance approval:
```json
{
  "protectedPaths": ["AGENTS.md"],
  "requireToken": "[governance-approved]"
}
```

`.control-plane/verification.json` — how to verify the project builds/tests pass:
```json
{
  "verificationCommand": "npm test",
  "verificationNote": "Must pass before any node is marked complete."
}
```

**Step 2 — Run the installer:**

```powershell
# From the ai-control-plane repo:
.\installers\install-claude-client.ps1 -RepoRoot <your-repo>
.\installers\sync-shared-skills.ps1    -RepoRoot <your-repo>
```

This writes:
- `.control-plane/hooks/` wrapper scripts (delegating to the shared ACP scripts)
- `.control-plane/resolve-control-plane.ps1` (path resolver)
- `.claude/settings.local.json` (Claude Code PreToolUse + Stop hooks)
- `.git/hooks/pre-commit` and `.git/hooks/post-commit`
- `.agents/skills/` with all shared skills

**Step 3 — Verify:**

```powershell
.\installers\health-check.ps1 -RepoRoot <your-repo>
# Expected: health-check: PASS (17/17 checks)
```

Re-run `health-check.ps1` any time the attach state may have drifted.

## Adapter fields

### Required

| Field | Description |
|-------|-------------|
| `adapterId` | Short slug, e.g. `my-project` |
| `displayName` | Human-readable name |
| `controlPlaneRepo` | Absolute path to your `ai-control-plane` checkout |
| `sharedAdapterPath` | Relative path from ACP root to shared adapter definition (use `adapters/generic/adapter.json`) |

### Optional

| Field | Description |
|-------|-------------|
| `canonicalSources` | Files an AI should read at session start |
| `queueFile` | Work queue file (e.g. `NODE_QUEUE.md`) |
| `handoverFile` | Session snapshot file (e.g. `HANDOVER.md`) |
| `governanceRoot` | Directory containing constitution files |
| `additionalPermissions` | Extra Claude Code permission allow-list entries beyond the base set (e.g. `["Bash(npm run *)"]`) |
| `localOnlySkills` | Skill names that are project-specific and should NOT be promoted to shared |
| `sharedSkillCandidates` | Skills under consideration for promotion to the shared library |

## Current client adapters

- one per-client example adapter directory (identifier-exempt island under the G/L layering rule; ownership tracked as an open item in PROJECT_STATUS.md); contains no private data
- `generic/` — template for new projects; copy `adapter.json` and fill `controlPlaneRepo`
