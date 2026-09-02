param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path $PSScriptRoot -Parent
$attachScript = Join-Path $repoRoot "installers\attach-project.ps1"
$initScript = Join-Path $repoRoot "installers\init-project.ps1"
$healthScript = Join-Path $repoRoot "scripts\check-attach-health.ps1"
$tmpBase = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "aicp-attach-init-$([System.Guid]::NewGuid().ToString('N').Substring(0,8))")
New-Item -ItemType Directory -Path $tmpBase -Force | Out-Null

$pass = 0
$fail = 0

function Assert-True {
    param([bool]$Condition, [string]$Label)
    if ($Condition) {
        Write-Output "  PASS: $Label"
        $script:pass++
    } else {
        Write-Output "  FAIL: $Label"
        $script:fail++
    }
}

try {
    Write-Output ""
    Write-Output "=== test_attach_existing_project_minimal ==="
    $client = Join-Path $tmpBase "existing-client"
    New-Item -ItemType Directory -Path $client -Force | Out-Null
    "# Existing Client" | Set-Content -LiteralPath (Join-Path $client "README.md") -Encoding utf8

    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $attachScript `
        -ClientRoot $client `
        -Profile generic `
        -Tier minimal `
        -ControlPlaneRepo $repoRoot `
        -SkipProfile 2>&1
    Assert-True ($LASTEXITCODE -eq 0) "attach-project exits 0"
    Assert-True (Test-Path (Join-Path $client "AGENTS.md")) "AGENTS.md created"
    Assert-True (Test-Path (Join-Path $client "AI_BOOTSTRAP.md")) "AI_BOOTSTRAP.md created"
    Assert-True (Test-Path (Join-Path $client "PROJECT_STATUS.md")) "PROJECT_STATUS.md created"
    Assert-True (Test-Path (Join-Path $client "CLAUDE.md")) "CLAUDE.md created"
    Assert-True (Test-Path (Join-Path $client ".control-plane\adapter.json")) "adapter.json created"
    Assert-True (Test-Path (Join-Path $client ".agents\ACTIVE_EDIT_OWNERSHIP.md")) "ownership file created"

    $adapter = Get-Content -LiteralPath (Join-Path $client ".control-plane\adapter.json") -Raw | ConvertFrom-Json
    Assert-True ($adapter.controlPlaneRepo -eq $repoRoot) "adapter points to control plane"
    Assert-True ($adapter.adapterId -eq "existing-client") "adapterId defaults from folder"

    $pp = Get-Content -LiteralPath (Join-Path $client ".control-plane\protected-paths.json") -Raw | ConvertFrom-Json
    Assert-True (@($pp.protectedPaths) -contains "AGENTS.md") "protected paths include AGENTS.md"
    Assert-True (-not (@($pp.protectedPaths) -contains "governance/")) "minimal tier excludes governance/"

    $health = & powershell -NoProfile -ExecutionPolicy Bypass -File $healthScript -ClientRoot $client -ControlPlaneRepo $repoRoot 2>&1
    Assert-True ($LASTEXITCODE -eq 0) "minimal attach health check passes"
    Assert-True ([bool]($health | Select-String "All checks PASS")) "health output says all pass"

    Write-Output ""
    Write-Output "=== test_init_new_project_standard ==="
    $newProject = Join-Path $tmpBase "new-client"
    $out2 = & powershell -NoProfile -ExecutionPolicy Bypass -File $initScript `
        -ProjectRoot $newProject `
        -Profile generic `
        -Tier standard `
        -ControlPlaneRepo $repoRoot `
        -SkipProfile 2>&1
    Assert-True ($LASTEXITCODE -eq 0) "init-project exits 0"
    Assert-True (Test-Path (Join-Path $newProject "HANDOVER.md")) "standard tier creates HANDOVER.md"
    Assert-True (Test-Path (Join-Path $newProject "NODE_QUEUE.md")) "standard tier creates NODE_QUEUE.md"
    Assert-True (Test-Path (Join-Path $newProject "governance\README.md")) "standard tier creates governance/"

    $pp2 = Get-Content -LiteralPath (Join-Path $newProject ".control-plane\protected-paths.json") -Raw | ConvertFrom-Json
    Assert-True (@($pp2.protectedPaths) -contains "governance/") "standard protected paths include governance/"

    $health2 = & powershell -NoProfile -ExecutionPolicy Bypass -File $healthScript -ClientRoot $newProject -ControlPlaneRepo $repoRoot 2>&1
    Assert-True ($LASTEXITCODE -eq 0) "standard init health check passes"

    Write-Output ""
    Write-Output "=== test_attach_claude_code_profile_installs_harness ==="
    $claudeClient = Join-Path $tmpBase "claude-client"
    New-Item -ItemType Directory -Path $claudeClient -Force | Out-Null
    Push-Location $claudeClient
    try {
        & git init | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "git init failed" }
        "# Claude Client" | Set-Content -LiteralPath "README.md" -Encoding utf8
    } finally {
        Pop-Location
    }

    $out3 = & powershell -NoProfile -ExecutionPolicy Bypass -File $attachScript `
        -ClientRoot $claudeClient `
        -Profile claude-code `
        -Tier minimal `
        -ControlPlaneRepo $repoRoot 2>&1
    Assert-True ($LASTEXITCODE -eq 0) "claude-code attach exits 0"
    Assert-True (Test-Path (Join-Path $claudeClient ".claude\settings.local.json")) "Claude settings created"
    Assert-True (Test-Path (Join-Path $claudeClient ".git\hooks\pre-commit")) "git pre-commit hook created"
    Assert-True (Test-Path (Join-Path $claudeClient ".git\hooks\post-commit")) "git post-commit hook created"
    Assert-True (Test-Path (Join-Path $claudeClient ".agents\skills\session-close\SKILL.md")) "shared skills synced"

    $fullHealth = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repoRoot "installers\health-check.ps1") `
        -RepoRoot $claudeClient `
        -Quiet 2>&1
    Assert-True ($LASTEXITCODE -eq 0) "claude-code full health check passes"
} finally {
    Remove-Item -LiteralPath $tmpBase -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Output ""
Write-Output "-----------------------------------------"
$total = $pass + $fail
Write-Output "project_attach_init: $pass/$total PASS, $fail FAIL"
if ($fail -gt 0) {
    Write-Output "project_attach_init: SOME FAILURES"
    exit 1
}
Write-Output "project_attach_init: ALL PASS"
exit 0
