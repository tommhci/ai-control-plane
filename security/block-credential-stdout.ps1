#Requires -Version 5.1
# ============================================================
# block-credential-stdout.ps1
# AI Control Plane — Credential Stdout Guard
#
# PURPOSE:
#   Intercepts shell commands that output plaintext credentials
#   to stdout (where AI session context can capture them).
#
# INSTALL (once, into PowerShell profile):
#   Add these two lines to C:\Users\1\Documents\PowerShell\Microsoft.PowerShell_profile.ps1
#
#     . "C:\dev\ai-control-plane\security\block-credential-stdout.ps1"
#     Register-CredentialGuard
#
# WHAT IT BLOCKS (non-interactive / AI sessions — hard exit 1):
#   git credential fill
#   git credential-manager get
#   gh auth token
#   gh auth status --show-token
#
# WHAT IT ALLOWS:
#   Everything else — git, gh work normally.
#   Interactive human sessions: warns + requires explicit "YES".
#
# ESCAPE HATCH (document reason first):
#   $env:CREDENTIAL_GUARD_DISABLE = '1'   # current session only
#
# DETECTION METHOD:
#   Uses System.Console (IsInputRedirected/IsOutputRedirected) to 
#   reliably detect automated piping/AI context vs human TTY.
#
# HONEST SCOPE:
#   Does NOT block: cat ~/.netrc, $env:TOKEN, cat ~/.gitconfig
#   Those require human discipline. Extend $CREDENTIAL_BLOCKED_PATTERNS to add.
#
# EVIDENCE BASIS:
#   Tom Vault session 2026-09-07: git credential fill stdout captured
#   by AI context, token leaked. ADR-0005 §2.8 = text rule only.
#   This script = mechanical enforcement of that text rule.
# ============================================================

Set-StrictMode -Version Latest

$script:CREDENTIAL_BLOCKED_PATTERNS = @(
    '^git(\s+)credential(\s+)fill',
    '^git(\s+)credential-manager(\s+)get',
    '^gh(\s+)auth(\s+)token',
    '^gh(\s+)auth(\s+)status(.*)--show-token'
)

function Invoke-GuardedGit {
    param([Parameter(ValueFromRemainingArguments)][string[]]$GitArgs)

    $fullCmd = "git $($GitArgs -join ' ')"
    $blocked = $false
    foreach ($p in $script:CREDENTIAL_BLOCKED_PATTERNS) {
        if ($fullCmd -match $p) { $blocked = $true; break }
    }

    if (-not $blocked) {
        & git.exe @GitArgs
        return
    }

    if ($env:CREDENTIAL_GUARD_DISABLE -eq '1') {
        Write-Warning "[CREDENTIAL GUARD] Override active (CREDENTIAL_GUARD_DISABLE=1). Running: $fullCmd"
        & git.exe @GitArgs
        return
    }

    $isInteractive = -not ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected)

    if ($isInteractive) {
        Write-Warning @"

[CREDENTIAL GUARD] '$fullCmd' outputs PLAINTEXT credentials to stdout.
AI sessions can silently capture this and log or leak it.

Safe alternative — redirect to file, then delete:
  git credential fill > cred.tmp
  Remove-Item cred.tmp

"@
        $ans = Read-Host "Type YES to proceed as human (anything else = abort)"
        if ($ans -ne 'YES') {
            Write-Host "[CREDENTIAL GUARD] Aborted cleanly." -ForegroundColor Green
            return
        }
        Write-Warning "[CREDENTIAL GUARD] Human confirmed. Proceeding."
        & git.exe @GitArgs
    } else {
        # Non-interactive (AI/script context) — hard block
        Write-Error "[CREDENTIAL GUARD] BLOCKED '$fullCmd' — plaintext credential output forbidden in automated sessions. Redirect to file or set CREDENTIAL_GUARD_DISABLE=1 with ADR-0005 §2.8 documentation."
        exit 1
    }
}

function Invoke-GuardedGh {
    param([Parameter(ValueFromRemainingArguments)][string[]]$GhArgs)

    $fullCmd = "gh $($GhArgs -join ' ')"
    $blocked = $false
    foreach ($p in $script:CREDENTIAL_BLOCKED_PATTERNS) {
        if ($fullCmd -match $p) { $blocked = $true; break }
    }

    if (-not $blocked -or $env:CREDENTIAL_GUARD_DISABLE -eq '1') {
        & gh.exe @GhArgs
        return
    }

    Write-Error "[CREDENTIAL GUARD] BLOCKED: '$fullCmd' — plaintext token output forbidden. Use 'gh auth status' (no --show-token) to verify auth state."
    exit 1
}

function Register-CredentialGuard {
    <#
    .SYNOPSIS
    Installs the credential stdout guard into the current PowerShell session.
    Call from $PROFILE after dot-sourcing this file.

    NOTE: Uses 'function global:git' syntax (not Set-Alias) because PowerShell
    resolves Function entries before Application entries (git.exe), but Alias
    entries pointing to a function name fail when the function isn't in Global scope.
    Verified empirically: Set-Alias approach silently falls through to git.exe.
    #>
    if ($env:CREDENTIAL_GUARD_DISABLE -eq '1') {
        Write-Warning "[CREDENTIAL GUARD] Skipping registration — CREDENTIAL_GUARD_DISABLE=1 is set."
        return
    }

    # Define global functions that shadow git.exe and gh.exe
    # These take precedence over Application entries in PS command resolution.
    $gitBlock = [scriptblock]::Create('Invoke-GuardedGit @args')
    $ghBlock  = [scriptblock]::Create('Invoke-GuardedGh  @args')

    New-Item -Path Function:Global:git -Value $gitBlock -Force | Out-Null
    New-Item -Path Function:Global:gh  -Value $ghBlock  -Force | Out-Null

    # Verify registration worked
    $gitCmd = Get-Command git -CommandType Function -ErrorAction SilentlyContinue
    if ($gitCmd) {
        Write-Host "[CREDENTIAL GUARD] Active — plaintext credential commands are intercepted." -ForegroundColor Cyan
    } else {
        Write-Warning "[CREDENTIAL GUARD] WARNING: function registration failed. Guard is NOT active."
    }
}

function Disable-CredentialGuard {
    <#
    .SYNOPSIS
    Disables the guard for this session. Document reason in ADR-0005 §2.8 first.
    #>
    $env:CREDENTIAL_GUARD_DISABLE = '1'
    Remove-Item -Path Function:Global:git -ErrorAction SilentlyContinue
    Remove-Item -Path Function:Global:gh  -ErrorAction SilentlyContinue
    Write-Warning "[CREDENTIAL GUARD] DISABLED for this session. Document reason in ADR-0005 §2.8."
}
