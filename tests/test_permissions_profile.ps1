param(
  [string]$ControlPlaneRepo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [string]$ClientRoot = (Join-Path $env:TEMP ("ai-control-plane-permissions-client-" + [guid]::NewGuid().ToString("N")))
)

$ErrorActionPreference = "Continue"

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "tests/test_dummy_client_attach.ps1") -ControlPlaneRepo $ControlPlaneRepo -ClientRoot $ClientRoot -KeepClient | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "dummy attach setup failed"
}

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "installers/install-permissions-profile.ps1") -RepoRoot $ClientRoot | Out-Null
if ($LASTEXITCODE -ne 0) {
  throw "permissions profile install failed"
}

$settings = Get-Content -LiteralPath (Join-Path $ClientRoot ".claude/settings.local.json") -Raw | ConvertFrom-Json
foreach ($bucket in @("allow", "ask", "deny")) {
  if ($null -eq $settings.permissions.$bucket -or @($settings.permissions.$bucket).Count -lt 1) {
    throw "missing permissions bucket after install: $bucket"
  }
}

foreach ($expected in @("WebFetch", "WebSearch", "Agent(*)", "Write(.claude/**)", "Write(.agents/skills/**)", "Write(.mcp.json)")) {
  if (@($settings.permissions.ask) -notcontains $expected) {
    throw "missing ask permission: $expected"
  }
}

foreach ($expected in @("Bash(git reset --hard*)", "Bash(git clean -fd*)")) {
  if (@($settings.permissions.deny) -notcontains $expected) {
    throw "missing deny permission: $expected"
  }
}

if (@($settings.hooks.PreToolUse).Count -lt 1) {
  throw "permissions install removed hooks"
}

Write-Output "permissions_profile_install: PASS"

if (Test-Path -LiteralPath $ClientRoot) {
  Remove-Item -LiteralPath $ClientRoot -Recurse -Force -ErrorAction SilentlyContinue
}
