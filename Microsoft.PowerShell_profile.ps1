# =============================================================================
#  Microsoft.PowerShell_profile.ps1
# -----------------------------------------------------------------------------
#  Interactive pwsh profile ("the .zshrc"): holds all configuration -- PSReadLine
#  options + key bindings, PATH/PATHEXT, env vars, aliases -- and dot-sources the
#  native mnml prompt (mnml-prompt.ps1, next to this file).
#
#  Load order:
#    1. Helper functions
#    2. PSReadLine -- native equivalents of the zsh plugins & bindkeys
#    3. PATH & PATHEXT
#    4. Aliases
#    5. Local overrides (dot-source git-ignored env.ps1 if present)
#    6. Prompt (dot-source mnml-prompt.ps1 + vi-mode wiring)
# =============================================================================

#region 1. Helpers
function Add-PathEntry {
    <#
    .SYNOPSIS
        Append (or prepend) a directory to $env:Path with dedup + existence checks.
        Skips empty/whitespace input and non-existent dirs (unless -Force).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyString()][AllowNull()]
        [string]$Path,
        [switch]$Prepend,
        [switch]$Force
    )
    process {
        if ([string]::IsNullOrWhiteSpace($Path)) { return }
        if (-not $Force -and -not (Test-Path -LiteralPath $Path -PathType Container)) { return }

        foreach ($e in ($env:Path -split ';')) {
            if ([string]::Equals($e.TrimEnd('\'), $Path.TrimEnd('\'), [System.StringComparison]::OrdinalIgnoreCase)) {
                return
            }
        }
        $env:Path = if ($Prepend) { "$Path;$env:Path" } else { "$($env:Path.TrimEnd(';'));$Path" }
    }
}
#endregion

#region 2. PSReadLine -- native equivalents of the zsh plugins + bindkeys
Set-PSReadLineOption -HistorySaveStyle SaveNothing
Set-PSReadLineOption -MaximumHistoryCount 10000
Set-PSReadLineOption -HistoryNoDuplicates                    # hist_ignore_dups
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -AddToHistoryHandler { param($line) $line -notmatch '^\s' }  # hist_ignore_space

# inline autosuggestions from history (native -- no external predictor module)
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineOption -ShowToolTips
Set-PSReadLineOption -CompletionQueryItems 65
Set-PSReadLineOption -ExtraPromptLineCount 1

# syntax highlighting: color tokens as you type
# gruvbox-material (dark medium) palette, truecolor
Set-PSReadLineOption -Colors @{
    Command          = "$([char]27)[38;2;137;180;130m" # aqua    #89b482
    Parameter        = "$([char]27)[38;2;212;190;152m" # fg      #d4be98
    Operator         = "$([char]27)[38;2;231;138;78m"  # orange  #e78a4e
    String           = "$([char]27)[38;2;169;182;101m" # green   #a9b665
    Number           = "$([char]27)[38;2;211;134;155m" # purple  #d3869b
    Variable         = "$([char]27)[38;2;125;174;163m" # blue    #7daea3
    Comment          = "$([char]27)[38;2;146;131;116m" # gray    #928374
    Keyword          = "$([char]27)[38;2;234;105;98m"  # red     #ea6962
    Type             = "$([char]27)[38;2;216;166;87m"  # yellow  #d8a657
    Error            = "$([char]27)[38;2;234;105;98m"  # red     #ea6962
    InlinePrediction = "$([char]27)[38;2;124;111;100m" # bg4     #7c6f64  (dim ghost)
}

# key bindings (mirror of the zsh `bindkey` block)
Set-PSReadLineKeyHandler -Chord UpArrow         -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Chord DownArrow       -Function HistorySearchForward
Set-PSReadLineKeyHandler -Chord Ctrl+Spacebar   -Function AcceptSuggestion       # bindkey "^ "
Set-PSReadLineKeyHandler -Chord Tab             -Function MenuComplete           # bindkey "^I"
Set-PSReadLineKeyHandler -Chord Shift+Tab       -Function MenuComplete           # bindkey kcbt
Set-PSReadLineKeyHandler -Chord Ctrl+RightArrow -Function ForwardWord
Set-PSReadLineKeyHandler -Chord Ctrl+LeftArrow  -Function BackwardWord
Set-PSReadLineKeyHandler -Chord Ctrl+Backspace  -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord Ctrl+h          -Function BackwardDeleteWord     # bindkey "^H"
Set-PSReadLineKeyHandler -Chord Ctrl+Delete     -Function KillWord
Set-PSReadLineKeyHandler -Chord Ctrl+a          -Function BeginningOfLine        # bindkey "^A"
Set-PSReadLineKeyHandler -Chord Ctrl+e          -Function EndOfLine              # bindkey "^E"
Set-PSReadLineKeyHandler -Chord Home            -Function BeginningOfLine
Set-PSReadLineKeyHandler -Chord End             -Function EndOfLine

# Ctrl+F -> psmux-sessionizer (bindkey -s "^f")
$script:PsmuxSessionizer = Join-Path $PSScriptRoot 'psmux-sessionizer.ps1'
Set-PSReadLineKeyHandler -Key Ctrl+f -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("& '$script:PsmuxSessionizer'")
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}
#endregion

#region 3. PATH & PATHEXT
if ($env:PATHEXT -notlike '*.PY*') { $env:PATHEXT += ';.PY' }

# every subdir of ~\.local\bin (prefer <subdir>\bin if it exists)
$BIN_DIR = Join-Path $env:USERPROFILE '.local\bin'
if (Test-Path -LiteralPath $BIN_DIR -PathType Container) {
    foreach ($d in [System.IO.Directory]::GetDirectories($BIN_DIR)) {
        Add-PathEntry ([System.IO.Path]::Combine($d, 'bin'))
        Add-PathEntry $d
    }
}
Add-PathEntry $BIN_DIR
Add-PathEntry (Join-Path $env:USERPROFILE '.opencode\bin') -Prepend   # zsh: PATH=$HOME/.opencode/bin:$PATH
#endregion

#region 4. Aliases
# match zsh: alias clear='clear && printf "\e[3J"' -- also wipe the scrollback buffer.
# (aliases outrank functions in PowerShell, so override the built-in `clear` alias)
function Clear-Screen { Clear-Host; [Console]::Write("$([char]27)[3J") }
Set-Alias -Name clear -Value Clear-Screen -Scope Global -Force

#endregion

#region 5. Local overrides (git-ignored, machine-specific)
# env.ps1 holds per-machine secrets/paths and stays out of version control.
$LocalEnv = Join-Path $PSScriptRoot 'env.ps1'
if (Test-Path -LiteralPath $LocalEnv -PathType Leaf) { . $LocalEnv }
#endregion

#region 6. Prompt
. (Join-Path $PSScriptRoot 'mnml-prompt.ps1')

try {
    Set-PSReadLineOption -ViModeIndicator Script -ViModeChangeHandler {
        param([Microsoft.PowerShell.ViMode]$mode)
        $script:PromptViMode = if ($mode -eq 'Command') { 'Command' } else { 'Insert' }
    }
} catch {
    Write-Verbose "ViModeChangeHandler not set: $_"
}
#endregion
