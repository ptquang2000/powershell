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
    $sessions = psmux -L shared list-sessions 2>$null
    if ($LASTEXITCODE -eq 0 -and $sessions) {
        $currentSession = psmux -L shared display-message -p '#S' 2>$null
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

# Clear nesting guard (psmux blocks commands when PSMUX_SESSION is set)
$savedPsmuxSession = $env:PSMUX_SESSION
$env:PSMUX_SESSION = $null
try {
    psmux -L shared has-session -t $sessionName 2>$null
    if ($LASTEXITCODE -ne 0) {
        psmux -L shared new-session -d -s $sessionName -c $Selected
    }

    if ($env:TMUX) {
        psmux -L shared switch-client -t $sessionName
    } else {
        psmux -L shared attach -t $sessionName
    }
} finally {
    $env:PSMUX_SESSION = $savedPsmuxSession
}
