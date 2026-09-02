# Canary C2 (L1): full governance-commit sequence on a disposable repo,
# with the platform's canonical hook + approve scripts wired in.
#
# Regression coverage bundled here (all landed 2026-08-29):
#   - pre-commit blocks protected paths without a token
#   - approve_governance_commit.ps1 creates .control-plane/ on demand
#   - a valid token lets the commit through and is consumed (burned)
#   - the approval_consumed audit line carries stagedBlobHashes (W1a)
#   - an expired token is rejected and recorded (disposition record)
#   - post-approval content drift is rejected as blob_mismatch (W1a)
#   - routine (non-protected) files pass the hook untouched
param(
  [string]$ControlPlaneRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$approveScript = Join-Path $ControlPlaneRepo "hooks\git\approve_governance_commit.ps1"
$canonicalHook = Join-Path $ControlPlaneRepo "hooks\git\pre_commit_protected_paths.ps1"
foreach ($f in @($approveScript, $canonicalHook)) {
  if (-not (Test-Path -LiteralPath $f)) { throw "missing platform script: $f" }
}

$script:passed = 0
$script:failed = 0
$script:fixtures = @()

function New-GovernedRepo {
  $root = Join-Path $env:TEMP ("canary-l1-fixture-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  Push-Location $root
  & git init | Out-Null
  & git config user.email "canary-l1@example.local" | Out-Null
  & git config user.name "Canary L1" | Out-Null
  New-Item -ItemType Directory -Force -Path ".control-plane" | Out-Null
  Set-Content -LiteralPath (Join-Path $root "AGENTS.md") -Value "# Contract`n`nbaseline`n" -Encoding ascii
  Set-Content -LiteralPath (Join-Path $root "README.md") -Value "# Routine`n" -Encoding ascii
  Set-Content -LiteralPath (Join-Path $root ".control-plane/protected-paths.json") -Value "{ `"protectedPaths`": [`"AGENTS.md`"] }" -Encoding ascii
  & git add AGENTS.md README.md .control-plane/protected-paths.json | Out-Null
  & git commit -m "seed" | Out-Null

  # Install the pre-commit hook pointing at the canonical script.
  $hook = "#!/bin/sh`nREPO_ROOT=`$(git rev-parse --show-toplevel)`npowershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$canonicalHook`" -RepoRoot `"`$REPO_ROOT`" -ProtectedPathsFile `".control-plane/protected-paths.json`"`nexit `$?`n"
  [IO.File]::WriteAllText((Join-Path $root ".git/hooks/pre-commit"), $hook)
  Pop-Location
  $script:fixtures += $root
  return $root
}

function Invoke-Git {
  # PS 5.1 turns native stderr (benign LF/CRLF warnings) into a
  # NativeCommandError under 2>&1 + Stop preference — the exact L3 lesson.
  # Wrap with EAP=Continue, mirroring tests/test_git_protected_paths.ps1.
  param([string]$Repo, [string[]]$GitArgs)
  $oldEap = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    Push-Location $Repo
    $out = & git @GitArgs 2>&1
    $code = $LASTEXITCODE
    Pop-Location
  } finally {
    $ErrorActionPreference = $oldEap
  }
  return [pscustomobject]@{ ExitCode = $code; Output = @($out) }
}

function Invoke-Approve {
  param([string]$Repo, [int]$TtlMinutes = 10)
  $exe = "powershell"
  $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
  if ($null -ne $pwshCmd) { $exe = $pwshCmd.Source }
  $out = & $exe -NoProfile -ExecutionPolicy Bypass -File $approveScript -RepoRoot $Repo -TtlMinutes $TtlMinutes 2>&1
  return [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = @($out) }
}

function Get-AuditLines {
  param([string]$Repo)
  $p = Join-Path $Repo ".control-plane/.governance-audit.jsonl"
  if (-not (Test-Path -LiteralPath $p)) { return @() }
  return @(Get-Content -LiteralPath $p | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    ForEach-Object { $_ | ConvertFrom-Json })
}

function Assert-True {
  param([string]$Name, [bool]$Condition, [string]$Detail)
  if ($Condition) { $script:passed++; Write-Output "PASS: $Name" }
  else { $script:failed++; Write-Output "FAIL: $Name $(if ($Detail) { "- $Detail" })" }
}

try {
  # --- Scenario 1: protected path without token is BLOCKED ---
  $repo = New-GovernedRepo
  Set-Content -LiteralPath (Join-Path $repo "AGENTS.md") -Value "# Contract`n`nchange 1`n" -Encoding ascii
  $null = Invoke-Git -Repo $repo -GitArgs @("add", "AGENTS.md")
  $c = Invoke-Git -Repo $repo -GitArgs @("commit", "-m", "should be blocked")
  $blocked = ($c.ExitCode -ne 0) -and ((($c.Output -join "`n")).IndexOf("BLOCKED") -ge 0)
  Assert-True -Name "commit without token is BLOCKED" -Condition $blocked -Detail (($c.Output -join " ") -replace '\s+', ' ')
  $head1 = (Invoke-Git -Repo $repo -GitArgs @("log", "--oneline", "-1")).Output[0]
  Assert-True -Name "blocked commit did not land" -Condition ($head1 -match "seed")

  # --- Scenario 2: approve -> commit passes; token burned; W1a audit ---
  $a = Invoke-Approve -Repo $repo
  Assert-True -Name "approve succeeds and creates .control-plane on demand" `
    -Condition (($a.ExitCode -eq 0) -and (Test-Path (Join-Path $repo ".control-plane/.governance-approval.json"))) `
    -Detail (($a.Output -join " ") -replace '\s+', ' ')
  $c = Invoke-Git -Repo $repo -GitArgs @("commit", "-m", "approved change")
  Assert-True -Name "commit with valid token passes" -Condition ($c.ExitCode -eq 0) -Detail (($c.Output -join " ") -replace '\s+', ' ')
  Assert-True -Name "token file consumed (burned)" -Condition (-not (Test-Path (Join-Path $repo ".control-plane/.governance-approval.json")))
  $audit = Get-AuditLines -Repo $repo
  $granted = @($audit | Where-Object { $_.event -eq "approval_granted" })
  $consumed = @($audit | Where-Object { $_.event -eq "approval_consumed" })
  Assert-True -Name "audit has granted + consumed lines" -Condition (($granted.Count -ge 1) -and ($consumed.Count -ge 1))
  $consumedLine = if ($consumed.Count -ge 1) { $consumed[$consumed.Count - 1] } else { $null }
  $consumedJson = if ($consumedLine) { $consumedLine | ConvertTo-Json -Compress -Depth 6 } else { "" }
  # Text-level assertion: immune to PS-version differences in how the
  # structured stagedBlobHashes object round-trips through JSON (CI PS 7.6
  # turned an empty ordered table into a missing property, 2026-08-29).
  $hashOk = $consumedJson -match 'stagedBlobHashesText' -and $consumedJson -match 'AGENTS\.md=[0-9a-f]{40}'
  Assert-True -Name "consumed line carries staged blob hashes (W1a)" `
    -Condition ([bool]($hashOk -and $consumedLine -and $consumedLine.result -eq "consumed")) `
    -Detail "consumed-line: $(if ($consumedJson) { $consumedJson } else { '<none>' })"

  # --- Scenario 3: expired token is rejected and recorded ---
  Set-Content -LiteralPath (Join-Path $repo "AGENTS.md") -Value "# Contract`n`nchange 2`n" -Encoding ascii
  $null = Invoke-Git -Repo $repo -GitArgs @("add", "AGENTS.md")
  $a = Invoke-Approve -Repo $repo -TtlMinutes 0
  Assert-True -Name "approve with TTL 0 succeeds" -Condition ($a.ExitCode -eq 0)
  $c = Invoke-Git -Repo $repo -GitArgs @("commit", "-m", "expired token attempt")
  $rejected = ($c.ExitCode -ne 0)
  $audit = Get-AuditLines -Repo $repo
  $expired = @($audit | Where-Object { $_.event -eq "approval_consumed" -and $_.result -eq "rejected_expired_or_mismatch" })
  Assert-True -Name "expired token rejected with disposition record" -Condition ($rejected -and $expired.Count -ge 1)

  # --- Scenario 4: content drift after approval -> blob_mismatch ---
  $a = Invoke-Approve -Repo $repo
  Assert-True -Name "re-approve for drift scenario" -Condition ($a.ExitCode -eq 0)
  Set-Content -LiteralPath (Join-Path $repo "AGENTS.md") -Value "# Contract`n`nchange 2 DRIFTED`n" -Encoding ascii
  $null = Invoke-Git -Repo $repo -GitArgs @("add", "AGENTS.md")
  $c = Invoke-Git -Repo $repo -GitArgs @("commit", "-m", "drifted content")
  $audit = Get-AuditLines -Repo $repo
  $mismatch = @($audit | Where-Object { $_.event -eq "approval_consumed" -and $_.result -eq "rejected_blob_mismatch" })
  $lastConsumed2 = @($audit | Where-Object { $_.event -eq "approval_consumed" })
  Assert-True -Name "post-approval drift rejected as blob_mismatch" -Condition ([bool](($c.ExitCode -ne 0) -and $mismatch.Count -ge 1)) `
    -Detail "commit-exit=$($c.ExitCode); last-consumed: $(if ($lastConsumed2.Count -ge 1) { $lastConsumed2[$lastConsumed2.Count - 1] | ConvertTo-Json -Compress -Depth 6 } else { '<none>' })"

  # --- Scenario 5: routine files pass untouched ---
  # Discard the drifted AGENTS.md left in the index by scenario 4 (deliberate
  # test fixture content, no value to preserve), so this commit is purely
  # routine and the hook's protected-path set is empty.
  $null = Invoke-Git -Repo $repo -GitArgs @("checkout", "HEAD", "--", "AGENTS.md")
  Set-Content -LiteralPath (Join-Path $repo "README.md") -Value "# Routine v2`n" -Encoding ascii
  $null = Invoke-Git -Repo $repo -GitArgs @("add", "README.md")
  $c = Invoke-Git -Repo $repo -GitArgs @("commit", "-m", "routine change passes")
  Assert-True -Name "routine (non-protected) commit passes hook" -Condition ($c.ExitCode -eq 0)
} finally {
  foreach ($f in $script:fixtures) {
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue }
  }
}

Write-Output ("=" * 50)
Write-Output ("canary L1 sequence: {0}/{1} passed" -f $script:passed, ($script:passed + $script:failed))
if ($script:failed -gt 0) { exit 1 }
exit 0
