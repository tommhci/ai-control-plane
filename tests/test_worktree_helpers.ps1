param(
  [string]$ControlPlaneRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$RepoRoot = (Join-Path $env:TEMP ("ai-control-plane-worktree-test-" + [guid]::NewGuid().ToString("N")))
)

$ErrorActionPreference = "Continue"

$worktreePath = "$RepoRoot-wt-helper"

foreach ($path in @($worktreePath, $RepoRoot)) {
  if (Test-Path -LiteralPath $path) {
    Remove-Item -LiteralPath $path -Recurse -Force
  }
}

New-Item -ItemType Directory -Force -Path $RepoRoot | Out-Null
Push-Location $RepoRoot
try {
  & git init | Out-Null
  & git config user.email "worktree-test@example.local" | Out-Null
  & git config user.name "Worktree Test" | Out-Null
  "worktree test" | Set-Content -LiteralPath "README.md" -Encoding utf8
  & git add README.md | Out-Null
  & git commit -m "init worktree helper test" | Out-Null
} finally {
  Pop-Location
}

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "worktrees/new_task_worktree.ps1") -RepoRoot $RepoRoot -Name "helper" -Branch "codex/helper-test" | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "new_task_worktree failed"
}
if (-not (Test-Path -LiteralPath $worktreePath)) {
  throw "worktree path was not created: $worktreePath"
}

$list = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "worktrees/list_task_worktrees.ps1") -RepoRoot $RepoRoot
if ($LASTEXITCODE -ne 0) {
  throw "list_task_worktrees failed"
}
# Representation-independent assertion: match the unique leaf directory name
# (contains a guid) instead of a full path. Full-path matching broke on CI
# (verify run 33186816561) even after short/long resolution - path
# representation differs between hosts (8.3 names, slash direction, case).
# The leaf name survives every representation git or PowerShell prints.
$leafName = Split-Path -Leaf $worktreePath
$normalizedList = (@($list) -join "`n").Replace("\", "/")
if ($normalizedList -notmatch [regex]::Escape($leafName)) {
    throw "created worktree not listed (leaf=$leafName); list output was:`n$($normalizedList -join "`n")"
}

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "worktrees/remove_task_worktree.ps1") -RepoRoot $RepoRoot -WorktreePath $worktreePath -Prune | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "remove_task_worktree failed"
}
if (Test-Path -LiteralPath $worktreePath) {
  throw "worktree path still exists after remove"
}

Write-Output "worktree_helpers: PASS"
