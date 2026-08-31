# Takes a fresh Windows machine to this repo's configured dev environment.
# Run this once. After it finishes, use .\rebuild.ps1 for every later change.
#
# Windows-native equivalent of bootstrap.sh / flake.nix / home.nix: there is no
# Windows target for nix-darwin or home-manager, so this installs the same
# tools with winget and copies config into place instead of using Nix. See
# windows\README.md for what's different from the Mac setup and why.

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot

Write-Host "==> Step 1: winget packages"
# ripgrep assumed already installed; add BurntSushi.ripgrep.MSVC here if not.
$packages = @(
  'sharkdp.fd',
  'junegunn.fzf',
  'jqlang.jq',
  'JesseDuffield.lazygit',
  'Neovim.Neovim',
  'wez.wezterm',
  'Starship.Starship',
  'Herdr.Herdr.Preview'   # published by Herdr, Inc. - Windows support is preview-only as of writing
)
foreach ($pkg in $packages) {
  Write-Host "    installing $pkg"
  winget install --id $pkg --exact --silent --accept-source-agreements --accept-package-agreements
}

Write-Host "==> Step 2: Hack Nerd Font (per-user install, no admin needed)"
$fontUrl = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip'
$zipPath = "$env:TEMP\HackNerdFont.zip"
$extractPath = "$env:TEMP\HackNerdFont"
Invoke-WebRequest -Uri $fontUrl -OutFile $zipPath
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force
$fontsDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null
$regKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
Get-ChildItem "$extractPath\*.ttf" | ForEach-Object {
  Copy-Item $_.FullName -Destination $fontsDir -Force
  New-ItemProperty -Path $regKey -Name "$($_.BaseName) (TrueType)" -Value $_.Name -PropertyType String -Force | Out-Null
}
Remove-Item $zipPath, $extractPath -Recurse -Force
Write-Host "    Hack Nerd Font installed for this user - restart apps to see it."

Write-Host "==> Step 3: XDG_CONFIG_HOME (so Neovim reads ~\.config\nvim like the Mac setup)"
# Neovim on Windows defaults to %LOCALAPPDATA%\nvim unless this is set.
# WezTerm and herdr resolve their own config paths and don't need this.
[Environment]::SetEnvironmentVariable('XDG_CONFIG_HOME', "$HOME\.config", 'User')
$env:XDG_CONFIG_HOME = "$HOME\.config"

Write-Host "==> Step 4: apply config files"
& (Join-Path $PSScriptRoot 'rebuild.ps1')

Write-Host "==> Done. Open a new terminal so PATH, XDG_CONFIG_HOME, and the profile take effect."
