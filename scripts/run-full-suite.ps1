<#
.SYNOPSIS
  Full-suite test runner across BOTH PowerShell hosts (pwsh7 + Windows
  PowerShell 5.1). Added 2026-08-23 after three occurrences of the
  host-difference failure family (CRLF stderr -> health-check stdin consume
  -> quote/BOM escaping): the suite only catches host quirks when each test
  runs under both hosts. This script makes the dual-host matrix a single
  command instead of a manual hunt.

.DESCRIPTION
  Runs every tests/test_*.ps1 (except test_state_store_migration.ps1, which
  requires -InputPath external input) under BOTH pwsh and powershell (5.1),
  prints a host x test matrix, and exits 1 if ANY test fails under EITHER
  host. Known noise: some tests print a harmless "InvalidOperation: You
  cannot call a method on a null-valued expression." line during batch runs
  while still exiting 0 (see tests/test_sqlite_mirror.ps1 comment); exit
  codes are the verdict, stderr lines are not.

.EXAMPLE
  pwsh -NoProfile -File scripts/run-full-suite.ps1

.OUTPUTS
  Matrix lines: [PASS/FAIL] <host> <test> (exit=<code>)
  Exit 0 = all green on both hosts; 1 = any failure.
#>
param()

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$tests = Get-ChildItem (Join-Path $repoRoot "tests") -Filter "test_*.ps1" |
  Where-Object { $_.Name -ne "test_state_store_migration.ps1" } |
  Sort-Object Name

$hosts = @(
  @{ Label = "pwsh7"; Exe = "pwsh" },
  @{ Label = "ps5.1"; Exe = "powershell" }
)

$failures = @()
$total = 0

Write-Host ""
Write-Host "=== Dual-host full-suite matrix (pwsh7 + PS5.1) ==="
Write-Host ("Tests: {0}  Hosts: {1}" -f $tests.Count, $hosts.Count)
Write-Host ""

foreach ($h in $hosts) {
  foreach ($t in $tests) {
    $total++
    $out = & $h.Exe -NoProfile -ExecutionPolicy Bypass -File $t.FullName 2>&1
    $code = $LASTEXITCODE
    $verdict = if ($code -eq 0) { "PASS" } else { "FAIL" }
    if ($code -ne 0) {
      $failures += "$($h.Label) $($t.BaseName) exit=$code"
    }
    # keep the last status line for context without flooding
    $statusLine = ($out | Select-String -Pattern "PASS$|ALL PASS|: PASS|FAIL" | Select-Object -Last 1).Line
    Write-Host ("[{0}] {1,-8} {2,-38} exit={3}  {4}" -f $verdict, $h.Label, $t.BaseName, $code, ($statusLine -replace '\s+', ' ').Trim())
    if ($code -ne 0) {
      # A red line with no reason is not a usable gate signal: emit the tail
      # of the captured output so CI (and any host) shows WHY the test died.
      Write-Host ("--- {0} {1} output tail ---" -f $h.Label, $t.BaseName)
      @($out) | Select-Object -Last 15 | ForEach-Object { Write-Host "  $_" }
    }
  }
}

Write-Host ""
if ($failures.Count -eq 0) {
  Write-Host "DUAL-HOST SUITE: ALL PASS ($total runs, 2 hosts)"
  exit 0
} else {
  Write-Host "DUAL-HOST SUITE: $($failures.Count) FAILURE(S):"
  $failures | ForEach-Object { Write-Host "  - $_" }
  exit 1
}