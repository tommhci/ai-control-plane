# Tests for scripts/boundary-lint.ps1 — disposable repo-shaped fixtures,
# asserts binary behavior: PASS/FAIL exit codes, machine-path tier,
# identifier exemptions (adapter islands, R-layer files, docs/audits/),
# and the boundary-lint:allow escape hatch.
#
# Fixture data below deliberately contains client identifiers and fake
# machine paths; those lines carry boundary-lint:allow markers so the lint
# scanning this very file (tests/ is in scope) does not self-trip.

param(
  [string]$BoundaryLintScript = (Join-Path $PSScriptRoot "..\scripts\boundary-lint.ps1")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $BoundaryLintScript)) {
  throw "boundary-lint.ps1 not found at $BoundaryLintScript"
}

$script:passed = 0
$script:failed = 0
$script:fixtures = @()

function New-Fixture {
  param([hashtable]$Files)
  $root = Join-Path $env:TEMP ("boundary-lint-fixture-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  foreach ($rel in $Files.Keys) {
    $abs = Join-Path $root ($rel.Replace('/', '\'))
    $dir = Split-Path -Parent $abs
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Set-Content -LiteralPath $abs -Value ([string]$Files[$rel]) -Encoding utf8
  }
  $script:fixtures += $root
  return $root
}

function Invoke-Lint {
  param([string]$Root)
  # Child-process call: the lint script uses `exit`, which would terminate
  # this test process if invoked in-process. Prefer pwsh; fall back to
  # Windows PowerShell so the test itself runs under either host.
  $exe = "powershell"
  $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($null -ne $pwshCmd) { $exe = $pwshCmd.Source }
  $out = & $exe -NoProfile -ExecutionPolicy Bypass -File $BoundaryLintScript -RepoRoot $Root 2>&1
  return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($out) }
}

function Assert-Lint {
  param([string]$Name, [object]$Result, [int]$ExpectedExit, [string]$OutputContains)
  $ok = ($Result.ExitCode -eq $ExpectedExit)
  if ($ok -and -not [string]::IsNullOrEmpty($OutputContains)) {
    $joined = ($Result.Output -join "`n")
    $ok = $joined.IndexOf($OutputContains, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
  }
  if ($ok) {
    $script:passed++
    Write-Output "PASS: $Name"
  } else {
    $script:failed++
    Write-Output "FAIL: $Name (exit=$($Result.ExitCode), expected=$ExpectedExit)"
    foreach ($line in $Result.Output) { Write-Output "  | $line" }
  }
}

try {
  # 1. Clean repo -> PASS (exit 0)
  $r = Invoke-Lint -Root (New-Fixture -Files @{
    "AGENTS.md" = "# Contract`n`nGeneric rules only, no tenant details."
  })
  Assert-Lint -Name "clean repo passes" -Result $r -ExpectedExit 0 -OutputContains "boundary-lint: PASS"

  # 2. Client identifier in canon -> FAIL (exit 1)
  $r = Invoke-Lint -Root (New-Fixture -Files @{
    "AGENTS.md" = "Client repos (e.g., tom-os-vnext) install from here. # boundary-lint:allow fixture data"
  })
  Assert-Lint -Name "clean fixture with marker passes" -Result $r -ExpectedExit 0

  $r = Invoke-Lint -Root (New-Fixture -Files @{
    "AGENTS.md" = "Client repos (e.g., tom-os-vnext) install from here." # boundary-lint:allow (fixture data)
  })
  Assert-Lint -Name "client identifier in canon fails" -Result $r -ExpectedExit 1 -OutputContains "client identifier"

  # 3. Machine-absolute path in canon -> FAIL (exit 1)
  $r = Invoke-Lint -Root (New-Fixture -Files @{
    "AGENTS.md" = "Archive lives at C:\Users\dev\session-archive - read first." # boundary-lint:allow (fixture data)
  })
  Assert-Lint -Name "machine-absolute path fails" -Result $r -ExpectedExit 1 -OutputContains "machine-absolute path"

  # 4. Allow marker escapes an otherwise failing line
  $r = Invoke-Lint -Root (New-Fixture -Files @{
    "AGENTS.md" = "Legacy name check: tom-os-local-backup # boundary-lint:allow detector signature"
  })
  Assert-Lint -Name "allow marker escapes line" -Result $r -ExpectedExit 0

  # 5. Identifier-exempt adapter island: identifier OK
  $r = Invoke-Lint -Root (New-Fixture -Files @{
    "adapters/tom-os/README.md" = "# Example adapter`nClient-local adapter contract for this project island." # boundary-lint:allow (fixture data)
  })
  Assert-Lint -Name "identifier exempt in adapter island" -Result $r -ExpectedExit 0

  # 6. ...but machine paths still FAIL inside the exempt island
  $r = Invoke-Lint -Root (New-Fixture -Files @{
    "adapters/tom-os/adapter.json" = "{ `"controlPlaneRepo`": `"C:/Users/dev/ai-control-plane`" }" # boundary-lint:allow (fixture data)
  })
  Assert-Lint -Name "machine path fails inside exempt island" -Result $r -ExpectedExit 1 -OutputContains "machine-absolute path"

  # 7. R-layer file may name clients
  $r = Invoke-Lint -Root (New-Fixture -Files @{
    "PROJECT_STATUS.md" = "Witness decided: the standalone line is canonical; tom-os line dormant." # boundary-lint:allow (fixture data)
  })
  Assert-Lint -Name "R-layer file may name clients" -Result $r -ExpectedExit 0

  # 8. ...but R-layer machine paths still FAIL
  $r = Invoke-Lint -Root (New-Fixture -Files @{
    "PROJECT_STATUS.md" = "Session archive: C:\Users\dev\zcode-run-2026-08-29" # boundary-lint:allow (fixture data)
  })
  Assert-Lint -Name "R-layer machine path fails" -Result $r -ExpectedExit 1 -OutputContains "machine-absolute path"

  # 9. docs/audits/ is an R-layer record dir: identifiers OK
  $r = Invoke-Lint -Root (New-Fixture -Files @{
    "docs/audits/cross-repo-findings.md" = "Finding 6/7 origin: multi-agent race on the client line."
  })
  Assert-Lint -Name "docs/audits identifiers allowed" -Result $r -ExpectedExit 0
} finally {
  foreach ($f in $script:fixtures) {
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue }
  }
}

Write-Output ("=" * 50)
Write-Output ("boundary-lint self-test: {0}/{1} passed" -f $script:passed, ($script:passed + $script:failed))
if ($script:failed -gt 0) { exit 1 }
exit 0
