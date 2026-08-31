# Re-applies this repo's config to the machine. Run this every time you edit
# a file under home\.config, home\AGENTS.md, windows\Microsoft.PowerShell_profile.ps1,
# or windows\.claude\settings.json.
#
# Windows can't create unprivileged symlinks (confirmed on this machine), so
# unlike the Mac setup's mkOutOfStoreSymlink edit-in-place model, this copies
# files into place. The repo is still the thing you edit - just re-run this
# script afterward instead of the change applying instantly.

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$HomeCfg = Join-Path $RepoRoot 'home\.config'

function Copy-Config($Src, $Dst) {
  $parent = Split-Path $Dst -Parent
  if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
  if (Test-Path $Src -PathType Container) {
    New-Item -ItemType Directory -Force -Path $Dst | Out-Null
    robocopy $Src $Dst /MIR /NFL /NDL /NJH /NJS | Out-Null
  } else {
    Copy-Item $Src $Dst -Force
  }
}

Write-Host "==> Neovim, WezTerm, Starship, herdr configs"
Copy-Config "$HomeCfg\nvim"              "$HOME\.config\nvim"
Copy-Config "$HomeCfg\wezterm"           "$HOME\.config\wezterm"
Copy-Config "$HomeCfg\starship.toml"     "$HOME\.config\starship.toml"
Copy-Config "$HomeCfg\herdr\config.toml" "$env:APPDATA\herdr\config.toml"

Write-Host "==> Agent policy (Claude, Codex, opencode share one AGENTS.md)"
$agents = Join-Path $RepoRoot 'home\AGENTS.md'
Copy-Config $agents "$HOME\.claude\CLAUDE.md"
Copy-Config $agents "$HOME\.codex\AGENTS.md"
Copy-Config $agents "$HOME\.config\opencode\AGENTS.md"

Write-Host "==> PowerShell profile"
Copy-Config (Join-Path $PSScriptRoot 'Microsoft.PowerShell_profile.ps1') $PROFILE

Write-Host "==> Claude Code settings"
$claudeSettings = "$HOME\.claude\settings.json"
$repoSettings = Join-Path $PSScriptRoot '.claude\settings.json'
if (Test-Path $claudeSettings) {
  Write-Host "    ~\.claude\settings.json already exists - not overwriting."
  Write-Host "    Diff it against windows\.claude\settings.json if you want to adopt changes by hand."
} else {
  Copy-Config $repoSettings $claudeSettings
}

Write-Host "==> Done. Open a new terminal to pick up the profile and PATH changes."
