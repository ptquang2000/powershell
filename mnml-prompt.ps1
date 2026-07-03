# =============================================================================
#  mnml-prompt.ps1 -- native mnml-style prompt, dot-sourced by the profile.
#  Owns its own glyph/color defaults (like zsh's minimal.zsh-theme). PSReadLine
#  wiring for the vi-mode indicator (-ViModeChangeHandler) is configured in the
#  profile; it just updates $script:PromptViMode below.
# -----------------------------------------------------------------------------
#  Mirrors the zsh `mnml` theme, flattened to one left-aligned line (PowerShell
#  has no native right-prompt, so mnml's RPROMPT cwd+git moves inline).
#
#  Layout:  [ssh-host] [venv] <cwd> [git-branch] <status-glyph><vi-mode-char>
#    * cwd         last 2 path segments, gray dirs / white separators, ~ for $HOME
#    * git-branch  read straight from .git/HEAD (no git spawn); no dirty state,
#                  since that would need a full worktree scan
#    * status      user glyph, green on success / red on failure, blue if bg job
#    * vi-mode     the '.' glyph in vi command mode, nothing in insert mode
# =============================================================================

# theme defaults (self-contained, mirroring mnml's MNML_* defaults).
# Glyph is a Nerd Font (Material Design Icons) PUA codepoint. Astral chars
# (surrogate pairs) render fine here; ConvertFromUtf32 handles the encoding.
$script:PromptGlyphUser   = [char]::ConvertFromUtf32(0xF0B5F)  # nf-md glyph U+F0B5F
$script:PromptGlyphNormal = [char]0x00B7                       # middle dot
$script:PromptViMode      = 'Insert'                           # updated by the profile's ViModeChangeHandler

function prompt {
    $ok  = $?              # capture last command's success FIRST, before anything clobbers it
    $lec = $LASTEXITCODE

    $e     = [char]27
    $reset = "$e[0m"
    # gruvbox-material (dark medium) palette, truecolor
    $gray    = "$e[38;2;146;131;116m"   # #928374
    $green   = "$e[38;2;169;182;101m"   # #a9b665
    $red     = "$e[38;2;234;105;98m"    # #ea6962
    $blue    = "$e[38;2;125;174;163m"   # #7daea3
    $magenta = "$e[38;2;211;134;155m"   # #d3869b  (purple)

    $sb = [System.Text.StringBuilder]::new()

    # ssh host (only over SSH)
    if ($env:SSH_CLIENT -or $env:SSH_TTY) {
        [void]$sb.Append("$gray$([System.Net.Dns]::GetHostName())$reset ")
    }

    # python virtualenv
    if ($env:VIRTUAL_ENV) {
        [void]$sb.Append("$gray$(Split-Path -Leaf $env:VIRTUAL_ENV)$reset ")
    }

    # cwd: last 2 segments, gray dirs, white separators, ~ for $HOME
    $path = $ExecutionContext.SessionState.Path.CurrentLocation.Path
    if ($path.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) {
        $path = '~' + $path.Substring($HOME.Length)
    }
    $segs = @($path -split '[\\/]+' | Where-Object { $_ -ne '' })
    if ($segs.Count -gt 2) { $segs = $segs[-2..-1] }
    [void]$sb.Append($gray + ($segs -join "$reset/$gray") + "$reset ")

    # git branch by reading .git/HEAD directly -- no process spawn. Walk up for
    # .git (a dir normally, a "gitdir: <path>" file in submodules/worktrees),
    # then parse HEAD: "ref: refs/heads/<branch>" or a detached commit SHA.
    $dir = $path -replace '^~', $HOME
    while ($dir -and (Test-Path -LiteralPath $dir -PathType Container)) {
        $dotgit = Join-Path $dir '.git'
        if (Test-Path -LiteralPath $dotgit) {
            $gitDir = if (Test-Path -LiteralPath $dotgit -PathType Container) {
                $dotgit
            } else {
                $ptr = (Get-Content -LiteralPath $dotgit -TotalCount 1) -replace '^gitdir:\s*'
                if ([System.IO.Path]::IsPathRooted($ptr)) { $ptr } else { Join-Path $dir $ptr }
            }
            $head = Join-Path $gitDir 'HEAD'
            if (Test-Path -LiteralPath $head) {
                $h = Get-Content -LiteralPath $head -TotalCount 1
                $branch = if ($h -match '^ref:\s*refs/heads/(.+)$') { $Matches[1] }
                          elseif ($h) { $h.Substring(0, [Math]::Min(7, $h.Length)) }
                if ($branch) { [void]$sb.Append("$magenta$branch$reset ") }
            }
            break
        }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }

    # status glyph (exit code / bg jobs) + vi-mode keymap glyph
    $scol = if ($ok -and ($null -eq $lec -or $lec -eq 0)) { $green } else { $red }
    if (@(Get-Job -State Running -ErrorAction SilentlyContinue).Count -gt 0) { $scol = $blue }
    [void]$sb.Append("$scol$script:PromptGlyphUser$reset")
    if ($script:PromptViMode -eq 'Command') {
        [void]$sb.Append("$gray$script:PromptGlyphNormal$reset")
    }
    [void]$sb.Append(' ')

    $global:LASTEXITCODE = $lec   # our git calls must not clobber the real exit code
    $sb.ToString()
}
