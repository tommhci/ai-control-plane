<#
.SYNOPSIS
    List available harness install profiles and their support status.

.PARAMETER Json
    Output as JSON array instead of formatted table.

.EXAMPLE
    & list-profiles.ps1
    & list-profiles.ps1 -Json
#>
param([switch]$Json)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$profilesDir = Join-Path $PSScriptRoot "..\profiles"
$profilesDir = [System.IO.Path]::GetFullPath($profilesDir)

if (-not (Test-Path $profilesDir)) {
    Write-Error "profiles/ directory not found at: $profilesDir"
    exit 1
}

$profiles = @()
Get-ChildItem $profilesDir -Filter "*.json" | Sort-Object Name | ForEach-Object {
    try {
        $p = Get-Content $_.FullName | ConvertFrom-Json
        $profiles += [pscustomobject]@{
            profile_id       = $p.profile_id
            harness          = $p.harness
            supported_status = $p.supported_status
            hook_support     = $p.hook_support
            settings_path    = $p.settings_path
        }
    } catch {
        Write-Warning "Could not parse $($_.Name): $_"
    }
}

if ($profiles.Count -eq 0) {
    Write-Output "No profiles found in $profilesDir"
    exit 0
}

if ($Json) {
    $profiles | ConvertTo-Json -Depth 5
} else {
    Write-Output ""
    Write-Output "Available Install Profiles"
    Write-Output "═══════════════════════════════════════════════════════════════"
    $profiles | ForEach-Object {
        $status = switch ($_.supported_status) {
            "verified"     { "[VERIFIED]    " }
            "experimental" { "[EXPERIMENTAL]" }
            "stub"         { "[STUB]         " }
            default        { "[$($_.supported_status)]" }
        }
        $hooks = if ($_.hook_support) { "hooks:yes" } else { "hooks:no" }
        Write-Output "  $status  $($_.profile_id.PadRight(14)) $hooks   $($_.harness)"
    }
    Write-Output ""
    Write-Output "Usage: installers/install-profile.ps1 -ClientRoot <path> -Profile <profile_id>"
    Write-Output ""
    Write-Output "Note: Only 'verified' profiles have been tested end-to-end."
    Write-Output "      'experimental' and 'stub' profiles require manual validation."
}

exit 0
