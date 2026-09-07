param(
  [string]$ToolInputJson = "",
  [string]$ProtectedPathsFile = ""
)

# PreToolUse Write|Edit hook.
# Blocks writes to protected paths without an explicit session token.
# Each client repo can supply its own protected-path list.
#
# HOOK MODE: COMMAND_EXIT_MODE (exit 2 = block). NOT JSON permissionDecision mode.
# KNOWN LIMITATION: PreToolUse hooks do NOT fire in Claude Code Agent SDK / harness mode.
# This hook only executes reliably in interactive Claude Code CLI sessions.
# Commit-time backstop (git pre-commit hook) remains the primary enforcement layer.

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ToolInputJson)) {
  try {
    $ToolInputJson = [Console]::In.ReadToEnd()
  } catch {
    [Console]::Error.WriteLine("[SECURITY BLOCKED] Failed to read stdin in check_write_target: $_")
    exit 2
  }
}

if ([string]::IsNullOrWhiteSpace($ToolInputJson)) {
  [Console]::Error.WriteLine("[SECURITY BLOCKED] Empty payload received in check_write_target (Fail-Closed)")
  exit 2
}

$ToolInputJson = $ToolInputJson.TrimStart([char]0xFEFF)

$filePath = ""
try {
  $parsed = $ToolInputJson | ConvertFrom-Json
  if ($null -ne $parsed.tool_input -and -not [string]::IsNullOrWhiteSpace($parsed.tool_input.file_path)) {
    $filePath = $parsed.tool_input.file_path
  } elseif (-not [string]::IsNullOrWhiteSpace($parsed.file_path)) {
    $filePath = $parsed.file_path
  } elseif (-not [string]::IsNullOrWhiteSpace($parsed.path)) {
    $filePath = $parsed.path
  }
} catch {
  [Console]::Error.WriteLine("[SECURITY BLOCKED] JSON payload parse failure in check_write_target: $_ (Fail-Closed)")
  exit 2
}

if ([string]::IsNullOrWhiteSpace($filePath)) {
  [Console]::Error.WriteLine("[SECURITY BLOCKED] Missing file_path in tool input (Fail-Closed)")
  exit 2
}

$filePath = $filePath -replace '\\', '/'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($ProtectedPathsFile)) {
  $ProtectedPathsFile = Join-Path $scriptDir "protected-paths.txt"
}

$protected = @()
if (Test-Path $ProtectedPathsFile) {
  if ($ProtectedPathsFile.EndsWith(".json")) {
    try {
      $config = Get-Content $ProtectedPathsFile -Raw | ConvertFrom-Json
      if ($null -ne $config.protectedPaths) {
        $protected = @($config.protectedPaths)
      }
    } catch {
      $protected = @()
    }
  } else {
    $protected = Get-Content $ProtectedPathsFile |
      Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
      ForEach-Object { $_.Trim() } |
      Where-Object { -not $_.StartsWith("#") }
  }
}

if ($protected.Count -eq 0) {
  $protected = @(
    "governance/",
    "AGENTS.md",
    "AI_BOOTSTRAP.md"
  )
}

foreach ($pattern in $protected) {
  if ($filePath -match [regex]::Escape($pattern)) {
    # Write-Error with Stop preference throws before exit 2 — use Console.Error to write and let exit 2 reach Claude Code as explicit deny.
    [Console]::Error.WriteLine("BLOCKED: '$filePath' matches protected path '$pattern'. There is no self-service bypass for this hook — get explicit user approval and have the user run the commit step themselves; this PreToolUse hook does not honor any environment variable.")
    exit 2
  }
}

exit 0