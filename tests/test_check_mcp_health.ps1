# CANONICAL SOURCE — ai-control-plane/tests/test_check_mcp_health.ps1
#
# Unit test for scripts/check-mcp-health.ps1

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir
$ScriptPath = Join-Path $RepoRoot "scripts\check-mcp-health.ps1"

Write-Host "Running test_check_mcp_health.ps1..." -ForegroundColor Cyan

if (-not (Test-Path $ScriptPath)) {
    throw "check-mcp-health.ps1 script not found at $ScriptPath"
}

# Run in quiet mode
$result = & $ScriptPath -Quiet

if ($null -eq $result) {
    throw "Expected PSCustomObject or Hashtable result, got null"
}

if (-not $result.ConfigFound) {
    throw "Expected mcp_config.json to be found on this machine"
}

if ($result.ActiveServers.Count -eq 0) {
    throw "Expected at least one active MCP server"
}

# Verify 'context' is not in ActiveServers
if ($result.ActiveServers -contains "context") {
    throw "Deprecated server 'context' must not be in active servers list"
}

# Verify valid servers exist
$expectedServers = @("notebooks", "visualization", "data-agent-kit")
foreach ($srv in $expectedServers) {
    if ($result.ActiveServers -notcontains $srv) {
        throw "Expected active server list to contain $srv"
    }
}

Write-Host "PASS: test_check_mcp_health passed with $($result.ActiveServers.Count) healthy servers." -ForegroundColor Green
exit 0
