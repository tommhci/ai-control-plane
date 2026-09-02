param(
  [ValidateSet("stop_event", "session_state", "note", "instinct_promoted")]
  [string]$EventType = "stop_event",
  [string]$EventJson = "",
  [string]$SessionId = "",
  [string]$StopCondition = "",
  [string]$Reason = "",
  [ValidateSet("fired_awaiting_user", "resumed_by_user", "bypassed_by_user", "")]
  [string]$Resolution = "fired_awaiting_user",
  [string]$Domain = "",
  [string]$Summary = "",
  [string]$OutputPath = ".agents/session_log.jsonl",
  [string]$LockFile = ".agents/.session_log.lock"
)

$ErrorActionPreference = "Stop"

# File-lock for concurrent write safety (replaces silent last-write-wins)
$maxWaitMs = 5000
$waitedMs = 0
while (Test-Path $LockFile) {
  if ($waitedMs -ge $maxWaitMs) {
    throw "write_session_event: lock timeout after ${maxWaitMs}ms — another process holds $LockFile"
  }
  Start-Sleep -Milliseconds 100
  $waitedMs += 100
}

try {
  New-Item $LockFile -ItemType File -Force | Out-Null

  if (-not [string]::IsNullOrWhiteSpace($EventJson)) {
    try {
      $event = $EventJson | ConvertFrom-Json
    } catch {
      throw "write_session_event: EventJson is not valid JSON"
    }

    if ([string]::IsNullOrWhiteSpace([string]$event.event_type)) {
      throw "write_session_event: EventJson requires event_type"
    }
    if ([string]::IsNullOrWhiteSpace([string]$event.timestamp)) {
      throw "write_session_event: EventJson requires timestamp"
    }
    if ([string]::IsNullOrWhiteSpace([string]$event.session_id)) {
      throw "write_session_event: EventJson requires session_id"
    }

    $json = $event | ConvertTo-Json -Depth 12 -Compress
  } else {
    if ([string]::IsNullOrWhiteSpace($SessionId)) {
      $SessionId = "session-" + (Get-Date -Format "yyyyMMdd-HHmmss")
    }

    $event = [ordered]@{ event_type = $EventType; timestamp = (Get-Date).ToString("o"); session_id = $SessionId }

    if ($EventType -eq "stop_event") {
      if ([string]::IsNullOrWhiteSpace($StopCondition)) { throw "stop_event requires -StopCondition" }
      $event["stop_condition"] = $StopCondition
      $event["reason"] = $Reason
      $event["resolution"] = $Resolution
    } elseif ($EventType -eq "note" -or $EventType -eq "instinct_promoted") {
      $event["domain"] = $Domain
      $event["summary"] = $Summary
    }

    $json = $event | ConvertTo-Json -Depth 4 -Compress
  }

  Add-Content -LiteralPath $OutputPath -Value $json -Encoding utf8
  Write-Output $json
} finally {
  Remove-Item $LockFile -Force -ErrorAction SilentlyContinue
}
