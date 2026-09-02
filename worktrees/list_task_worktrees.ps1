param(
  [string]$RepoRoot = "."
)

$ErrorActionPreference = "Stop"

$resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Push-Location $resolvedRepoRoot
try {
  & git worktree list
  if ($LASTEXITCODE -ne 0) {
    throw "git worktree list failed with exit $LASTEXITCODE"
  }
} finally {
  Pop-Location
}
