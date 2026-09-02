param(
  [Parameter(Mandatory)]
  [string]$ClientRoot,
  [Parameter(Mandatory)]
  [string]$DatabasePath,
  [string]$SchemaPath = "",
  [string]$ClientId = "",
  [string]$DisplayName = "",
  [switch]$IncludeEffectivenessLog,
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SchemaPath)) {
  $SchemaPath = Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) "schema.sql"
}

function Write-Status ([string]$msg) { if (-not $Quiet) { Write-Host $msg } }

# Resolve paths
$ClientRoot = (Resolve-Path $ClientRoot).Path

# Determine client identity from adapter if not provided
if ([string]::IsNullOrWhiteSpace($ClientId)) {
  $adapterPath = Join-Path $ClientRoot ".control-plane\adapter.json"
  if (Test-Path $adapterPath) {
    try {
      $adapter = Get-Content $adapterPath -Raw | ConvertFrom-Json
      $ClientId = $adapter.adapterId
      if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = $adapter.displayName }
    } catch {
      $ClientId = Split-Path $ClientRoot -Leaf
    }
  } else {
    $ClientId = Split-Path $ClientRoot -Leaf
  }
}
if ([string]::IsNullOrWhiteSpace($DisplayName)) { $DisplayName = $ClientId }

# Collect source JSONL files to import
$sourceFiles = @()
$sessionLog = Join-Path $ClientRoot ".agents\session_log.jsonl"
if (Test-Path $sessionLog) { $sourceFiles += $sessionLog }
if ($IncludeEffectivenessLog) {
  $effectivenessLog = Join-Path $ClientRoot ".agents\effectiveness_log.jsonl"
  if (Test-Path $effectivenessLog) { $sourceFiles += $effectivenessLog }
}

if ($sourceFiles.Count -eq 0) {
  Write-Host (ConvertTo-Json @{
    status = "INSUFFICIENT_DATA"
    client_id = $ClientId
    reason = "no JSONL source files found in $ClientRoot/.agents/"
  } -Compress)
  exit 0
}

# Ensure Python is available for SQLite operations
$pythonCmd = $null
foreach ($try in @("python", "python3", "py")) {
  try {
    $ver = & $try --version 2>&1
    if ($ver -match "Python") { $pythonCmd = $try; break }
  } catch {}
}
if ($null -eq $pythonCmd) {
  Write-Error "import_jsonl_to_sqlite: Python not found. Install Python 3 to use SQLite import."
  exit 1
}

# Resolve schema and DB paths
$SchemaPath = (Resolve-Path $SchemaPath).Path
$dbDir = Split-Path $DatabasePath -Parent
if (-not [string]::IsNullOrWhiteSpace($dbDir) -and -not (Test-Path $dbDir)) {
  New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
}
$DatabasePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DatabasePath)
$now = (Get-Date).ToString("o")

# Write Python script to a temp file to avoid PowerShell @"..."@ variable expansion
$pyTempFile = Join-Path $env:TEMP ("acp_import_" + [System.IO.Path]::GetRandomFileName() + ".py")

# Single-quoted here-string: PowerShell does NOT expand $ inside @'...'@
$pyCode = @'
import json, sqlite3, sys
from pathlib import Path

db_path = sys.argv[1]
schema_path = sys.argv[2]
client_id = sys.argv[3]
display_name = sys.argv[4]
client_root = sys.argv[5]
now = sys.argv[6]
source_files = sys.argv[7:]

schema = Path(schema_path).read_text(encoding="utf-8")

results = []
with sqlite3.connect(db_path) as conn:
    conn.executescript(schema)
    conn.execute(
        "INSERT OR REPLACE INTO clients(client_id, display_name, client_root, last_import) VALUES (?,?,?,?)",
        (client_id, display_name, client_root, now)
    )
    for sf in source_files:
        lines_read = lines_imported = lines_skipped = 0
        for line_no, line in enumerate(Path(sf).read_text(encoding="utf-8-sig").splitlines(), start=1):
            stripped = line.strip()
            if not stripped:
                continue
            lines_read += 1
            try:
                ev = json.loads(stripped)
            except json.JSONDecodeError:
                lines_skipped += 1
                continue
            et = ev.get("event_type")
            ts = ev.get("timestamp")
            sid = ev.get("session_id")
            if not et or not ts or not sid:
                lines_skipped += 1
                continue
            domain = ev.get("domain", "")
            node = ev.get("active_node", "")
            payload = json.dumps(ev, ensure_ascii=False, sort_keys=True)
            try:
                conn.execute(
                    "INSERT OR IGNORE INTO events(client_id, source_file, source_line, event_type, timestamp, session_id, domain, active_node, payload_json, imported_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
                    (client_id, sf, line_no, et, ts, sid, domain, node, payload, now)
                )
                lines_imported += conn.execute("SELECT changes()").fetchone()[0]
            except Exception:
                lines_skipped += 1
                continue
        conn.execute(
            "INSERT INTO imports(client_id, source_file, imported_at, lines_read, lines_imported, lines_skipped) VALUES (?,?,?,?,?,?)",
            (client_id, sf, now, lines_read, lines_imported, lines_skipped)
        )
        results.append({"source": sf, "lines_read": lines_read, "imported": lines_imported, "skipped": lines_skipped})

    total_events = conn.execute("SELECT COUNT(*) FROM events WHERE client_id=?", (client_id,)).fetchone()[0]

print(json.dumps({"status": "OK", "client_id": client_id, "sources": results, "total_events_for_client": total_events}))
'@

Set-Content -LiteralPath $pyTempFile -Value $pyCode -Encoding utf8

try {
  $pyArgs = @($DatabasePath, $SchemaPath, $ClientId, $DisplayName, $ClientRoot, $now) + $sourceFiles
  $result = & $pythonCmd $pyTempFile @pyArgs 2>&1

  if ($LASTEXITCODE -ne 0) {
    Write-Error "import_jsonl_to_sqlite: Python script failed: $result"
    exit 1
  }

  Write-Output $result
} finally {
  Remove-Item $pyTempFile -Force -ErrorAction SilentlyContinue
}
