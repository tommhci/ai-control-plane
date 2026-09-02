param(
  [string]$ControlPlaneRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$InputPath = ""  # pass -InputPath <path-to-your-project>/.agents/session_log.jsonl
)

$ErrorActionPreference = "Stop"

$python = Get-Command python -ErrorAction SilentlyContinue
if ($null -eq $python) {
  $python = Get-Command py -ErrorAction SilentlyContinue
}
if ($null -eq $python) {
  throw "Python is required for SQLite dry-run migration"
}

if ([string]::IsNullOrEmpty($InputPath)) {
  $tmpDir = Join-Path $env:TEMP ("acp-migration-test-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
  $InputPath = Join-Path $tmpDir "session_log.jsonl"
  @(
    '{"event_type":"stop_event","timestamp":"2026-01-01T00:00:00Z","session_id":"s-test-1","stop_condition":"test","reason":"unit test","resolution":"fired_awaiting_user"}',
    '{"event_type":"note","timestamp":"2026-01-01T00:01:00Z","session_id":"s-test-1","domain":"product","summary":"migration test fixture"}'
  ) | Set-Content -LiteralPath $InputPath -Encoding utf8
}

$dbPath = Join-Path $env:TEMP "ai-control-plane-state-migration.sqlite"
Remove-Item -LiteralPath $dbPath -Force -ErrorAction SilentlyContinue

& $python.Source (Join-Path $ControlPlaneRepo "state/migrate_jsonl_to_sqlite.py") `
  --input $InputPath `
  --db $dbPath `
  --schema (Join-Path $ControlPlaneRepo "state/schema.sql")

if ($LASTEXITCODE -ne 0) {
  throw "state migration failed"
}

if (-not (Test-Path -LiteralPath $dbPath)) {
  throw "migration did not create sqlite db"
}

Write-Output "state_store_migration_test: PASS"
