param(
  [string]$SessionId = "",
  [ValidateSet("product", "governance", "personal", "analytical", "unknown")]
  [string]$Domain = "unknown",
  [string]$ActiveNode = "",
  [ValidateSet("verified_now", "historical", "unknown", "waived_by_user")]
  [string]$ActiveNodeStatus = "unknown",
  [ValidateSet("verified_now", "historical", "not_run", "failed", "unknown", "waived_by_user")]
  [string]$TestsStatus = "unknown",
  [string]$TestsCommand = "",
  [string]$TestsResult = "",
  [string]$Summary = "",
  [string]$OutputPath = ".agents/session_log.jsonl"
)

$ErrorActionPreference = "Stop"

function Invoke-GitValue {
  param([string[]]$GitArgs)
  $value = & git @GitArgs
  if ($LASTEXITCODE -ne 0) {
    throw "git $($GitArgs -join ' ') failed"
  }
  return $value
}

if ([string]::IsNullOrWhiteSpace($SessionId)) {
  $SessionId = "session-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

if ($TestsStatus -eq "verified_now" -and
    ([string]::IsNullOrWhiteSpace($TestsCommand) -or [string]::IsNullOrWhiteSpace($TestsResult))) {
  throw "TestsStatus=verified_now requires non-empty TestsCommand and TestsResult"
}

$branch = (Invoke-GitValue @("branch", "--show-current") | Select-Object -First 1)
$headCommit = (Invoke-GitValue @("rev-parse", "--short", "HEAD") | Select-Object -First 1)
$dirtyRaw = @(Invoke-GitValue @("status", "--porcelain=v1"))

$event = [ordered]@{
  event_type = "session_state"
  timestamp = (Get-Date).ToString("o")
  session_id = $SessionId
  domain = $Domain
  authority = "machine"
  repo = [ordered]@{
    branch = [ordered]@{
      value = $branch
      source_command = "git branch --show-current"
    }
    head_commit = [ordered]@{
      value = $headCommit
      source_command = "git rev-parse --short HEAD"
    }
    dirty_files = [ordered]@{
      value = $dirtyRaw
      source_command = "git status --porcelain=v1"
    }
  }
  tests = [ordered]@{
    status = $TestsStatus
    command = $(if ([string]::IsNullOrWhiteSpace($TestsCommand)) { $null } else { $TestsCommand })
    result = $(if ([string]::IsNullOrWhiteSpace($TestsResult)) { $null } else { $TestsResult })
  }
  active_node = [ordered]@{
    value = $(if ([string]::IsNullOrWhiteSpace($ActiveNode)) { $null } else { $ActiveNode })
    status = $ActiveNodeStatus
    source = $(if ([string]::IsNullOrWhiteSpace($ActiveNode)) { $null } else { "caller" })
  }
  summary = $(if ([string]::IsNullOrWhiteSpace($Summary)) { $null } else { $Summary })
}

$json = $event | ConvertTo-Json -Depth 8 -Compress
$writer = Join-Path $PSScriptRoot "write_session_event.ps1"
if (-not (Test-Path -LiteralPath $writer)) {
  throw "Missing session event writer: $writer"
}

& $writer -EventJson $json -OutputPath $OutputPath
