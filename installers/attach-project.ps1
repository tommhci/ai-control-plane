<#
.SYNOPSIS
    Attach an existing project to ai-control-plane.

.DESCRIPTION
    Creates the thin project-local discovery layer that AI tools can see from
    the client repo root, plus the .control-plane adapter files used by shared
    health checks and hooks.

    This script intentionally copies only entrypoint/context files. It does not
    import the whole control plane into the client and does not overwrite
    existing project files unless -Force is provided.
#>
param(
    [Parameter(Mandatory=$true)][string]$ClientRoot,
    [string]$Profile = "generic",
    [ValidateSet("minimal","standard")][string]$Tier = "minimal",
    [string]$ControlPlaneRepo = "",
    [string]$ProjectId = "",
    [string]$DisplayName = "",
    [switch]$Force,
    [switch]$SkipProfile,
    [switch]$SkipHarnessInstall,
    [switch]$SkipHealthCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return (Resolve-Path -LiteralPath $Path).Path
    }
    return [System.IO.Path]::GetFullPath($Path)
}

function Convert-ToProjectId {
    param([string]$Name)
    $id = $Name.ToLowerInvariant() -replace '[^a-z0-9._-]+','-'
    $id = $id.Trim('-')
    if (-not $id) { return "client-project" }
    return $id
}

function Write-TextIfNeeded {
    param(
        [string]$Path,
        [string]$Content,
        [switch]$ForceWrite
    )
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if ((Test-Path -LiteralPath $Path) -and -not $ForceWrite) {
        Write-Output "  SKIP    $Path"
        return
    }
    $Content | Set-Content -LiteralPath $Path -Encoding utf8
    Write-Output "  WRITE   $Path"
}

function Copy-FileIfNeeded {
    param(
        [string]$Source,
        [string]$Target,
        [switch]$ForceCopy
    )
    if (-not (Test-Path -LiteralPath $Source)) {
        throw "Template source not found: $Source"
    }
    $parent = Split-Path -Parent $Target
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if ((Test-Path -LiteralPath $Target) -and -not $ForceCopy) {
        Write-Output "  SKIP    $Target"
        return
    }
    Copy-Item -LiteralPath $Source -Destination $Target -Force:$ForceCopy
    Write-Output "  COPY    $Target"
}

if (-not $ControlPlaneRepo) {
    $ControlPlaneRepo = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
}

$ControlPlaneRepo = Resolve-FullPath $ControlPlaneRepo
$ClientRoot = Resolve-FullPath $ClientRoot

if (-not (Test-Path -LiteralPath $ClientRoot)) {
    throw "ClientRoot not found: $ClientRoot"
}
if (-not (Test-Path -LiteralPath $ControlPlaneRepo)) {
    throw "ControlPlaneRepo not found: $ControlPlaneRepo"
}

$projectName = Split-Path -Leaf $ClientRoot
if (-not $ProjectId) { $ProjectId = Convert-ToProjectId $projectName }
if (-not $DisplayName) { $DisplayName = $projectName }

$bootstrapDir = Join-Path $ControlPlaneRepo "templates\project-bootstrap"
$adapterTemplateDir = Join-Path $ControlPlaneRepo "templates\project-adapter"
if (-not (Test-Path -LiteralPath $bootstrapDir)) { throw "Missing bootstrap template: $bootstrapDir" }
if (-not (Test-Path -LiteralPath $adapterTemplateDir)) { throw "Missing adapter template: $adapterTemplateDir" }

Write-Output ""
Write-Output "[attach-project] ClientRoot       : $ClientRoot"
Write-Output "[attach-project] ControlPlaneRepo : $ControlPlaneRepo"
Write-Output "[attach-project] Profile          : $Profile"
Write-Output "[attach-project] Tier             : $Tier"
Write-Output ""

Push-Location $ClientRoot
try {
    New-Item -ItemType Directory -Path ".control-plane", ".agents" -Force | Out-Null

    Write-Output "Project discovery files:"
    foreach ($name in @("AGENTS.md","AI_BOOTSTRAP.md","ACTIVE_CONTEXT.md")) {
        Copy-FileIfNeeded `
            -Source (Join-Path $bootstrapDir $name) `
            -Target (Join-Path $ClientRoot $name) `
            -ForceCopy:$Force
    }

    $projectStatus = @"
# Project Status

Project: $DisplayName
Project ID: $ProjectId
AI Control Plane: $ControlPlaneRepo
Attach tier: $Tier
Attached: $(Get-Date -Format 'yyyy-MM-dd')

## Current State

- TODO: describe the project goal.
- TODO: describe what is currently working.
- TODO: describe what must not be changed without explicit approval.

## Verification

- TODO: record the install/test/build commands for this project.

## AI Working Constraints

- Read `AGENTS.md` and `AI_BOOTSTRAP.md` at session start.
- Load shared ai-control-plane protocols only when the current task needs them.
- Keep project-specific state in this repo, not in the shared control plane.
"@
    Write-TextIfNeeded -Path (Join-Path $ClientRoot "PROJECT_STATUS.md") -Content $projectStatus -ForceWrite:$Force

    $claude = @"
@AGENTS.md
@AI_BOOTSTRAP.md

## Claude Code

- Treat `AGENTS.md` and `AI_BOOTSTRAP.md` as this project's instruction entrypoint.
- Cross-tool lessons registry (global canon): `$ControlPlaneRepo\docs\cross-tool-lessons.md` — read it before governed or destructive work (L1 commit sequence, L2 history-before-repair, U4 pre-deletion gate).
- Load shared ai-control-plane protocols only when routed by local project files.
- Do not assume the whole sibling control plane is automatically in context.
"@
    Write-TextIfNeeded -Path (Join-Path $ClientRoot "CLAUDE.md") -Content $claude -ForceWrite:$Force

    if ($Tier -eq "standard") {
        foreach ($name in @("HANDOVER.md","NODE_QUEUE.md","PROJECT_GOVERNANCE_TIERS.md","SETUP_CHECKLIST.md")) {
            Copy-FileIfNeeded `
                -Source (Join-Path $bootstrapDir $name) `
                -Target (Join-Path $ClientRoot $name) `
                -ForceCopy:$Force
        }
        $govSource = Join-Path $bootstrapDir "governance"
        $govTarget = Join-Path $ClientRoot "governance"
        if ((Test-Path -LiteralPath $govTarget) -and -not $Force) {
            Write-Output "  SKIP    $govTarget"
        } else {
            Copy-Item -Recurse -LiteralPath $govSource -Destination $govTarget -Force:$Force
            Write-Output "  COPY    $govTarget"
        }
    }

    Write-Output ""
    Write-Output "Control plane adapter files:"

    $adapter = [ordered]@{
        adapterId = $ProjectId
        project = $ProjectId
        displayName = $DisplayName
        mode = "client"
        controlPlaneRepo = $ControlPlaneRepo
        sharedAdapterPath = "adapters/generic/adapter.json"
        canonicalSources = @("README.md","PROJECT_STATUS.md","AGENTS.md","AI_BOOTSTRAP.md")
        ownershipFile = ".agents/ACTIVE_EDIT_OWNERSHIP.md"
        sessionLog = ".agents/session_log.jsonl"
        effectivenessLog = ".agents/effectiveness_log.jsonl"
    }
    $adapter | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath ".control-plane\adapter.json" -Encoding utf8
    Write-Output "  WRITE   .control-plane\adapter.json"

    $protected = @("AGENTS.md","AI_BOOTSTRAP.md","PROJECT_STATUS.md",".control-plane/protected-paths.json")
    if ($Tier -eq "standard") {
        $protected += @("HANDOVER.md","NODE_QUEUE.md","governance/")
    }
    if ($Profile -eq "claude-code" -and -not $SkipHarnessInstall) {
        # P3 (cross-repo findings 2026-08-17): the enforcement registration itself
        # (hook registry, hook wrappers, commit-time backstop) must be write-guarded,
        # or an agent can rewrite its own enforcement.
        $protected += @(
            ".claude/settings.local.json",
            ".control-plane/",
            ".control-plane/hooks/",
            ".control-plane/adapter.json",
            ".control-plane/resolve-control-plane.ps1",
            ".git/hooks/"
        )
    }
    [ordered]@{
        protectedPaths = $protected
        notes = @("$DisplayName protected paths generated by attach-project.ps1")
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath ".control-plane\protected-paths.json" -Encoding utf8
    Write-Output "  WRITE   .control-plane\protected-paths.json"

    $ownership = @"
# Active Edit Ownership

## Current Ownership
None.

## History
"@
    Write-TextIfNeeded -Path (Join-Path $ClientRoot ".agents\ACTIVE_EDIT_OWNERSHIP.md") -Content $ownership -ForceWrite:$Force
    if (-not (Test-Path -LiteralPath ".agents\session_log.jsonl")) {
        New-Item -ItemType File -Path ".agents\session_log.jsonl" -Force | Out-Null
        Write-Output "  WRITE   .agents\session_log.jsonl"
    } else {
        Write-Output "  SKIP    .agents\session_log.jsonl"
    }
    if (-not (Test-Path -LiteralPath ".agents\effectiveness_log.jsonl")) {
        New-Item -ItemType File -Path ".agents\effectiveness_log.jsonl" -Force | Out-Null
        Write-Output "  WRITE   .agents\effectiveness_log.jsonl"
    } else {
        Write-Output "  SKIP    .agents\effectiveness_log.jsonl"
    }

    if (-not $SkipProfile) {
        Write-Output ""
        Write-Output "Applying profile guidance:"
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "installers\install-profile.ps1") `
            -ClientRoot $ClientRoot `
            -Profile $Profile `
            -ControlPlaneRepo $ControlPlaneRepo
        if ($LASTEXITCODE -ne 0) { throw "install-profile failed with exit $LASTEXITCODE" }
    }

    if (-not $SkipHarnessInstall -and $Profile -eq "claude-code") {
        Write-Output ""
        Write-Output "Installing Claude Code harness:"
        if (-not (Test-Path -LiteralPath ".git")) {
            Write-Output "  .git not found - running git init for Claude Code hook installation."
            & git init | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "git init failed with exit $LASTEXITCODE" }
        }

        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "installers\install-claude-client.ps1") `
            -RepoRoot $ClientRoot `
            -AdapterDir ".control-plane"
        if ($LASTEXITCODE -ne 0) { throw "install-claude-client failed with exit $LASTEXITCODE" }

        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "installers\sync-shared-skills.ps1") `
            -RepoRoot $ClientRoot `
            -AdapterDir ".control-plane" `
            -SkillsDir ".agents/skills"
        if ($LASTEXITCODE -ne 0) { throw "sync-shared-skills failed with exit $LASTEXITCODE" }
    } elseif (-not $SkipHarnessInstall -and $Profile -ne "claude-code") {
        Write-Output ""
        Write-Output "Harness install: profile '$Profile' has no verified automatic hook installer; discovery files are attached."
    }

    if (-not $SkipHealthCheck) {
        Write-Output ""
        Write-Output "Running attach health check:"
        if ($Profile -eq "claude-code" -and -not $SkipHarnessInstall) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "installers\health-check.ps1") `
                -RepoRoot $ClientRoot `
                -AdapterDir ".control-plane" `
                -Quiet
            if ($LASTEXITCODE -ne 0) { throw "health-check failed with exit $LASTEXITCODE" }
        } else {
            & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ControlPlaneRepo "scripts\check-attach-health.ps1") `
                -ClientRoot $ClientRoot `
                -ControlPlaneRepo $ControlPlaneRepo
            if ($LASTEXITCODE -ne 0) { throw "check-attach-health failed with exit $LASTEXITCODE" }
        }
    }

    Write-Output ""
    Write-Output "attach-project: PASS"
    Write-Output "Client '$DisplayName' is attached to ai-control-plane."
} finally {
    Pop-Location
}
