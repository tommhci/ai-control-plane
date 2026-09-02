param(
  [string]$ControlPlaneRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$ClientRoot = (Join-Path $env:TEMP ("ai-control-plane-drift-client-" + [guid]::NewGuid().ToString("N")))
)

$ErrorActionPreference = "Stop"

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "tests/test_dummy_client_attach.ps1") -ControlPlaneRepo $ControlPlaneRepo -ClientRoot $ClientRoot -KeepClient | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "dummy attach setup failed"
}

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "security/scan_control_plane_drift.ps1") -ClientRoot $ClientRoot | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "drift scanner failed on clean dummy client"
}

$settingsPath = Join-Path $ClientRoot ".claude/settings.local.json"
$settings = Get-Content -LiteralPath $settingsPath -Raw
$settings = $settings.Replace(".control-plane/hooks/check-ownership.ps1", "$ControlPlaneRepo/state/claim_ownership.ps1")
Set-Content -LiteralPath $settingsPath -Value $settings -Encoding utf8

$oldPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
  $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "security/scan_control_plane_drift.ps1") -ClientRoot $ClientRoot 2>&1
  $exit = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $oldPreference
}

if ($exit -eq 0) {
  throw "drift scanner failed to detect synthetic absolute-path drift"
}

Write-Output "drift_scanner_synthetic: PASS"

if (Test-Path -LiteralPath $ClientRoot) {
  Remove-Item -LiteralPath $ClientRoot -Recurse -Force -ErrorAction SilentlyContinue
}

exit 0
