# Canary C2 (U4): exercises scripts/u4-gate.ps1 against a disposable repo.
# Scenarios: clean tracked tree -> PASS; untracked content -> FAIL with
# evidence; modified tracked content -> FAIL; missing path -> PASS; audit
# log accumulates a verdict line per invocation.
param(
  [string]$U4GateScript = (Join-Path $PSScriptRoot "..\scripts\u4-gate.ps1")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $U4GateScript)) { throw "u4-gate.ps1 not found at $U4GateScript" }

$script:passed = 0
$script:failed = 0
$script:fixtures = @()

function New-Repo {
  $root = Join-Path $env:TEMP ("u4-gate-fixture-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  Push-Location $root
  & git init | Out-Null
  & git config user.email "u4-fixture@example.local" | Out-Null
  & git config user.name "U4 Fixture" | Out-Null
  Set-Content -LiteralPath (Join-Path $root "clean.txt") -Value "committed content`n" -Encoding ascii
  & git add clean.txt | Out-Null
  & git commit -m "seed" | Out-Null
  Pop-Location
  $script:fixtures += $root
  return $root
}

function Invoke-Gate {
  param([string]$Repo, [string]$Target, [string]$Purpose)
  $exe = "powershell"
  $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($null -ne $pwshCmd) { $exe = $pwshCmd.Source }
  $out = & $exe -NoProfile -ExecutionPolicy Bypass -File $U4GateScript -Path $Target -RepoRoot $Repo -Purpose $Purpose 2>&1
  return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($out) }
}

function Assert-Gate {
  param([string]$Name, [object]$Result, [int]$ExpectedExit, [string]$OutputContains)
  $ok = ($Result.ExitCode -eq $ExpectedExit)
  if ($ok -and -not [string]::IsNullOrEmpty($OutputContains)) {
    $joined = ($Result.Output -join "`n")
    $ok = $joined.IndexOf($OutputContains, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
  }
  if ($ok) { $script:passed++; Write-Output "PASS: $Name" }
  else {
    $script:failed++
    Write-Output "FAIL: $Name (exit=$($Result.ExitCode), expected=$ExpectedExit)"
    foreach ($line in $Result.Output) { Write-Output "  | $line" }
  }
}

try {
  # 1. Fully tracked, clean tree -> PASS
  $repo = New-Repo
  $r = Invoke-Gate -Repo $repo -Target "clean.txt" -Purpose "scenario 1"
  Assert-Gate -Name "clean tracked file passes" -Result $r -ExpectedExit 0 -OutputContains "U4 gate [PASS]"

  # 2. Untracked file appears -> FAIL, with would-lose evidence
  Set-Content -LiteralPath (Join-Path $repo "untracked.txt") -Value "never committed`n" -Encoding ascii
  $r = Invoke-Gate -Repo $repo -Target "." -Purpose "scenario 2"
  Assert-Gate -Name "untracked content fails with evidence" -Result $r -ExpectedExit 1 -OutputContains "would-lose"

  # 3. Modified tracked file -> FAIL
  $repo2 = New-Repo
  Set-Content -LiteralPath (Join-Path $repo2 "clean.txt") -Value "dirty working copy`n" -Encoding ascii
  $r = Invoke-Gate -Repo $repo2 -Target "." -Purpose "scenario 3"
  Assert-Gate -Name "modified tracked content fails" -Result $r -ExpectedExit 1 -OutputContains "U4 gate [FAIL]"

  # 4. Missing path -> PASS (nothing to lose)
  $r = Invoke-Gate -Repo $repo2 -Target "does-not-exist" -Purpose "scenario 4"
  Assert-Gate -Name "missing path passes" -Result $r -ExpectedExit 0

  # 5. Audit log: one verdict line per invocation
  $auditPath = Join-Path $repo2 ".control-plane/u4-audit.jsonl"
  $ok = (Test-Path -LiteralPath $auditPath)
  if ($ok) {
    $lines = @(Get-Content -LiteralPath $auditPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $ok = ($lines.Count -ge 2)
    if ($ok) {
      $last = $lines[$lines.Count - 1] | ConvertFrom-Json
      $ok = ($last.event -eq "u4_gate_check") -and ($last.verdict -eq "PASS") -and ($last.purpose -eq "scenario 4")
    }
  }
  if ($ok) { $script:passed++; Write-Output "PASS: audit log records verdict lines" }
  else { $script:failed++; Write-Output "FAIL: audit log records verdict lines" }
} finally {
  foreach ($f in $script:fixtures) {
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue }
  }
}

Write-Output ("=" * 50)
Write-Output ("u4-gate canary: {0}/{1} passed" -f $script:passed, ($script:passed + $script:failed))
if ($script:failed -gt 0) { exit 1 }
exit 0
