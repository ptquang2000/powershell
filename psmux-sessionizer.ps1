#!/usr/bin/env pwsh
# psmux-sessionizer - tmux-sessionizer for psmux on Windows
# Usage: psmux-sessionizer [path]
# If no path given, uses fzf to pick from existing sessions + directories.
# Works both outside and inside a psmux session.

param([string]$selected)

$searchPaths = @(
    "$env:USERPROFILE",
    "$env:USERPROFILE\work"
)
$pathDepth = 0
$session = $env:PSMUX_SESSION

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
    $env:PSMUX_SESSION = $session
    if ($env:TMUX -or $session) {
        psmux switch-client -t $name
    } else {
        psmux attach $name
    }
}
