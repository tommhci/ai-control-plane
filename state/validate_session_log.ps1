param(
  [string]$InputPath = ".agents/session_log.jsonl"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $InputPath)) {
  throw "Missing session log: $InputPath"
}

$lineNumber = 0
$errors = New-Object System.Collections.Generic.List[string]

Get-Content -LiteralPath $InputPath | ForEach-Object {
  $lineNumber += 1
  if ([string]::IsNullOrWhiteSpace($_)) {
    return
  }

  try {
    $event = $_ | ConvertFrom-Json
  } catch {
    $errors.Add("line ${lineNumber}: invalid JSON")
    return
  }

  if ($event.event_type -ne "session_state") {
    return
  }

  if ($event.authority -ne "machine") {
    $errors.Add("line ${lineNumber}: session_state authority must be machine")
  }

  if ($event.repo.branch.source_command -ne "git branch --show-current") {
    $errors.Add("line ${lineNumber}: branch source_command mismatch")
  }
  if ($event.repo.head_commit.source_command -ne "git rev-parse --short HEAD") {
    $errors.Add("line ${lineNumber}: head_commit source_command mismatch")
  }
  if ($event.repo.dirty_files.source_command -ne "git status --porcelain=v1") {
    $errors.Add("line ${lineNumber}: dirty_files source_command mismatch")
  }

  if ($event.tests.status -eq "verified_now") {
    if ([string]::IsNullOrWhiteSpace([string]$event.tests.command)) {
      $errors.Add("line ${lineNumber}: verified_now tests require command")
    }
    if ([string]::IsNullOrWhiteSpace([string]$event.tests.result)) {
      $errors.Add("line ${lineNumber}: verified_now tests require result")
    }
  }
}

if ($errors.Count -gt 0) {
  $errors | ForEach-Object { Write-Error $_ }
  throw "session log validation failed with $($errors.Count) error(s)"
}

Write-Output "session_log_validation_ok"
