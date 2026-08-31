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
# The registry entry alone only makes the font persist for the NEXT logon -
# it does not load into the CURRENT session's font table. AddFontResource
# registers each file for this session immediately; without it, no amount of
# restarting an app will make the font visible until you log off and back on.
Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[DllImport("gdi32.dll", CharSet = CharSet.Auto)]
public static extern int AddFontResource(string lpFileName);
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
Get-ChildItem "$fontsDir\*.ttf" | ForEach-Object {
  [Win32.NativeMethods]::AddFontResource($_.FullName) | Out-Null
}
$result = [UIntPtr]::Zero
[Win32.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x001D, [UIntPtr]::Zero, $null, 2, 3000, [ref]$result) | Out-Null
Write-Host "    Hack Nerd Font installed and loaded for this session - fully restart WezTerm (not just reload) to see it."

Write-Host "==> Step 3: modern PSReadLine (the in-box 2.0.0 predates prediction/ghost-text entirely)"
$psrlVersion = (Get-Module PSReadLine -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
if (-not $psrlVersion -or $psrlVersion -lt [Version]'2.2.0') {
  # Install-Module hangs non-interactively the first time it needs to trust
  # PSGallery or bootstrap the NuGet provider, even with -Force. Downloading
  # the .nupkg directly and unpacking it sidesteps that prompt entirely.
  #
  # $HOME\Documents is NOT necessarily the real Documents folder: OneDrive's
  # Known Folder Move redirects the special folder elsewhere while leaving a
  # stale $HOME\Documents on disk, so anything installed there silently goes
  # unnoticed. GetFolderPath resolves the real, current redirect target.
  $docs = [Environment]::GetFolderPath('MyDocuments')
  $nupkg = "$env:TEMP\psreadline.nupkg.zip"
  $extract = "$env:TEMP\psreadline_extract"
  Invoke-WebRequest -Uri 'https://www.powershellgallery.com/api/v2/package/PSReadLine' -OutFile $nupkg
  Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
  Expand-Archive -Path $nupkg -DestinationPath $extract -Force
  [xml]$nuspec = Get-Content (Get-ChildItem "$extract\*.nuspec" | Select-Object -First 1).FullName
  $version = $nuspec.package.metadata.version
  $destModuleDir = "$docs\WindowsPowerShell\Modules\PSReadLine\$version"
  New-Item -ItemType Directory -Force -Path $destModuleDir | Out-Null
  Get-ChildItem $extract -Exclude '_rels', 'package', '[Content_Types].xml', '*.nuspec' | ForEach-Object {
    Copy-Item $_.FullName -Destination $destModuleDir -Recurse -Force
  }
  Remove-Item $nupkg, $extract -Recurse -Force
  Write-Host "    Installed PSReadLine $version to $destModuleDir"
} else {
  Write-Host "    PSReadLine $psrlVersion already current enough"
}

Write-Host "==> Step 4: XDG_CONFIG_HOME (so Neovim reads ~\.config\nvim like the Mac setup)"
# Neovim on Windows defaults to %LOCALAPPDATA%\nvim unless this is set.
# WezTerm and herdr resolve their own config paths and don't need this.
[Environment]::SetEnvironmentVariable('XDG_CONFIG_HOME', "$HOME\.config", 'User')
$env:XDG_CONFIG_HOME = "$HOME\.config"

Write-Host "==> Step 5: apply config files"
& (Join-Path $PSScriptRoot 'rebuild.ps1')

Write-Host "==> Done. Open a new terminal so PATH, XDG_CONFIG_HOME, and the profile take effect."
