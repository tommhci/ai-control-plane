param(
  [string]$ControlPlaneRepo = (Split-Path $PSScriptRoot -Parent)
)

# KNOWN NOISE (recorded 2026-08-23, do not re-investigate without new signal):
# during batch/sequential runs this test may print
#   "InvalidOperation: You cannot call a method on a null-valued expression."
# while still exiting 0. Verified: single-run is clean (no message, exit 0);
# the message is a benign side effect of batch stderr capture, not a defect.
# Exit code is the verdict; the stderr line is not a failure signal.
# Tracked in scripts/run-full-suite.ps1 as expected batch noise.

$ErrorActionPreference = "Continue"

$import = Join-Path $ControlPlaneRepo "state\sqlite\import_jsonl_to_sqlite.ps1"
$query  = Join-Path $ControlPlaneRepo "state\sqlite\query_control_plane_state.ps1"

if (-not (Test-Path $import)) { throw "import script not found: $import" }
if (-not (Test-Path $query))  { throw "query script not found: $query" }

$dbPath = Join-Path $env:TEMP ("acp-sqlite-test-" + [guid]::NewGuid().ToString("N") + ".db")

# Create minimal dummy JSONL for two clients
$tmpDir = Join-Path $env:TEMP ("acp-sqlite-client-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path "$tmpDir\alpha\.agents" -Force | Out-Null
New-Item -ItemType Directory -Path "$tmpDir\beta\.agents"  -Force | Out-Null

$eventAlpha = @(
  '{"event_type":"stop_event","timestamp":"2026-01-01T00:00:00Z","session_id":"s1","stop_condition":"test","reason":"test","resolution":"fired_awaiting_user"}',
  '{"event_type":"note","timestamp":"2026-01-01T00:01:00Z","session_id":"s1","domain":"test","summary":"note 1"}',
  'not-valid-json',
  '{"missing_required_fields":true}'
) -join "`n"

$eventBeta = @(
  '{"event_type":"stop_event","timestamp":"2026-02-01T00:00:00Z","session_id":"s2","stop_condition":"test","reason":"test","resolution":"resumed_by_user"}'
) -join "`n"

Set-Content "$tmpDir\alpha\.agents\session_log.jsonl" $eventAlpha -Encoding utf8
Set-Content "$tmpDir\beta\.agents\session_log.jsonl"  $eventBeta  -Encoding utf8

try {
  # Test 1: Import alpha client
  $r1 = & powershell -NoProfile -ExecutionPolicy Bypass -File $import `
    -ClientRoot "$tmpDir\alpha" -DatabasePath $dbPath -ClientId "alpha" -DisplayName "Alpha Client" 2>&1 | Out-String
  $j1 = $r1.Trim() | ConvertFrom-Json
  if ($j1.status -ne "OK")           { throw "alpha import status: expected OK, got $($j1.status)" }
  if ($j1.total_events_for_client -ne 2) { throw "alpha import: expected 2 events, got $($j1.total_events_for_client)" }
  Write-Host "test_sqlite_import_alpha: PASS (imported=$($j1.total_events_for_client))"

  # Test 2: Import beta client
  $r2 = & powershell -NoProfile -ExecutionPolicy Bypass -File $import `
    -ClientRoot "$tmpDir\beta" -DatabasePath $dbPath -ClientId "beta" -DisplayName "Beta Client" 2>&1 | Out-String
  $j2 = $r2.Trim() | ConvertFrom-Json
  if ($j2.status -ne "OK")           { throw "beta import status: expected OK, got $($j2.status)" }
  if ($j2.total_events_for_client -ne 1) { throw "beta import: expected 1 event, got $($j2.total_events_for_client)" }
  Write-Host "test_sqlite_import_beta: PASS (imported=$($j2.total_events_for_client))"

  # Test 3: Idempotency — re-import alpha, events should not grow
  $r3 = & powershell -NoProfile -ExecutionPolicy Bypass -File $import `
    -ClientRoot "$tmpDir\alpha" -DatabasePath $dbPath -ClientId "alpha" -DisplayName "Alpha Client" 2>&1 | Out-String
  $j3 = $r3.Trim() | ConvertFrom-Json
  if ($j3.status -ne "OK")           { throw "idempotency import status: expected OK" }
  if ($j3.total_events_for_client -ne 2) { throw "idempotency: event count changed after re-import (got $($j3.total_events_for_client))" }
  $src3 = $j3.sources[0]
  if ($src3.imported -ne 0)          { throw "idempotency: expected 0 new imports, got $($src3.imported)" }
  Write-Host "test_sqlite_idempotency: PASS (re-import added 0 events)"

  # Test 4: Malformed lines skipped
  if ($src3.lines_read -ne 4)        { throw "malformed skip: expected 4 lines_read, got $($src3.lines_read)" }
  Write-Host "test_sqlite_malformed_skip: PASS (lines_read=$($src3.lines_read), skipped=$($src3.skipped))"

  # Test 5: Query — two clients visible
  $r5 = & powershell -NoProfile -ExecutionPolicy Bypass -File $query -DatabasePath $dbPath 2>&1 | Out-String
  $j5 = $r5.Trim() | ConvertFrom-Json
  if ($j5.status -ne "OK")           { throw "query status: expected OK" }
  if ($j5.clients.Count -ne 2)       { throw "query: expected 2 clients, got $($j5.clients.Count)" }
  if ($j5.total_events -ne 3)        { throw "query: expected 3 total events, got $($j5.total_events)" }
  if ($j5.stop_event_count -ne 2)    { throw "query: expected 2 stop_events, got $($j5.stop_event_count)" }
  Write-Host "test_sqlite_query: PASS (clients=$($j5.clients.Count), events=$($j5.total_events), stop_events=$($j5.stop_event_count))"

  Write-Host ""
  Write-Host "sqlite_mirror: ALL PASS"
} finally {
  Remove-Item $dbPath -Force -ErrorAction SilentlyContinue
  Remove-Item $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
}
