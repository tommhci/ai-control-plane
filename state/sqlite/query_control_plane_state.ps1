param(
  [Parameter(Mandatory)]
  [string]$DatabasePath,
  [string]$ClientId = "",
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $DatabasePath)) {
  Write-Host (ConvertTo-Json @{
    status = "INSUFFICIENT_DATA"
    reason = "database not found: $DatabasePath"
    hint = "Run import_jsonl_to_sqlite.ps1 first"
  } -Compress)
  exit 0
}

$pythonCmd = $null
foreach ($try in @("python", "python3", "py")) {
  try {
    $ver = & $try --version 2>&1
    if ($ver -match "Python") { $pythonCmd = $try; break }
  } catch {}
}
if ($null -eq $pythonCmd) {
  Write-Error "query_control_plane_state: Python not found."
  exit 1
}

$DatabasePath = (Resolve-Path $DatabasePath).Path

$pyTempFile = Join-Path $env:TEMP ("acp_query_" + [System.IO.Path]::GetRandomFileName() + ".py")

$pyCode = @'
import json, sqlite3, sys

db_path = sys.argv[1]
client_filter = sys.argv[2] if len(sys.argv) > 2 else ""

with sqlite3.connect(db_path) as conn:
    conn.row_factory = sqlite3.Row

    if client_filter:
        clients = conn.execute("SELECT * FROM clients WHERE client_id=?", (client_filter,)).fetchall()
    else:
        clients = conn.execute("SELECT * FROM clients ORDER BY last_import DESC").fetchall()

    clients_list = [dict(r) for r in clients]

    if client_filter:
        where = "WHERE client_id=?"
        params = (client_filter,)
        and_kw = "AND"
    else:
        where = ""
        params = ()
        and_kw = "WHERE"

    total_events = conn.execute("SELECT COUNT(*) FROM events " + where, params).fetchone()[0]

    rows = conn.execute("SELECT event_type, COUNT(*) as cnt FROM events " + where + " GROUP BY event_type ORDER BY cnt DESC", params).fetchall()
    by_type = {r["event_type"]: r["cnt"] for r in rows}

    recent = conn.execute(
        "SELECT session_id, MIN(timestamp) as first_seen, MAX(timestamp) as last_seen, COUNT(*) as event_count FROM events " + where + " GROUP BY session_id ORDER BY last_seen DESC LIMIT 5",
        params
    ).fetchall()
    recent_sessions = [dict(r) for r in recent]

    stop_count = conn.execute(
        "SELECT COUNT(*) FROM events " + where + " " + and_kw + " event_type='stop_event'", params
    ).fetchone()[0]

    d7_count = conn.execute(
        "SELECT COUNT(*) FROM events " + where + " " + and_kw + " (event_type LIKE '%d7%' OR event_type LIKE '%meta%')", params
    ).fetchone()[0]

    eff_count = conn.execute(
        "SELECT COUNT(*) FROM events " + where + " " + and_kw + " event_type='skill_effectiveness'", params
    ).fetchone()[0]

    imp_where = where.replace("WHERE client_id", "WHERE client_id")
    bad = conn.execute("SELECT SUM(lines_skipped) FROM imports " + imp_where, params).fetchone()[0] or 0

    result = {
        "status": "OK",
        "clients": clients_list,
        "total_events": total_events,
        "events_by_type": by_type,
        "recent_sessions": recent_sessions,
        "stop_event_count": stop_count,
        "d7_meta_warning_count": d7_count,
        "effectiveness_event_count": eff_count,
        "data_quality": {
            "total_skipped_lines": bad,
            "quality": "GOOD" if bad == 0 else "DEGRADED"
        }
    }

print(json.dumps(result, indent=2))
'@

Set-Content -LiteralPath $pyTempFile -Value $pyCode -Encoding utf8

try {
  if ([string]::IsNullOrWhiteSpace($ClientId)) {
    $result = & $pythonCmd $pyTempFile $DatabasePath 2>&1
  } else {
    $result = & $pythonCmd $pyTempFile $DatabasePath $ClientId 2>&1
  }

  if ($LASTEXITCODE -ne 0) {
    Write-Error "query_control_plane_state: Python script failed: $result"
    exit 1
  }

  Write-Output $result
} finally {
  Remove-Item $pyTempFile -Force -ErrorAction SilentlyContinue
}
