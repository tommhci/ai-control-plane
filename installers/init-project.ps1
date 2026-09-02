<#
.SYNOPSIS
    Create a new project directory and attach ai-control-plane.
#>
param(
    [Parameter(Mandatory=$true)][string]$ProjectRoot,
    [string]$Profile = "generic",
    [ValidateSet("minimal","standard")][string]$Tier = "minimal",
    [string]$ControlPlaneRepo = "",
    [string]$ProjectId = "",
    [string]$DisplayName = "",
    [switch]$GitInit,
    [switch]$Force,
    [switch]$SkipProfile,
    [switch]$SkipHarnessInstall,
    [switch]$SkipHealthCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $ControlPlaneRepo) {
    $ControlPlaneRepo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
if (-not (Test-Path -LiteralPath $ProjectRoot)) {
    New-Item -ItemType Directory -Path $ProjectRoot -Force | Out-Null
    Write-Output "[init-project] Created: $ProjectRoot"
} else {
    Write-Output "[init-project] Exists : $ProjectRoot"
}

if ($GitInit -and -not (Test-Path -LiteralPath (Join-Path $ProjectRoot ".git"))) {
    Push-Location $ProjectRoot
    try {
        & git init | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git init failed with exit $LASTEXITCODE" }
        Write-Output "[init-project] git init: PASS"
    } finally {
        Pop-Location
    }
}

$attachArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $ControlPlaneRepo "installers\attach-project.ps1"),
    "-ClientRoot", $ProjectRoot,
    "-Profile", $Profile,
    "-Tier", $Tier,
    "-ControlPlaneRepo", $ControlPlaneRepo
)
if ($ProjectId) { $attachArgs += @("-ProjectId", $ProjectId) }
if ($DisplayName) { $attachArgs += @("-DisplayName", $DisplayName) }
if ($Force) { $attachArgs += "-Force" }
if ($SkipProfile) { $attachArgs += "-SkipProfile" }
if ($SkipHarnessInstall) { $attachArgs += "-SkipHarnessInstall" }
if ($SkipHealthCheck) { $attachArgs += "-SkipHealthCheck" }

& powershell @attachArgs

if ($LASTEXITCODE -ne 0) { throw "attach-project failed with exit $LASTEXITCODE" }

Write-Output ""
Write-Output "init-project: PASS"
Write-Output "Project initialized and attached: $ProjectRoot"
