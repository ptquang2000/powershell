$script:PromptGlyphNormal = [char]0x00B7
$script:PromptViMode      = 'Insert'

function prompt {
    $lec = $LASTEXITCODE

    $e       = [char]27
    $reset   = "$e[0m"
    $gray    = "$e[38;2;146;131;116m"
    $magenta = "$e[38;2;211;134;155m"

    $sb = [System.Text.StringBuilder]::new()

    if ($env:SSH_CLIENT -or $env:SSH_TTY) {
        [void]$sb.Append("$gray$([System.Net.Dns]::GetHostName())$reset ")
    }

    if ($env:VIRTUAL_ENV) {
        [void]$sb.Append("$gray$(Split-Path -Leaf $env:VIRTUAL_ENV)$reset ")
    }

    $path = $ExecutionContext.SessionState.Path.CurrentLocation.Path
    if ($path.StartsWith($HOME, [System.StringComparison]::OrdinalIgnoreCase)) {
        $path = '~' + $path.Substring($HOME.Length)
    }
    $segs = @($path -split '[\\/]+' | Where-Object { $_ -ne '' })
    if ($segs.Count -gt 2) { $segs = $segs[-2..-1] }
    [void]$sb.Append($gray + ($segs -join "$reset/$gray") + "$reset ")

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

    [void]$sb.Append("`n")
    if ($script:PromptViMode -eq 'Command') {
        [void]$sb.Append("$gray$script:PromptGlyphNormal$reset")
    }

    $global:LASTEXITCODE = $lec
    $sb.ToString()
}
