# CANONICAL SOURCE — ai-control-plane/tests/test_check_mcp_health.ps1
#
# Unit test for scripts/check-mcp-health.ps1 (hermetic — uses a temp fixture
# config via -ConfigPath; never asserts machine-local MCP state).

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$ScriptPath = Join-Path $RepoRoot "scripts\check-mcp-health.ps1"

Write-Host "Running test_check_mcp_health.ps1..." -ForegroundColor Cyan

if (-not (Test-Path $ScriptPath)) {
    throw "check-mcp-health.ps1 script not found at $ScriptPath"
}

$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("mcp-health-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

try {
    # ── Scenario 1: fixture config with expected active servers ──────────────
    $fixtureConfig = Join-Path $tempDir "mcp_config.json"
    $fixture = [ordered]@{
        mcpServers = [ordered]@{
            "notebooks"      = [ordered]@{ command = "node"; args = @("C:/proxy/proxy_bundle.js", "notebooks-pipe") }
            "visualization"  = [ordered]@{ command = "node"; args = @("C:/proxy/proxy_bundle.js", "viz-pipe") }
            "data-agent-kit" = [ordered]@{ command = "node"; args = @("C:/proxy/proxy_bundle.js", "dak-pipe") }
        }
    }
    $fixture | ConvertTo-Json -Depth 5 | Set-Content -Path $fixtureConfig -Encoding utf8

    $result = & $ScriptPath -Quiet -ConfigPath $fixtureConfig

    if ($null -eq $result) {
        throw "Expected PSCustomObject or Hashtable result, got null"
    }

    if (-not $result.ConfigFound) {
        throw "Expected ConfigFound=true for fixture config at $fixtureConfig"
    }

    $expectedServers = @("notebooks", "visualization", "data-agent-kit")
    foreach ($srv in $expectedServers) {
        if ($result.ActiveServers -notcontains $srv) {
            throw "Expected active server list to contain $srv"
        }
    }

    # Deprecated server must not be registered in the fixture
    if ($result.ActiveServers -contains "context") {
        throw "Deprecated server 'context' must not be in active servers list"
    }

    Write-Host "PASS: fixture config scanned with $($result.ActiveServers.Count) servers." -ForegroundColor Green

    # ── Scenario 2: missing config → clean early return, no throw ─────────────
    $missingPath = Join-Path $tempDir "does-not-exist.json"
    $result2 = & $ScriptPath -Quiet -ConfigPath $missingPath

    if ($null -eq $result2) {
        throw "Expected result object for missing config, got null"
    }
    if ($result2.ConfigFound) {
        throw "Expected ConfigFound=false for missing config"
    }
    if ($result2.ActiveServers.Count -ne 0) {
        throw "Expected empty ActiveServers for missing config"
    }

    Write-Host "PASS: missing config handled with clean early return." -ForegroundColor Green
}
finally {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit 0
