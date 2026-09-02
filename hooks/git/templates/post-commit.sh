#!/bin/sh
# Post-commit: auto-capture git state + template sync check + governance notice.
# Installed by ai-control-plane/installers/install-claude-client.ps1
# {{CAPTURE_SESSION_STATE}} is replaced with the client-local capture script path at install time.
REPO_ROOT=$(git rev-parse --show-toplevel)

powershell.exe -NonInteractive -File "{{CAPTURE_SESSION_STATE}}" \
  -SessionId "post-commit-auto" \
  -Domain "unknown" \
  -ActiveNodeStatus "historical" \
  -TestsStatus "not_run" \
  -Summary "auto-captured by post-commit hook" 2>/dev/null || true

CHANGED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || true)
if echo "$CHANGED" | grep -qE "^(AGENTS\.md|AI_BOOTSTRAP\.md)$"; then
  if [ -d "new-project-template" ] && ! echo "$CHANGED" | grep -qE "^new-project-template/(AGENTS|AI_BOOTSTRAP)\.md$"; then
    echo "WARNING [post-commit]: AGENTS.md or AI_BOOTSTRAP.md changed but new-project-template/ not synced."
    echo "         Template sync rule requires syncing or explicit defer note in HANDOVER.md."
  fi
fi

if echo "$CHANGED" | grep -qE "^governance/"; then
  echo "NOTICE [post-commit]: governance/ file committed. Verify [governance-approved] token was in commit message."
fi
