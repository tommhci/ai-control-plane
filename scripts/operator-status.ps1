param(
  [string]$ClientRoot      = ".",
  [string]$ControlPlaneRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ClientRoot)) {
  throw "ClientRoot does not exist: $ClientRoot"
}
$resolvedClient = (Resolve-Path -LiteralPath $ClientRoot).Path

$healthScript = Join-Path $ControlPlaneRepo "installers\health-check.ps1"
$driftScript  = Join-Path $ControlPlaneRepo "security\scan_control_plane_drift.ps1"

foreach ($s in @($healthScript, $driftScript)) {
  if (-not (Test-Path -LiteralPath $s)) { throw "required script not found: $s" }
}

$ErrorActionPreference = "Continue"

if ($Json) {
  # JSON mode: suppress terminal output, capture drift lines for error counts
  & powershell -NonInteractive -ExecutionPolicy Bypass -File $healthScript `
    -RepoRoot $resolvedClient -Quiet 2>&1 | Out-Null
  $healthExit = $LASTEXITCODE

  $driftLines    = & powershell -NonInteractive -ExecutionPolicy Bypass -File $driftScript `
    -ClientRoot $resolvedClient 2>&1
  $driftExit     = $LASTEXITCODE
  $driftErrors   = @($driftLines | Where-Object { "$_" -match "^ERROR:" }).Count
  $driftWarnings = @($driftLines | Where-Object { "$_" -match "^WARN:"  }).Count

  $overall = if ($healthExit -eq 0 -and $driftExit -eq 0) { "PASS" } else { "FAIL" }

  [pscustomobject]@{
    timestamp  = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    clientRoot = $resolvedClient
    health = [pscustomobject]@{
      status = if ($healthExit -eq 0) { "PASS" } else { "FAIL" }
    }
    drift = [pscustomobject]@{
      status   = if ($driftExit -eq 0) { "PASS" } else { "FAIL" }
      errors   = $driftErrors
      warnings = $driftWarnings
    }
    overall = $overall
  } | ConvertTo-Json -Depth 4
} else {
  Write-Host ""
  Write-Host "=== Health Check ===" -ForegroundColor Cyan
  & powershell -NonInteractive -ExecutionPolicy Bypass -File $healthScript -RepoRoot $resolvedClient
  $healthExit = $LASTEXITCODE

  Write-Host ""
  Write-Host "=== Drift Scan ===" -ForegroundColor Cyan
  & powershell -NonInteractive -ExecutionPolicy Bypass -File $driftScript -ClientRoot $resolvedClient
  $driftExit = $LASTEXITCODE

  $overall = if ($healthExit -eq 0 -and $driftExit -eq 0) { "PASS" } else { "FAIL" }
  $color   = if ($overall -eq "PASS") { "Green" } else { "Red" }
  Write-Host ""
  Write-Host "operator-status: $overall" -ForegroundColor $color
}

exit $(if ($overall -eq "PASS") { 0 } else { 1 })
