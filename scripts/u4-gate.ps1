# CANONICAL SOURCE — ai-control-plane/scripts/u4-gate.ps1
#
# U4 pre-deletion gate (lessons registry U4: metadata != content).
# Run BEFORE any deletion-class operation on a path (file, directory,
# worktree, branch cleanup). Read-only: never deletes, never modifies the
# target or the git index.
#
# Binary verdict (exit 0 = PASS, exit 1 = FAIL):
#   PASS - every file under -Path is git-tracked AND the tree is clean there
#          (a recoverable snapshot exists in the object store), or the path
#          does not exist (nothing to lose).
#   FAIL - the target carries untracked or uncommitted content that a
#          deletion would destroy permanently. Commit or back it up first,
#          then re-run. Deleted-but-never-committed content has no recovery
#          path; this is exactly the prototype-worktree loss class.
#
# Evidence: every invocation appends a line to
# .control-plane/u4-audit.jsonl (untracked LOCAL state, like the governance
# audit log; the monthly patrol commits a de-identified summary). The log is
# the disposal record the acceptance criteria ("content-loss incidents must
# have a disposition record") require.
#
# Usage:
#   pwsh -File scripts/u4-gate.ps1 -Path <target> [-RepoRoot <repo>] [-Purpose "<why>"]

param(
  [Parameter(Mandatory = $true)][string]$Path,
  [string]$RepoRoot = ".",
  [string]$Purpose = ""
)

$ErrorActionPreference = "Stop"

$resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$auditDir = Join-Path $resolvedRepoRoot ".control-plane"
$auditPath = Join-Path $auditDir "u4-audit.jsonl"

if (-not (Test-Path -LiteralPath $auditDir)) {
  New-Item -ItemType Directory -Path $auditDir -Force | Out-Null
}

$targetPath = if ([System.IO.Path]::IsPathRooted($Path)) {
  $Path
} else {
  Join-Path $resolvedRepoRoot $Path
}

Push-Location $resolvedRepoRoot
try {
  $now = (Get-Date).ToString("o")
  $verdict = "PASS"
  $reason = ""
  $totalFiles = 0
  $trackedFiles = 0
  $untrackedFiles = 0
  $modifiedFiles = 0
  $dirtyHashes = [ordered]@{}

  if (-not (Test-Path -LiteralPath $targetPath)) {
    $reason = "target does not exist - nothing to lose"
  } else {
    $items = @(Get-ChildItem -LiteralPath $targetPath -Recurse -File -Force |
      Where-Object { $_.FullName -notmatch '[\\/]\.git([\\/]|$)' })
    $totalFiles = $items.Count

    # Tracked files under the target (read-only index query). Pass the
    # user-supplied path TEXT to git, never a recomputed absolute form: hosts
    # with 8.3 short-name resolution (CI runners) make Resolve-Path disagree
    # with enumerated FullName prefixes, and recomputed paths silently match
    # nothing (CI failure class, 2026-08-29). Git resolves the relative text
    # against CWD, which is $resolvedRepoRoot here.
    $gitPath = if ([string]::IsNullOrWhiteSpace($Path)) { "." } else { $Path }
    $tracked = @(& git ls-files -- $gitPath)
    $trackedFiles = $tracked.Count

    # Dirty state under the target (read-only). -uall lists untracked files
    # individually (not as a bare directory entry) and git's output is the
    # single authority for which paths are dirty: hash those paths directly -
    # short-name or long-name forms are both valid aliases for reading, so no
    # path coordinate conversion is ever needed.
    $statusLines = @(& git status --porcelain -uall -- $gitPath)
    foreach ($line in $statusLines) {
      if ([string]::IsNullOrWhiteSpace($line)) { continue }
      $xy = $line.Substring(0, 2)
      if ($xy -eq '!!') { continue }
      $p = $line.Substring(3).Trim('"').Replace('/', '\')
      if ($xy -eq '??') { $untrackedFiles++ } else { $modifiedFiles++ }
      $fullSp = Join-Path $resolvedRepoRoot $p
      if (Test-Path -LiteralPath $fullSp -PathType Leaf) {
        $h = Get-FileHash -LiteralPath $fullSp -Algorithm SHA256
        $dirtyHashes[$p.Replace('\', '/')] = $h.Hash.Substring(0, 16)
      }
    }

    if ($untrackedFiles -gt 0 -or $modifiedFiles -gt 0) {
      $verdict = "FAIL"
      $reason = ("uncommitted or untracked content would be permanently lost: {0} untracked, {1} modified/uncommitted file(s)" -f $untrackedFiles, $modifiedFiles)

      # Content fingerprint of what would be lost: already collected above
      # from git's own dirty listing.
    } elseif ($trackedFiles -eq 0) {
      # No dirty lines but nothing tracked either (e.g. an empty dir, or an
      # ignored-only tree). Ignored content is disposable by definition.
      $reason = "no tracked files and no dirty state under target (empty or ignored-only)"
    } else {
      $reason = ("clean, fully tracked tree ({0} file(s)) - recoverable from the object store" -f $trackedFiles)
    }
  }

  $auditLine = [ordered]@{
    event          = "u4_gate_check"
    timestamp      = $now
    target         = $targetPath
    purpose        = $Purpose
    verdict        = $verdict
    reason         = $reason
    totalFiles     = $totalFiles
    trackedFiles   = $trackedFiles
    untrackedFiles = $untrackedFiles
    modifiedFiles  = $modifiedFiles
    lostContentSha = $dirtyHashes
  } | ConvertTo-Json -Compress -Depth 6
  Add-Content -LiteralPath $auditPath -Value $auditLine -Encoding utf8

  Write-Output ("U4 gate [{0}]: {1} - {2}" -f $verdict, $targetPath, $reason)
  if ($verdict -eq "FAIL") {
    Write-Output "Commit or back up the content above first, then re-run this gate."
    foreach ($k in $dirtyHashes.Keys) { Write-Output ("  would-lose: {0} (sha256:{1}...)" -f $k, $dirtyHashes[$k]) }
    exit 1
  }
  Write-Output "Audit: $auditPath"
  exit 0
} finally {
  Pop-Location
}
