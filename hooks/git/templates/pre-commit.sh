#!/bin/sh
# Pre-commit: block unauthorized commits containing protected governance paths.
# Installed by ai-control-plane/installers/install-claude-client.ps1
REPO_ROOT=$(git rev-parse --show-toplevel)

powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$REPO_ROOT/.control-plane/hooks/git-pre-commit-protected-paths.ps1" \
  -ProtectedPathsFile ".control-plane/protected-paths.json"
exit $?
