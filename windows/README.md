# Windows setup

The Windows counterpart to the Mac setup described in the root [README.md](../README.md).
Same tools and configs where possible; a different mechanism underneath, because Nix's
Windows story doesn't cover this.

## Why this isn't just home.nix again

`flake.nix`, `configuration.nix`, and `home.nix` depend on nix-darwin and Homebrew, both
macOS-only. Nix itself doesn't target Windows outside WSL2, and WezTerm - the terminal this
setup is built around - has to run as a native Windows app either way. Recreating the Nix
layer inside WSL2 would still leave WezTerm's config unmanaged by it, so this uses winget
and plain PowerShell scripts instead: same result, no added machinery for a platform Nix
doesn't reach.

## What you get

Running `bootstrap.ps1` sets up:

- CLI tools via winget: fd, fzf, jq, lazygit, Neovim, WezTerm, Starship, herdr
- Hack Nerd Font, installed per-user (no admin required)
- Shell: PowerShell profile with PSReadLine history suggestions and the same aliases as
  the Mac's zsh config
- Editor: the same Neovim config as the Mac (`home/.config/nvim` - already
  cross-platform, unchanged)
- Terminal: the same WezTerm config as the Mac (`home/.config/wezterm` - already
  cross-platform, unchanged)
- Agent configs: Claude, Codex, and opencode all read from one shared `home/AGENTS.md`
- herdr, for the same tmux-like pane workflow as the Mac's `home/.config/herdr`

## Fresh-machine setup

```powershell
git clone https://github.com/cmaclean1521/dotfiles.git ~\dotfiles
cd ~\dotfiles
.\windows\bootstrap.ps1
```

## Daily use

Edit files under `home\.config`, `home\AGENTS.md`, or `windows\`, then:

```powershell
.\windows\rebuild.ps1
```

## How this differs from the Mac setup

**No symlinks, so no instant edit-in-place.** The Mac setup uses `mkOutOfStoreSymlink` so
editing a file in the repo changes the live config immediately. This machine has no
unprivileged symlink permission (tested during setup: `New-Item -ItemType SymbolicLink`
fails without admin or Developer Mode), so `rebuild.ps1` copies files into place instead.
Edit the repo copy, then run `rebuild.ps1` - one extra step versus the Mac.

**No Homebrew cleanup / no macOS system defaults.** `configuration.nix`'s
`homebrew.onActivation.cleanup = "zap"` and its `system.defaults` block (dark mode, key
repeat, Dock, Finder, trackpad) are macOS-specific and have no equivalent here. Nothing
on this machine gets removed for not being declared in a package list.

**`~\.claude\settings.json` is never silently overwritten.** Unlike the fully-managed
`home/.config` tree, this file already held hand-tuned settings (deny/ask permission
rules, a hook, a custom statusline) before this setup existed. `rebuild.ps1` only writes
it if it's missing; if it already exists, it prints a reminder to diff it against
`windows\.claude\settings.json` by hand instead of overwriting your customizations.

**herdr is on the preview channel.** Windows support is beta upstream: local persistent
sessions and panes work over PowerShell, but Windows can't act as a `--remote` target
host yet, and plugins are in preview. `bootstrap.ps1` installs the winget package
published by Herdr, Inc. itself (`Herdr.Herdr.Preview`) rather than one of the
unofficial/community-published winget listings that also show up in `winget search herdr`.
herdr's config path is Windows-specific too: `%APPDATA%\herdr\config.toml`, not
`~\.config\herdr` (herdr doesn't read `XDG_CONFIG_HOME` on Windows).

**`XDG_CONFIG_HOME` is set explicitly.** Neovim on Windows defaults to
`%LOCALAPPDATA%\nvim` and ignores `~\.config` unless this is set. `bootstrap.ps1` sets it
once, persistently, to `~\.config`, so Neovim (and any other XDG-aware tool you add
later) resolves the same way it does on the Mac. WezTerm doesn't need this - it checks
`~\.config\wezterm\wezterm.lua` directly on every platform.

**If `rebuild.ps1` can't write the PowerShell profile:** Windows Defender's
Controlled Folder Access (ransomware protection) protects Documents by default, and the
PowerShell profile (`$PROFILE`) lives there. If it's enabled (check with
`Get-MpPreference | Select EnableControlledFolderAccess`), scripts silently can't create
files in Documents - `rebuild.ps1` catches this and prints the exact source/destination
path so you can copy the file yourself in File Explorer (which is allowed by default).
This isn't specific to this repo; it'll block any script writing to Documents.

**`cc`/`co` shortcuts differ.** The Mac aliases are `cc='claude --dangerously-skip-permissions'`
and `co='codex --full-auto'`. This machine's PowerShell profile drops
`--dangerously-skip-permissions` from `cc` (a deliberate choice made when porting this
setup, not a technical limitation) - `cc` here is a plain `claude` shortcut, and `co`
keeps `--full-auto`. Your Windows `~\.claude\settings.json` also keeps its existing
`defaultMode: "auto"` with its deny/ask rules, rather than adopting the Mac config's
`bypassPermissions` default.

**Not ported:** macOS system defaults (dark mode, Dock, Finder, trackpad) and the
Homebrew `zap` cleanup policy - both meaningless on Windows. Git identity is untouched
here for the same reason the Mac README leaves it alone: it was already configured.
