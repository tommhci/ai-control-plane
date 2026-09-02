param(
  [string]$RepoRoot = ".",
  [string]$Name,
  [string]$Branch = "",
  [string]$ParentDir = "",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Name)) {
  throw "Name is required"
}

$safeName = ($Name -replace '[^A-Za-z0-9._-]', '-').Trim("-")
if ([string]::IsNullOrWhiteSpace($safeName)) {
  throw "Name must contain at least one safe character"
}

$resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
if ([string]::IsNullOrWhiteSpace($Branch)) {
  $Branch = "codex/$safeName"
}
if ([string]::IsNullOrWhiteSpace($ParentDir)) {
  $ParentDir = Split-Path -Parent $resolvedRepoRoot
}

$repoName = Split-Path -Leaf $resolvedRepoRoot
$worktreePath = Join-Path $ParentDir "$repoName-wt-$safeName"

Push-Location $resolvedRepoRoot
try {
  $command = "git worktree add `"$worktreePath`" -b `"$Branch`""
  if ($DryRun) {
    Write-Output "DRY-RUN: $command"
  } else {
    & git worktree add $worktreePath -b $Branch
    if ($LASTEXITCODE -ne 0) {
      throw "git worktree add failed with exit $LASTEXITCODE"
    }
  }
} finally {
  Pop-Location
}

Write-Output "worktreePath=$worktreePath"
Write-Output "branch=$Branch"
