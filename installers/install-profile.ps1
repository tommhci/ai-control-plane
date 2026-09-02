<#
.SYNOPSIS
    Apply a harness-specific install profile to a client root.

.DESCRIPTION
    Validates the selected profile, checks existing settings, and applies 
    profile-specific install guidance. Does NOT overwrite existing settings 
    without backup or -Force.

    Experimental and stub profiles are applied but clearly marked as 
    unverified. Only claude-code is verified.

.PARAMETER ClientRoot
    Path to the client project root.

.PARAMETER Profile
    Profile ID to apply (claude-code | codex | cursor | generic | opencode).

.PARAMETER ControlPlaneRepo
    Path to the ai-control-plane repo. Defaults to the directory two levels 
    above this script.

.PARAMETER Force
    Overwrite existing settings files without prompting.

.EXAMPLE
    & install-profile.ps1 -ClientRoot C:\...\my-project -Profile claude-code
    & install-profile.ps1 -ClientRoot C:\...\my-project -Profile cursor -Force
#>
param(
    [Parameter(Mandatory=$true)][string]$ClientRoot,
    [Parameter(Mandatory=$true)][string]$Profile,
    [string]$ControlPlaneRepo = "",
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── resolve paths ──────────────────────────────────────────────────────────
if (-not $ControlPlaneRepo) {
    $ControlPlaneRepo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}
$profilesDir = Join-Path $ControlPlaneRepo "profiles"
$profileFile = Join-Path $profilesDir "$Profile.json"

# ── validation ────────────────────────────────────────────────────────────
if (-not (Test-Path $ClientRoot)) {
    Write-Error "ClientRoot not found: $ClientRoot"
    exit 1
}

if (-not (Test-Path $profileFile)) {
    Write-Output "[ERROR] Unknown profile: '$Profile'"
    Write-Output "  Available profiles:"
    Get-ChildItem $profilesDir -Filter "*.json" | ForEach-Object { Write-Output "    $($_.BaseName)" }
    exit 1
}

$p = Get-Content $profileFile | ConvertFrom-Json
Write-Output ""
Write-Output "[install-profile] Profile: $($p.profile_id)"
Write-Output "  Harness         : $($p.harness)"
Write-Output "  Supported status: $($p.supported_status)"
Write-Output "  Client root     : $ClientRoot"
Write-Output ""

if ($p.supported_status -ne "verified") {
    Write-Output "  WARNING: This profile is '$($p.supported_status)' - not verified end-to-end."
    Write-Output "     Manual validation required before claiming this harness is supported."
    Write-Output ""
}

# ── check required files ──────────────────────────────────────────────────
Write-Output "Checking required files..."
$missing = @()
foreach ($rf in $p.required_files) {
    $fullPath = Join-Path $ClientRoot $rf
    if (Test-Path $fullPath) {
        Write-Output "  PRESENT : $rf"
    } else {
        Write-Output "  MISSING : $rf"
        $missing += $rf
    }
}

# ── check settings_path collision ────────────────────────────────────────
$settingsMsg = ""
if ($p.settings_path) {
    $settingsFullPath = Join-Path $ClientRoot $p.settings_path
    if ((Test-Path $settingsFullPath) -and -not $Force) {
        $settingsMsg = "EXISTS"
        Write-Output ""
        Write-Output "  Settings path already exists: $($p.settings_path)"
        Write-Output "  Use -Force to overwrite, or inspect and merge manually."
    } elseif (Test-Path $settingsFullPath) {
        $settingsMsg = "OVERWRITE (Force)"
        Write-Output "  Settings path: $($p.settings_path) - will overwrite (-Force)"
    } else {
        $settingsMsg = "NOT_PRESENT"
    }
}

# ── apply: copy adapter template if .control-plane is missing ────────────
$cpDir = Join-Path $ClientRoot ".control-plane"
$templateDir = Join-Path $ControlPlaneRepo "templates\project-adapter"
if (-not (Test-Path $cpDir)) {
    if (Test-Path $templateDir) {
        Copy-Item -Recurse $templateDir $cpDir
        Write-Output ""
        Write-Output "  Copied .control-plane/ from template — update adapter.json placeholders."
    } else {
        Write-Output ""
        Write-Output "  Template not found at $templateDir — create .control-plane/ manually."
    }
} else {
    Write-Output ""
    Write-Output "  .control-plane/ already present — skipping template copy."
}

# ── print install steps ───────────────────────────────────────────────────
Write-Output ""
Write-Output "Install Steps for '$($p.profile_id)':"
$i = 1
foreach ($step in $p.install_steps) {
    Write-Output "  $i. $step"
    $i++
}

# ── health check guidance ────────────────────────────────────────────────
Write-Output ""
Write-Output "Health checks to run:"
foreach ($h in $p.health_checks) {
    Write-Output "  - $h"
}

# ── known limitations ────────────────────────────────────────────────────
if ($p.known_limitations.Count -gt 0) {
    Write-Output ""
    Write-Output "Known limitations:"
    foreach ($l in $p.known_limitations) {
        Write-Output "  * $l"
    }
}

# ── summary ──────────────────────────────────────────────────────────────
Write-Output ""
Write-Output "-----------------------------------------"
$status = if ($missing.Count -eq 0) { "READY" } else { "INCOMPLETE (missing: $($missing.Count) files)" }
Write-Output "Profile applied: $($p.profile_id) | status: $($p.supported_status) | client: $status"

if ($p.supported_status -ne "verified") {
    Write-Output ""
    Write-Output "REMINDER: '$($p.profile_id)' is $($p.supported_status)."
    Write-Output "Do not report this harness as supported until real session validation passes."
}

exit 0
