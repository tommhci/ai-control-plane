<#
.SYNOPSIS
  Memory-diff: find AI-tool memory lessons not yet harvested into the
  cross-tool lessons registry. Binary output per the 2026-08-29
  acceptance standard.

.DESCRIPTION
  Compares the lesson files in AI-tool memory stores
  (~/.claude/projects/*/memory/*.md by default) against the Sources
  registered in docs/cross-tool-lessons.md. Emits:
    - [UNHARVESTED] <file>  — memory lesson with no matching Source line
    - (summary) unharvested count
  Exit 0 always (report-only); pair with -FailOnGap for gating.

  This implements the monthly-patrol memory-diff item (2026-08-29):
  tool memory is the delivery layer, docs/cross-tool-lessons.md is the
  system of record - a lesson living only in memory evaporates on a tool
  switch.

.PARAMETER MemoryGlob
  Wildcard paths of memory files to check.

.PARAMETER Registry
  The canonical lessons registry.

.PARAMETER FailOnGap
  Exit 1 when any unharvested memory lesson is found.

.EXAMPLE
  pwsh -NoProfile -File scripts/memory-diff.ps1 -FailOnGap
#>
param(
    [string[]]$MemoryGlob = @("$env:USERPROFILE\.claude\projects\*\memory\*.md"),
    [string]$Registry = (Join-Path $PSScriptRoot "..\docs\cross-tool-lessons.md"),
    [switch]$FailOnGap
)

$ErrorActionPreference = "Stop"

$registryText = if (Test-Path -LiteralPath $Registry) {
    Get-Content -LiteralPath $Registry -Raw -Encoding UTF8
} else {
    Write-Output "[FAIL] registry not found: $Registry"
    exit 1
}

# A memory file counts as harvested when its stem name appears in the
# registry (Source line or promoted lesson body).
$unharvested = @()
$files = Get-ChildItem -Path $MemoryGlob -File -ErrorAction SilentlyContinue
foreach ($f in $files) {
    $stem = $f.BaseName -replace '^feedback[-_]', ''
    if ($registryText -match [regex]::Escape($stem)) { continue }
    if ($registryText -match [regex]::Escape($f.BaseName)) { continue }
    $unharvested += $f
    Write-Output "[UNHARVESTED] $($f.FullName)"
}

Write-Output ("memory files scanned: {0} | unharvested: {1}" -f $files.Count, $unharvested.Count)
if ($FailOnGap -and $unharvested.Count -gt 0) { exit 1 }
exit 0
