# hooks/ — Canonical Hook Sources

This directory contains the canonical hook implementations for the ai-control-plane platform.
Client repos do not own copies of these hooks; they install thin wrappers that delegate here.

## Directory Layout

```
hooks/
  git/
    pre_commit_protected_paths.ps1   # Canonical git pre-commit enforcement (adapter-aware)
    templates/
      pre-commit.sh                  # Shell entry point installed into client .git/hooks/
      pre-commit-compat.ps1          # Legacy PS1 forwarder for older local workflows
      post-commit.sh                 # Post-commit session capture template
  claude-code/
    check_write_target.ps1           # Claude Code PreToolUse Write|Edit guard
    protected-paths.txt              # Fallback protected-path list for claude-code hook
```

## Canonical Git Pre-Commit Hook

`hooks/git/pre_commit_protected_paths.ps1` is the single authoritative source for protected-path
enforcement at commit time. It is **adapter-aware**:

1. Reads `protectedPaths` array from `.control-plane/protected-paths.json` in the client repo.
2. Falls back to `["governance/", "AGENTS.md", "AI_BOOTSTRAP.md"]` if the file is missing entirely.

No client-specific paths are hardcoded. The hook works for any client repo that has a
`.control-plane/protected-paths.json` (or no file at all, for the default path set).

## How Clients Install This Hook

Run the installer from the client repo root:

```powershell
& "C:\path\to\ai-control-plane\installers\install-claude-client.ps1" -RepoRoot "." -AdapterDir ".control-plane"
```

The installer writes:
- `.git/hooks/pre-commit` — thin shell wrapper (from `templates/pre-commit.sh`)
- `.git/hooks/pre-commit.ps1` — legacy PS1 forwarder (from `templates/pre-commit-compat.ps1`)
- `.control-plane/hooks/git-pre-commit-protected-paths.ps1` — generated wrapper that resolves the
  control-plane repo at runtime and delegates to `hooks/git/pre_commit_protected_paths.ps1` here

The delegation chain is:

```
.git/hooks/pre-commit (shell)
  → .control-plane/hooks/git-pre-commit-protected-paths.ps1 (generated wrapper)
    → <controlPlaneRepo>/hooks/git/pre_commit_protected_paths.ps1 (this file — canonical)
```

Clients never own a copy. If the canonical hook changes, re-running the installer picks up the
change without requiring any edit to the client repo's hook files.

## Approving a Protected Commit

Approval is token-based, not environment-variable based.

Run the approval script only after staging the exact protected files you intend
to commit:

```powershell
git add <exact protected files>
& "C:\path\to\ai-control-plane\hooks\git\approve_governance_commit.ps1" -RepoRoot "."
git commit -m "..."
```

Important:

- The approval token is scoped to the staged protected-file set at approval time.
- If the staged set changes after approval, the token no longer matches.
- If the approval script prints `No staged files match a protected path`, inspect
  `git diff --cached --name-only` first. That is a staged-state mismatch, not
  proof that the hook is broken.

## Adding a New Client Repo

1. Create `.control-plane/adapter.json` pointing at this repo:
   ```json
   { "controlPlaneRepo": "C:/path/to/ai-control-plane" }
   ```
2. Create `.control-plane/protected-paths.json` with repo-specific paths (optional; defaults apply if absent).
3. Run `installers/install-claude-client.ps1`.
4. Verify with `git commit --dry-run` on a staged governance file — it should be blocked.
