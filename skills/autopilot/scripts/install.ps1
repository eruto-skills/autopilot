# Installs autopilot on Windows. Use -HostName codex for ~/.agents/skills/.
# Idempotent: re-running on an already-linked path is safe.
#
# Manual equivalent (if you can't run this script):
#   New-Item -ItemType Junction `
#     -Path  "$env:USERPROFILE\.claude\skills\autopilot" `
#     -Target (Split-Path -Parent $PSScriptRoot)
#
# Why a Junction instead of SymbolicLink: Junctions work without admin rights
# or Developer Mode. They're directory-only, same-volume — both fine here.

[CmdletBinding()]
param(
  [ValidateSet('claude', 'codex')]
  [string]$HostName = 'claude',
  [switch]$Force   # if set, replaces an existing junction only; real directories are preserved
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot                       # autopilot/ repo path
$hostDir = if ($HostName -eq 'codex') { '.agents' } else { '.claude' }
$skillsDir = Join-Path $env:USERPROFILE ($hostDir + '/skills')
$linkPath = Join-Path $skillsDir 'autopilot'

if (-not (Test-Path $skillsDir)) {
  New-Item -ItemType Directory -Path $skillsDir | Out-Null
}

if (Test-Path $linkPath) {
  $existing = Get-Item $linkPath -Force
  if ($existing.LinkType -eq 'Junction' -and $existing.Target -contains $repoRoot) {
    Write-Host "already linked: $linkPath -> $repoRoot"
    exit 0
  }
  if ($Force -and $existing.LinkType -eq 'Junction') {
    Write-Host "removing existing entry: $linkPath"
    Remove-Item -LiteralPath $linkPath -Force
  } else {
    Write-Error "path exists and is not the expected junction: $linkPath`nRun with -Force to replace, or remove it manually."
    exit 1
  }
}

New-Item -ItemType Junction -Path $linkPath -Target $repoRoot | Out-Null
Write-Host "created junction: $linkPath -> $repoRoot"
exit 0
