# Worktree-First Policy

Status: active policy with helper scripts and conflict remedy.

## Core Rule

Use a separate git worktree before running more than one write-capable AI agent
against the same repository. `ACTIVE_EDIT_OWNERSHIP.md` remains a visibility
layer, not the primary isolation boundary.

If a second writer hits an ownership conflict in the main checkout, the control
plane should route them to `worktrees/new_task_worktree.ps1` instead of asking
them to keep competing in the same worktree.

## When To Use A Worktree

- Any parallel implementation or repair work.
- Any audit that may become write-capable after findings.
- Any risky governance, hook, adapter, or installer change while another session
  is active.
- Any experiment whose revert path is unclear.

Stay in the main worktree only when there is exactly one write-capable agent and
the task has a narrow file set.

## Branch And Path Convention

- Branch prefix: `codex/`.
- Branch shape: `codex/<phase>-<short-topic>`.
- Sibling path shape: `../<repo-name>-wt-<short-topic>`.

Example:

```powershell
git worktree add ../<your-repo>-wt-hooks -b codex/p1-hooks
```

## Merge Gate

Before merging or copying work back:

- Run the target repo smoke test or equivalent verification.
- Confirm `git status --short` is clean except documented local-only files.
- Confirm no protected-path edit bypassed the client hook.
- Re-run shared-skill hash parity if skills changed.
- Have one conductor perform the merge/copy; do not let agents merge each other.

## Cleanup

After merge or explicit abandonment:

```powershell
git worktree remove ../<your-repo>-wt-hooks
git worktree prune
```

Do not remove a worktree with uncommitted changes unless the human explicitly
confirms the changes are disposable.
