#!/usr/bin/env pwsh
# psmux-sessionizer - tmux-sessionizer for psmux on Windows
# Usage: psmux-sessionizer [path]
# If no path given, uses fzf to pick from existing sessions + directories.
# Works both outside and inside a psmux session.

param([string]$Selected)

$searchPaths = @(
    "$env:USERPROFILE"
)
$pathDepth = 1

if (-not $Selected) {
    $candidates = @()

    $currentSession = $null
    $sessions = psmux list-sessions 2>$null
    if ($LASTEXITCODE -eq 0 -and $sessions) {
        $currentSession = psmux display-message -p '#S' 2>$null
        foreach ($line in $sessions -split "`n") {
            if ($line -match '^([^:]+):') {
                $name = $Matches[1].Trim()
                if ($name -ne $currentSession) {
                    $candidates += "[PSMUX] $name"
                }
            }
        }
    }

    $candidates += Get-ChildItem -Path $searchPaths -Recurse -Depth $pathDepth -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/]\.git([\\/]|$)' } |
        ForEach-Object { $_.FullName }

    $Selected = $candidates | fzf
}

if (-not $Selected) { exit 0 }

if ($Selected -match '^\[PSMUX\]\s+(.+)$') {
    $sessionName = $Matches[1].Trim()
} else {
    $dirName = Split-Path $Selected -Leaf
    $sessionName = $dirName -replace '\.', '_'
}

# psmux's nesting guard silently no-ops new-session and attach when
# PSMUX_SESSION is set. Clear it for those calls; switch-client is unaffected.
#
# Note: we intentionally do NOT use `-L shared`. psmux 3.3.3 has a bug where
# `switch-client` calls `list_session_names()` without a namespace filter, so
# any session stored under a socket namespace (port file `<socket>__<name>.port`)
# is filtered out and becomes unreachable via `switch-client -t <name>`. Using
# the default namespace keeps sessions visible to switch-client.
$savedPsmuxSession = $env:PSMUX_SESSION
try {
    psmux has-session -t $sessionName 2>$null
    if ($LASTEXITCODE -ne 0) {
        $env:PSMUX_SESSION = $null
        psmux new-session -d -s $sessionName -c $Selected
        $createExit = $LASTEXITCODE
        $env:PSMUX_SESSION = $savedPsmuxSession
        psmux has-session -t $sessionName 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "psmux new-session failed for '$sessionName' (exit=$createExit, path=$Selected)"
            exit 1
        }
    }

    if ($env:TMUX) {
        psmux switch-client -t $sessionName
    } else {
        $env:PSMUX_SESSION = $null
        psmux attach -t $sessionName
    }
} finally {
    $env:PSMUX_SESSION = $savedPsmuxSession
}
