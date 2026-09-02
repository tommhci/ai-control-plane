param()

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$claimScript = Join-Path $scriptDir "claim_ownership.ps1"
$repoRoot = (Resolve-Path (Join-Path $scriptDir "..")).Path
$tempFile = Join-Path $env:TEMP "claim-ownership-smoke-$([guid]::NewGuid().ToString('N')).md"

function Invoke-Claim {
  param(
    [string[]]$ArgumentList
  )

  $oldPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File $claimScript @ArgumentList 2>&1
    return [pscustomobject]@{
      ExitCode = $LASTEXITCODE
      Output = @($output)
    }
  } finally {
    $ErrorActionPreference = $oldPreference
  }
}

@"
# Active Edit Ownership

## Current Ownership
None.
## Entry Format

placeholder

## History

[2026-01-01 active] owner=Historical/owner files="old.md" purpose="historical active entry" release="released later"
[2026-01-01 released] owner=Historical/owner files="old.md" outcome="done"
"@ | Set-Content -LiteralPath $tempFile -Encoding utf8

try {
  $historicalCheck = Invoke-Claim -ArgumentList @("-OwnershipFile", $tempFile, "-CheckOnly")
  if ($historicalCheck.ExitCode -ne 0) {
    throw "historical active entry produced false conflict"
  }

  $claim = Invoke-Claim -ArgumentList @("-OwnershipFile", $tempFile, "-Tool", "Owner/A", "-Files", "a.md", "-Purpose", "smoke")
  if ($claim.ExitCode -ne 0) {
    throw "claim failed"
  }

  $ownCheck = Invoke-Claim -ArgumentList @("-OwnershipFile", $tempFile, "-Tool", "Owner/A", "-CheckOnly")
  if ($ownCheck.ExitCode -ne 0) {
    throw "owner check failed"
  }

  $conflictCheck = Invoke-Claim -ArgumentList @("-OwnershipFile", $tempFile, "-Tool", "Owner/B", "-RepoRoot", $repoRoot, "-CheckOnly")
  if ($conflictCheck.ExitCode -eq 0) {
    throw "conflict check failed to block second owner"
  }
  if (-not (($conflictCheck.Output -join "`n") -match "new_task_worktree\.ps1")) {
    throw "conflict output did not include worktree remedy"
  }

  $release = Invoke-Claim -ArgumentList @("-OwnershipFile", $tempFile, "-Tool", "Owner/A", "-Files", "a.md", "-Outcome", "smoke release", "-ReleaseOwnership")
  if ($release.ExitCode -ne 0) {
    throw "release failed"
  }

  $postReleaseCheck = Invoke-Claim -ArgumentList @("-OwnershipFile", $tempFile, "-Tool", "Owner/B", "-CheckOnly")
  if ($postReleaseCheck.ExitCode -ne 0) {
    throw "release did not clear current ownership"
  }

  Write-Output "claim_ownership_smoke: PASS"
} finally {
  Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
}
