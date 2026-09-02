<#
.SYNOPSIS
  Worktree + object-store integrity audit for multi-worktree repositories.

.DESCRIPTION
  Born 2026-08-29 from a real data-loss incident: a prototype worktree was
  deleted by a parallel session before its planned content review, and a
  shared object store turned out to hold a corrupted branch line (missing
  objects, untraversable history) that nobody had ever checked for.

  One command replays every manual check from that incident:
    1. Per-worktree: branch, dirty-file count, detached-HEAD flag.
    2. Per-branch: traversal health (rev-list succeeds / fails on missing
       objects) — corrupted lines are reported per branch, not hidden.
    3. Object-store integrity: git fsck --no-dangling broken-link scan.
  Report-only by default. -FailOnIntegrity exits 1 when fsck finds broken
  links or any branch fails traversal, so CI/patrol can gate on it.

.PARAMETER RepoPath
  Path to the repository (worktree or main checkout) to audit. Required.

.PARAMETER FailOnIntegrity
  Exit 1 on fsck broken links or branch traversal failure.

.EXAMPLE
  pwsh -NoProfile -File scripts/worktree-audit.ps1 -RepoPath C:\path\to\repo

.NOTES
  Encoding: UTF-8 with BOM (PS 5.1 host compatibility, see cross-repo
  findings finding 5). Report-only: never deletes, prunes, or repairs —
  the U4 pre-deletion gate (cross-repo-findings maintenance rules) applies
  to any destructive follow-up.
#>
param(
    [Parameter(Mandatory = $true)][string]$RepoPath,
    [switch]$FailOnIntegrity
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $RepoPath)) {
    throw "RepoPath does not exist: $RepoPath"
}

# Report-only audit: native-command stderr is data, not a terminating error.
# (PS 5.1 turns git stderr into NativeCommandError under EAP=Stop.)
$ErrorActionPreference = "Continue"

function Invoke-WorktreeAudit {
    param([string]$Repo)

    if (Test-Path -LiteralPath (Join-Path $Repo "ARCHIVED.md")) {
        Write-Host "=== worktree-audit: $Repo [ARCHIVED / EXEMPT] ==="
        Write-Host "  Repository contains ARCHIVED.md tombstone - skipping active worktree scan."
        Write-Host "=== result: ALL CLEAN (EXEMPT) ==="
        return 0
    }

    $g = @("-C", $Repo)
    $failures = 0

    Write-Host "=== worktree-audit: $Repo ==="

    # -- 1. worktree inventory ------------------------------------------------
    Write-Host "-- worktrees --"
    $entries = @(); $current = $null
    foreach ($line in (& git @g worktree list --porcelain 2>$null)) {
        if ($line -like "worktree *") {
            if ($current) { $entries += $current }
            $current = @{ path = $line.Substring(9); branch = "(detached)"; head = "" }
        }
        elseif ($line -like "HEAD *" -and $current) { $current.head = $line.Substring(5).Substring(0, 7) }
        elseif ($line -like "branch *" -and $current) { $current.branch = $line.Substring(7) -replace "refs/heads/", "" }
    }
    if ($current) { $entries += $current }

    foreach ($w in $entries) {
        $dirty = (& git @g -C $w.path status --porcelain 2>$null | Measure-Object).Count
        Write-Host ("  {0} | {1} | dirty={2}" -f $w.path, $w.branch, $dirty)
    }
    Write-Host ("  total worktrees: {0}" -f $entries.Count)

    # -- 2. branch traversal health -------------------------------------------
    Write-Host "-- branch traversal (corrupted lines fail here) --"
    foreach ($b in (& git @g for-each-ref --format="%(refname:short)" refs/heads/ 2>$null)) {
        $out = & git @g rev-list --count $b 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host ("  [FAIL] {0}: traversal error" -f $b)
            $failures++
        } else {
            Write-Host ("  [ok]   {0}: {1} commits" -f $b, ($out | Select-Object -First 1))
        }
    }

    # -- 3. object-store integrity --------------------------------------------
    Write-Host "-- fsck (broken links; dangling excluded) --"
    $broken = & git @g fsck --no-dangling 2>&1 | Where-Object { $_ -match "^(broken link|missing|error|fatal)" }
    if ($broken) {
        $broken | ForEach-Object { Write-Output ("  [BROKEN] {0}" -f $_) }
        $failures++
    } else {
        Write-Host "  [ok] no broken links"
    }

    Write-Host ("=== result: {0} ===" -f $(if ($failures -gt 0) { "$failures integrity failure(s)" } else { "ALL CLEAN" }))
    return $failures
}

$total = Invoke-WorktreeAudit -Repo $RepoPath
if ($FailOnIntegrity -and $total -gt 0) { exit 1 }
exit 0
