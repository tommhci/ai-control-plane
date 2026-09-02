param(
  [string]$RepoRoot = ".",
  [string]$WorktreePath,
  [switch]$Prune,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($WorktreePath)) {
  throw "WorktreePath is required"
}

$resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$resolvedWorktreePath = if (Test-Path -LiteralPath $WorktreePath) {
  (Resolve-Path -LiteralPath $WorktreePath).Path
} else {
  [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $WorktreePath))
}

$leaf = Split-Path -Leaf $resolvedWorktreePath
if ($leaf -notmatch "-wt-") {
  throw "Refusing to remove worktree path without '-wt-' marker: $resolvedWorktreePath"
}

Push-Location $resolvedRepoRoot
try {
  $command = "git worktree remove `"$resolvedWorktreePath`""
  if ($DryRun) {
    Write-Output "DRY-RUN: $command"
  } else {
    & git worktree remove $resolvedWorktreePath
    if ($LASTEXITCODE -ne 0) {
      throw "git worktree remove failed with exit $LASTEXITCODE"
    }
  }

  if ($Prune) {
    if ($DryRun) {
      Write-Output "DRY-RUN: git worktree prune"
    } else {
      & git worktree prune
      if ($LASTEXITCODE -ne 0) {
        throw "git worktree prune failed with exit $LASTEXITCODE"
      }
    }
  }
} finally {
  Pop-Location
}

Write-Output "removed=$resolvedWorktreePath"
