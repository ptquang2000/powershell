# Skip expensive profile setup when pwsh is invoked as a one-shot command
# wrapper (e.g., psmux wraps `new-window <cmd>` as `pwsh -NoLogo -Command <cmd>`).
# Interactive panes use `-NoExit` so they still load the full profile.
$__cmdline = [Environment]::GetCommandLineArgs()
if (($__cmdline -match '^-(Command|c|EncodedCommand|e|File|f)$') -and
    -not ($__cmdline -match '^-NoExit$')) {
    return
}
Remove-Variable __cmdline

Import-Module CompletionPredictor

Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -PredictionViewStyle InlineView
Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord 
Set-PSReadLineKeyHandler -Key End -Function AcceptSuggestion
Set-PSReadLineKeyHandler -Chord 'Tab' -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+Backspace' -Function BackwardKillWord
Set-PSReadLineOption -ShowToolTips
Set-PSReadLineOption -CompletionQueryItems 65

# Update Path Environment Variable

$env:Path += ";C:\Python314;C:\Python314\Scripts"
$env:Path += ";C:\Strawberry\perl\bin"

# Add .PY to PATHEXT
if ($env:PATHEXT -notlike '*.PY*') {
    $env:PATHEXT += ';.PY'
}

# Add every BIN_DIR and BIN_DIR\bin to PATH
$BIN_DIR = Join-Path $env:USERPROFILE ".local\bin"
if (Test-Path $BIN_DIR) {
    $paths = foreach ($d in [System.IO.Directory]::GetDirectories($BIN_DIR)) {
        $bin = [System.IO.Path]::Combine($d, "bin")
        if ([System.IO.Directory]::Exists($bin)) { $bin } else { $d }
    }
    if ($paths) { $env:PATH += ';' + ($paths -join ';') }
}

Write-Host "`nPATH added`n"

# VS and Tools shortcuts (PowerShell functions)
Function vs2017 { & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\Professional\Common7\IDE\devenv.exe" @args }
Function vs2022 { & "$env:ProgramFiles\Microsoft Visual Studio\2022\Professional\Common7\IDE\devenv.exe" @args }
Function Invoke-VsBatEnv([string]$BatPath, [string[]]$BatArgs) {
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        $quoted = ($BatArgs | ForEach-Object { "`"$_`"" }) -join ' '
        cmd /c " `"$BatPath`" $quoted && set > `"$tmp`" " 2>&1 | Write-Host
        Get-Content $tmp | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process')
            }
        }
    } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
}
Function buildtools { Invoke-VsBatEnv "C:\BuildTools\Common7\Tools\VsDevCmd.bat" $args }
Function crosscompiler { Invoke-VsBatEnv "C:\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" $args }
Function cp_sdk { & "$env:USERPROFILE\.local\bin\sync-bin\cp_sdk.bat" @args }
Function sync_bin { python "$env:USERPROFILE\work\sync-bin\sync.py" @args }
Function gen_prj { python "$env:USERPROFILE\work\upd-sln\gen_prj.py" @args }

# To set WIX (currently commented out):
# $env:WIX = "$env:USERPROFILE\wix311-binaries"

# Set JAVA_HOME
$env:JAVA_HOME = "C:\jdk-21"

# Add scripts and VMWare to Path
$env:Path += ";$env:USERPROFILE\.local\bin\scripts;${env:ProgramFiles(x86)}\VMWare\VMWare Workstation"

# Ctrl+F triggers psmux-sessionizer (create/switch sessions via fzf)
$script:PsmuxSessionizerPath = Join-Path $PSScriptRoot 'psmux-sessionizer.ps1'
Set-PSReadLineKeyHandler -Key Ctrl+f -ScriptBlock {
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert("& '$script:PsmuxSessionizerPath'")
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

# oh-my-posh
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    try {
        oh-my-posh init pwsh --config material | Invoke-Expression
    } catch {
        Write-Warning "oh-my-posh failed to load: $_"
    }
}

# Project Env
$env:QT_DIR="C:\Qt\5.15.10\msvc2017\"
$env:QT_ARM64_DIR="C:\Qt\5.15.10\win32-arm64-msvc2017\"
$env:PATH+=";$env:QT_DIR;$env:QT_DIR\bin"
