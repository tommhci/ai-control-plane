# Canary C2 (bypass ceiling): proves the DOCUMENTED ceiling, not a defect.
#
# `git commit --no-verify` skips the pre-commit hook entirely, succeeds, and
# git records nothing about the skip. This test asserts exactly that behavior
# so the ceiling in AGENTS.md "Enforcement ceiling" stays executable evidence:
# client-side enforcement is friction + audit trail; the only non-bypassable
# backstop is server-side CI + branch protection.
#
# Expected outcome: ALL assertions PASS = ceiling confirmed and documented.
param(
  [string]$ControlPlaneRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$canonicalHook = Join-Path $ControlPlaneRepo "hooks\git\pre_commit_protected_paths.ps1"
if (-not (Test-Path -LiteralPath $canonicalHook)) { throw "missing platform script: $canonicalHook" }

$script:passed = 0
$script:failed = 0
$script:fixtures = @()

function New-GovernedRepo {
  $root = Join-Path $env:TEMP ("canary-bypass-fixture-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $root | Out-Null
  Push-Location $root
  & git init | Out-Null
  & git config user.email "canary-bypass@example.local" | Out-Null
  & git config user.name "Canary Bypass" | Out-Null
  New-Item -ItemType Directory -Force -Path ".control-plane" | Out-Null
  Set-Content -LiteralPath (Join-Path $root "AGENTS.md") -Value "# Contract`n`nbaseline`n" -Encoding ascii
  Set-Content -LiteralPath (Join-Path $root ".control-plane/protected-paths.json") -Value "{ `"protectedPaths`": [`"AGENTS.md`"] }" -Encoding ascii
  & git add AGENTS.md .control-plane/protected-paths.json | Out-Null
  & git commit -m "seed" | Out-Null
  $hook = "#!/bin/sh`nREPO_ROOT=`$(git rev-parse --show-toplevel)`npowershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$canonicalHook`" -RepoRoot `"`$REPO_ROOT`" -ProtectedPathsFile `".control-plane/protected-paths.json`"`nexit `$?`n"
  [IO.File]::WriteAllText((Join-Path $root ".git/hooks/pre-commit"), $hook)
  Pop-Location
  $script:fixtures += $root
  return $root
}

try {
  $repo = New-GovernedRepo
  $before = (git -C $repo rev-parse HEAD)

  Set-Content -LiteralPath (Join-Path $repo "AGENTS.md") -Value "# Contract`n`nbypassed change`n" -Encoding ascii
  $null = git -C $repo add AGENTS.md
  Push-Location $repo
  $out = & git commit --no-verify -m "bypass: hook skipped" 2>&1
  $code = $LASTEXITCODE
  Pop-Location

  $after = (git -C $repo rev-parse HEAD)
  $auditPath = Join-Path $repo ".control-plane/.governance-audit.jsonl"

  $p1 = ($code -eq 0)
  $p2 = ($after -ne $before)
  $p3 = -not (Test-Path -LiteralPath $auditPath)

  if ($p1) { $script:passed++; Write-Output "PASS (ceiling confirmed): --no-verify commit succeeds" }
  else { $script:failed++; Write-Output "FAIL: --no-verify commit did not succeed (exit=$code)"; $out | ForEach-Object { Write-Output "  | $_" } }
  if ($p2) { $script:passed++; Write-Output "PASS (ceiling confirmed): protected change landed with no token" }
  else { $script:failed++; Write-Output "FAIL: HEAD did not move" }
  if ($p3) { $script:passed++; Write-Output "PASS (ceiling confirmed): no audit trail of the skip (git records nothing)" }
  else { $script:failed++; Write-Output "FAIL: unexpected audit trail exists" }

  Write-Output "Ceiling note: this is the documented behavior in AGENTS.md 'Enforcement ceiling'."
  Write-Output "Server-side CI (verify workflow) + branch protection are the non-bypassable backstop."
} finally {
  foreach ($f in $script:fixtures) {
    if (Test-Path -LiteralPath $f) { Remove-Item -LiteralPath $f -Recurse -Force -ErrorAction SilentlyContinue }
  }
}

Write-Output ("=" * 50)
Write-Output ("canary bypass ceiling: {0}/{1} passed" -f $script:passed, ($script:passed + $script:failed))
if ($script:failed -gt 0) { exit 1 }
exit 0
