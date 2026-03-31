#!/usr/bin/env pwsh
# psmux-sessionizer - tmux-sessionizer for psmux on Windows
# Usage: psmux-sessionizer [path]
# If no path given, uses fzf to pick a directory.

param([string]$Selected)

if ($env:TMUX) { exit 0 }

$searchPaths = @(
    "$env:USERPROFILE\Documents",
    "$env:USERPROFILE\Downloads",
    "$env:USERPROFILE\work",
    "$env:USERPROFILE\.local\bin",
    "$env:USERPROFILE\.config"
)

if (-not $Selected) {
    $Selected = Get-ChildItem -Path $searchPaths -Recurse -Depth 2 -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/]\.git([\\/]|$)' } |
        ForEach-Object { $_.FullName } |
        fzf
}

if (-not $Selected) { exit 0 }

$dirName = Split-Path $Selected -Leaf
$sessionName = $dirName -replace '\.', '_'

psmux has-session -t $sessionName 2>$null
if ($LASTEXITCODE -ne 0) {
    psmux new-session -d -s $sessionName
    psmux send-keys -t $sessionName "cd '$Selected'" Enter
}

psmux attach -t $sessionName
