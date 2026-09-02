# Permissions Ask-Mode Profile

Status: installable baseline.

## Purpose

Use Claude Code permissions as a second boundary below hooks. Hooks enforce
project-specific checks; permissions make risky tool classes ask before running.

## Install

```powershell
powershell -ExecutionPolicy Bypass -File <control-plane>/installers/install-permissions-profile.ps1 -RepoRoot <client-repo>
```

To install a client-specific profile:

```powershell
powershell -ExecutionPolicy Bypass -File <control-plane>/installers/install-permissions-profile.ps1 -RepoRoot <client-repo> -ProfilePath <client-repo>/.control-plane/permissions-baseline.json
```

## Rollback

The installer writes a backup next to the settings file:

```powershell
Copy-Item -Force <client-repo>/.claude/settings.local.json.permissions-backup <client-repo>/.claude/settings.local.json
```

## Policy

- `deny`: destructive operations with high irreversible risk.
- `ask`: network, agent dispatch, settings edits, skills edits, MCP config edits, protected-path-adjacent edits, dependency installs, push/merge operations.
- `allow`: routine read-only git inspection and local verification commands.

Do not use permissions as the only protected-path control. Keep the client
`.control-plane/protected-paths.json` hook active.
