#!/usr/bin/env pwsh
# psmux-sessionizer - tmux-sessionizer for psmux on Windows
# Usage: psmux-sessionizer [path]
# If no path given, uses fzf to pick from existing sessions + directories.
# Works both outside and inside a psmux session.

param([string]$selected)

$searchPaths = @(
    "$env:USERPROFILE",
    "$env:USERPROFILE\work",
    "$env:USERPROFILE\personal"
)
$session = $env:PSMUX_SESSION
$wasInside = [bool]($env:PSMUX_SESSION -or $env:TMUX)

if (-not $selected) {
    $selected = @(
        psmux list-sessions 2>$null |
            ForEach-Object { ($_ -split ':')[0] } |
            Where-Object { $_ -and $_ -ne $session } |
            ForEach-Object { "[PSMUX] $_" }
        Get-ChildItem -Path $searchPaths -Directory -ErrorAction SilentlyContinue |
            Where-Object Name -ne '.git' | ForEach-Object { $_.FullName }
    ) | fzf
}

if (-not $selected) { exit 0 }

if ($selected -match '^\[PSMUX\]\s+(.+)$') {
    $name = $Matches[1].Trim()
} else {
    $dirName = Split-Path $selected -Leaf
    $name = $dirName -replace '\.', '_'
}

# psmux's nesting guard silently no-ops new-session and attach when
# PSMUX_SESSION is set. Clear it for those calls; switch-client is unaffected.
$env:PSMUX_SESSION = $null
try {
    psmux has-session -t $name 2>$null
    if ($LASTEXITCODE -ne 0) {
        psmux new-session -d -s $name -c $selected
        if ($LASTEXITCODE -ne 0) {
            Write-Error "psmux new-session failed for '$name' (path=$selected)"
            exit 1
        }
    }
} finally {
    # Don't restore yet - we need to switch while nesting guard is bypassed
}

# Switch or attach while outside the nesting context
if ($wasInside) {
    # psmux's CLI routes switch-client to the server named by $TMUX; with no
    # (or stale) $TMUX it falls back to the most-recent registry session.
    # Popup children (prefix+f) are spawned with PSMUX_SESSION and
    # PSMUX_TARGET_SESSION but no $TMUX of their own, or one inherited from a
    # server that no longer matches, so the request lands on a server none of
    # our clients is attached to and the SWITCH directive is silently dropped
    # (created-but-never-switched). PSMUX_SESSION is the ground truth for
    # which session's client this shell belongs to, so point $TMUX at that
    # session's port file. Only the switch-client child below inherits it: it
    # is restored immediately after, so the new server above - already
    # spawned - and the calling shell never see the synthetic value.
    $origTmux = $env:TMUX
    $rebuiltTmux = $false
    if ($session) {
        $portFile = Join-Path $env:USERPROFILE ".psmux\$session.port"
        if (Test-Path $portFile) {
            $port = (Get-Content $portFile -Raw).Trim()
            if ($port) {
                $env:TMUX = "psmux-sessionizer,$port,0"
                $rebuiltTmux = $true
            }
        }
    }

    psmux switch-client -t $name

    # Restore the caller's routing state before anything else inherits this.
    if ($rebuiltTmux) { $env:TMUX = $origTmux }
} else {
    psmux attach $name
}

# Restore original nesting state
$env:PSMUX_SESSION = $session
