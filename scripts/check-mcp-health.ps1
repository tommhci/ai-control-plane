# CANONICAL SOURCE — ai-control-plane/scripts/check-mcp-health.ps1
#
# Diagnostic and auto-repair utility for Antigravity MCP server configurations.
# Checks:
#   1. Validates mcp_config.json schema and active server entries.
#   2. Detects installed Google Cloud Data Agent Kit extension versions in ~/.antigravity-ide/extensions.
#   3. Probes active Windows Named Pipes (datacloud-mcp-*) for running servers.
#   4. With -Fix flag, automatically updates outdated extension paths and prunes deprecated servers.

[CmdletBinding()]
param(
    [switch]$Fix,
    [switch]$Quiet
)

$ErrorActionPreference = "Stop"

$mcpConfigPath = Join-Path $HOME ".gemini\config\mcp_config.json"
$extensionsDir = Join-Path $HOME ".antigravity-ide\extensions"

$result = [ordered]@{
    ConfigFound      = $false
    ActiveServers    = @()
    ExtensionsFound  = @()
    LatestExtension  = $null
    PipesOnline      = @()
    PipesOffline     = @()
    OutdatedEntries  = @()
    IssuesFound      = 0
    Fixed            = $false
}

# ── 1. Check mcp_config.json ──────────────────────────────────────────────────
if (-not (Test-Path $mcpConfigPath)) {
    if (-not $Quiet) { Write-Warning "mcp_config.json not found at $mcpConfigPath" }
    return $result
}
$result.ConfigFound = $true

try {
    $configContent = Get-Content $mcpConfigPath -Raw -Encoding utf8
    $configJson = $configContent | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse JSON from $($mcpConfigPath) - $_"
    return $result
}

# ── 2. Discover installed extension versions ─────────────────────────────────
if (Test-Path $extensionsDir) {
    $datacloudExts = Get-ChildItem -Path $extensionsDir -Directory -Filter "googlecloudtools.datacloud-*" |
        Sort-Object Name -Descending
    foreach ($ext in $datacloudExts) {
        $result.ExtensionsFound += $ext.Name
    }
    if ($datacloudExts.Count -gt 0) {
        $result.LatestExtension = $datacloudExts[0].FullName
    }
}

# ── 3. Check Windows Named Pipes ──────────────────────────────────────────────
$availablePipes = @()
if ($IsWindows -or $env:OS -match "Windows") {
    try {
        $pipeFiles = [System.IO.Directory]::GetFiles("\\.\pipe\")
        $availablePipes = $pipeFiles | Where-Object { $_ -match "datacloud-mcp" }
    } catch {
        # Fallback if pipe directory inspection fails
    }
}

# ── 4. Evaluate registered MCP servers ────────────────────────────────────────
$serversObj = $configJson.mcpServers
if ($null -ne $serversObj) {
    $serverNames = $serversObj.PSObject.Properties | Select-Object -ExpandProperty Name
    $result.ActiveServers = $serverNames

    foreach ($name in $serverNames) {
        $srv = $serversObj.$name
        $targetProxy = $srv.args[0]
        $pipeId = $srv.args[1]

        # Check if file path exists
        if (-not (Test-Path $targetProxy)) {
            $result.OutdatedEntries += $name
            $result.IssuesFound++
            if (-not $Quiet) {
                Write-Warning "MCP Server [$name] target proxy script does not exist: $targetProxy"
            }
        }

        # Check if named pipe is live
        $expectedPipePattern = "datacloud-mcp-$pipeId"
        $isLive = $availablePipes | Where-Object { $_ -match [regex]::Escape($expectedPipePattern) }
        if ($isLive) {
            $result.PipesOnline += $name
        } else {
            $result.PipesOffline += $name
        }
    }
}

# ── 5. Auto-repair if -Fix is passed ─────────────────────────────────────────
if ($Fix -and $null -ne $result.LatestExtension) {
    $latestProxyBundle = Join-Path $result.LatestExtension "mcp_servers\cli\mcp_proxy_bundle.js"
    if (Test-Path $latestProxyBundle) {
        $modified = $false
        
        # Remove deprecated context server if still present
        if ($null -ne $serversObj.context) {
            $serversObj.PSObject.Properties.Remove('context')
            $modified = $true
            if (-not $Quiet) { Write-Host "Pruned deprecated 'context' MCP server from config." -ForegroundColor Green }
        }

        # Update paths for remaining servers
        foreach ($prop in $serversObj.PSObject.Properties) {
            $sName = $prop.Name
            $currentArg0 = $serversObj.$sName.args[0]
            if ($currentArg0 -ne $latestProxyBundle) {
                $serversObj.$sName.args[0] = $latestProxyBundle
                $modified = $true
                if (-not $Quiet) { Write-Host "Updated [$sName] proxy path to latest extension ($latestProxyBundle)" -ForegroundColor Green }
            }
        }

        if ($modified) {
            $newJson = $configJson | ConvertTo-Json -Depth 10
            Set-Content -Path $mcpConfigPath -Value $newJson -Encoding utf8
            $result.Fixed = $true
            if (-not $Quiet) { Write-Host "Successfully saved updated $mcpConfigPath" -ForegroundColor Green }
        }
    }
}

if (-not $Quiet) {
    Write-Host "`n=== MCP Health Diagnostics ===" -ForegroundColor Cyan
    Write-Host "Config file: $mcpConfigPath (Found: $($result.ConfigFound))"
    Write-Host "Active servers: $($result.ActiveServers -join ', ')"
    Write-Host "Online pipes: $($result.PipesOnline -join ', ')"
    if ($result.PipesOffline.Count -gt 0) {
        Write-Host "Offline pipes: $($result.PipesOffline -join ', ')" -ForegroundColor Yellow
    }
    if ($result.IssuesFound -eq 0) {
        Write-Host "Status: HEALTHY (No path or version discrepancies)" -ForegroundColor Green
    } else {
        Write-Host "Status: UNHEALTHY ($($result.IssuesFound) issue(s) detected. Run with -Fix to auto-repair)" -ForegroundColor Red
    }
}

return $result

