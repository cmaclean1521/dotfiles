# Windows equivalent of home.nix's programs.zsh block.
# The repo copy here is the source of truth; rebuild.ps1 copies it to $PROFILE.

$env:EDITOR = 'nvim'
$env:STARSHIP_CONFIG = "$HOME\.config\starship.toml"

foreach ($dir in @("$HOME\.local\bin", "$HOME\.opencode\bin")) {
  if ((Test-Path $dir) -and ($env:PATH -notlike "*$dir*")) {
    $env:PATH = "$dir;$env:PATH"
  }
}

# Ghost-text history suggestions, closest Windows equivalent to zsh autosuggestions.
Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView
Set-PSReadLineOption -Colors @{ InlineSuggestion = '#5c6370' }
# Mirrors home.nix's bindkey '^f' autosuggest-accept: ForwardChar accepts the
# suggestion when the cursor is already at the end of the line (same as RightArrow).
Set-PSReadLineKeyHandler -Chord 'Ctrl+f' -Function ForwardChar

function .. { Set-Location .. }
function add { git add . }
function push { git push }
function pull { git pull }
function m { git switch main }
# Ported from the Mac config's cc/co shortcuts, minus the auto-skip-permissions
# flag (dropped deliberately for this machine - see windows/README.md).
function cc { claude @args }
function co { codex --full-auto @args }

if (Get-Command starship -ErrorAction SilentlyContinue) {
  Invoke-Expression (&starship init powershell)
}
