param(
  [string]$RepoRoot = ".",
  [string]$ProfilePath = "",
  [string]$SettingsPath = ".claude/settings.local.json",
  [switch]$NoBackup
)

$ErrorActionPreference = "Stop"

$resolvedRepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
if ([string]::IsNullOrWhiteSpace($ProfilePath)) {
  $ProfilePath = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")).Path "permissions/ask-mode-baseline.json"
}

$resolvedProfilePath = (Resolve-Path -LiteralPath $ProfilePath).Path
$resolvedSettingsPath = Join-Path $resolvedRepoRoot $SettingsPath

if (-not (Test-Path -LiteralPath $resolvedSettingsPath)) {
  throw "Missing Claude settings file: $resolvedSettingsPath. Run install-claude-client.ps1 first."
}

$profile = Get-Content -LiteralPath $resolvedProfilePath -Raw | ConvertFrom-Json
if ($null -eq $profile.permissions) {
  throw "Profile missing permissions object: $resolvedProfilePath"
}

$settings = Get-Content -LiteralPath $resolvedSettingsPath -Raw | ConvertFrom-Json
if ($null -eq $settings.permissions) {
  $settings | Add-Member -MemberType NoteProperty -Name permissions -Value ([pscustomobject]@{})
}

if (-not $NoBackup) {
  $backupPath = "$resolvedSettingsPath.permissions-backup"
  Copy-Item -LiteralPath $resolvedSettingsPath -Destination $backupPath -Force
}

foreach ($bucket in @("allow", "ask", "deny")) {
  $existing = @()
  if ($null -ne $settings.permissions.$bucket) {
    $existing = @($settings.permissions.$bucket)
  }

  $incoming = @()
  if ($null -ne $profile.permissions.$bucket) {
    $incoming = @($profile.permissions.$bucket)
  }

  $merged = @($existing + $incoming | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)

  if ($null -eq $settings.permissions.$bucket) {
    $settings.permissions | Add-Member -MemberType NoteProperty -Name $bucket -Value $merged
  } else {
    $settings.permissions.$bucket = $merged
  }
}

$settings | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resolvedSettingsPath -Encoding utf8

Write-Output "install-permissions-profile: PASS"
Write-Output "repoRoot=$resolvedRepoRoot"
Write-Output "profile=$resolvedProfilePath"
if (-not $NoBackup) {
  Write-Output "rollback=Copy-Item -Force '$backupPath' '$resolvedSettingsPath'"
}
