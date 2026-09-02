# LEGACY COMPATIBILITY HELPER.
# Git executes .git/hooks/pre-commit (the .sh file), not this .ps1 file.
# Keep this only as an explicit manual forwarder for older local workflows.
# Installed by ai-control-plane/installers/install-claude-client.ps1
$repoRoot = (& git rev-parse --show-toplevel)
& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$repoRoot/.control-plane/hooks/git-pre-commit-protected-paths.ps1" -ProtectedPathsFile ".control-plane/protected-paths.json"
exit $LASTEXITCODE
