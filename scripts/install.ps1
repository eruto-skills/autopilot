# Installs the autopilot skill into ~/.claude/skills/ on Windows.
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
  [switch]$Force   # if set, removes any existing entry at the target path before linking
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot                       # autopilot/ repo path
$skillsDir = Join-Path $env:USERPROFILE '.claude\skills'
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
  if ($Force) {
    Write-Host "removing existing entry: $linkPath"
    Remove-Item $linkPath -Recurse -Force
  } else {
    Write-Error "path exists and is not the expected junction: $linkPath`nRun with -Force to replace, or remove it manually."
    exit 1
  }
}

New-Item -ItemType Junction -Path $linkPath -Target $repoRoot | Out-Null
Write-Host "created junction: $linkPath -> $repoRoot"
exit 0
