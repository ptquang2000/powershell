#!/usr/bin/env pwsh
# psmux-sessionizer - tmux-sessionizer for psmux on Windows
# Usage: psmux-sessionizer [path]
# If no path given, uses fzf to pick from existing sessions + directories.
# Works both outside and inside a psmux session.

param([string]$Selected)

$searchPaths = @(
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\work",
    "$env:USERPROFILE\.local\bin",
    "$env:USERPROFILE\.config"
)

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

    $candidates += Get-ChildItem -Path $searchPaths -Recurse -Depth 2 -Directory -ErrorAction SilentlyContinue |
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

    psmux has-session -t $sessionName 2>$null
    if ($LASTEXITCODE -ne 0) {
        psmux new-session -d -s $sessionName
        psmux send-keys -t $sessionName "cd '$Selected'" Enter
    }
}

if ($env:TMUX) {
    # psmux switch-client CLI is broken — it returns 0 but never switches.
    # psmux attach from inside nests clients and corrupts the terminal.
    # The only reliable switch mechanism is psmux's internal choose-session.
    # Open it so the user can confirm the target (newly created or existing).
    psmux choose-session
} else {
    psmux attach -t $sessionName
}
