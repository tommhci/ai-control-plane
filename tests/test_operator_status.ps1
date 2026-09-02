param(
  [string]$ControlPlaneRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$statusScript = Join-Path $ControlPlaneRepo "scripts\operator-status.ps1"
$attachTest   = Join-Path $PSScriptRoot "test_dummy_client_attach.ps1"

if (-not (Test-Path -LiteralPath $statusScript)) { throw "operator-status.ps1 not found: $statusScript" }
if (-not (Test-Path -LiteralPath $attachTest))   { throw "test_dummy_client_attach.ps1 not found: $attachTest" }

$clientRoot = Join-Path $env:TEMP ("acp-status-test-" + [guid]::NewGuid().ToString("N"))

try {
  # ── 1. Spin up a fully installed dummy client ────────────────────────────────
  # Use Continue so git LF/CRLF warnings on stderr don't throw as NativeCommandError
  $ErrorActionPreference = "Continue"
  $attachLines = & powershell -NonInteractive -ExecutionPolicy Bypass -File $attachTest `
    -ControlPlaneRepo $ControlPlaneRepo `
    -ClientRoot $clientRoot `
    -KeepClient 2>&1
  $attachExit = $LASTEXITCODE
  $ErrorActionPreference = "Stop"
  if ($attachExit -ne 0) {
    $msg = $attachLines | ForEach-Object { "$_" } | Out-String
    throw "dummy client attach failed (exit=$attachExit):`n$msg"
  }

  # ── 2. JSON mode: valid client → overall PASS ────────────────────────────────
  $jsonOut = & powershell -NonInteractive -ExecutionPolicy Bypass -File $statusScript `
    -ClientRoot $clientRoot -Json 2>&1 | Out-String
  $jsonExit = $LASTEXITCODE

  if ($jsonExit -ne 0) { throw "test_operator_status_json: expected exit 0, got $jsonExit. Output:`n$jsonOut" }

  try {
    $result = $jsonOut.Trim() | ConvertFrom-Json
  } catch {
    throw "test_operator_status_json: JSON parse failed. Raw output:`n$jsonOut"
  }

  foreach ($field in @("timestamp", "clientRoot", "health", "drift", "overall")) {
    if ($null -eq $result.$field) { throw "test_operator_status_json: missing field '$field'" }
  }
  if ($result.overall       -ne "PASS") { throw "test_operator_status_json: overall=$($result.overall), expected PASS" }
  if ($result.health.status -ne "PASS") { throw "test_operator_status_json: health.status=$($result.health.status), expected PASS" }
  if ($result.drift.status  -ne "PASS") { throw "test_operator_status_json: drift.status=$($result.drift.status), expected PASS" }
  Write-Host "test_operator_status_json: PASS"

  # ── 3. Human mode: valid client → exit 0 ────────────────────────────────────
  & powershell -NonInteractive -ExecutionPolicy Bypass -File $statusScript `
    -ClientRoot $clientRoot 2>&1 | Out-Null
  $humanExit = $LASTEXITCODE
  if ($humanExit -ne 0) { throw "test_operator_status_human: expected exit 0, got $humanExit" }
  Write-Host "test_operator_status_human: PASS"

  # ── 4. Invalid client → exit non-zero ────────────────────────────────────────
  $ErrorActionPreference = "Continue"
  & powershell -NonInteractive -ExecutionPolicy Bypass -File $statusScript `
    -ClientRoot "C:\this-path-does-not-exist-99999" 2>&1 | Out-Null
  $badExit = $LASTEXITCODE
  $ErrorActionPreference = "Stop"
  if ($badExit -eq 0) { throw "test_operator_status_invalid: expected non-zero exit, got 0" }
  Write-Host "test_operator_status_invalid: PASS"

} finally {
  if (Test-Path -LiteralPath $clientRoot) {
    Remove-Item -LiteralPath $clientRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Write-Host ""
Write-Host "operator_status: ALL PASS"
exit 0
