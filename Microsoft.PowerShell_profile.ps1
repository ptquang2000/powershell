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
Function buildtools { & "C:\BuildTools\Common7\Tools\VsDevCmd.bat" @args }
Function crosscompiler { & "C:\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" @args }
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

if (-not $env:NVIM_LOG_FILE) {
	# Use $env:TMUX (set by psmux in every pane) instead of spawning
	# psmux display-message.  The old approach returned exit-code 0 even
	# from *outside* psmux when a server was already running, making the
	# check unreliable and also adding ~200 ms startup latency.
	if (-not $env:TMUX) {
		Set-Location -Path $env:HOMEPATH
	}
}

# oh-my-posh
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $script:OmpTheme = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\material.omp.json"
    try {
        oh-my-posh init pwsh --config $script:OmpTheme | Invoke-Expression
    } catch {
        Write-Warning "oh-my-posh failed to load: $_"
    }
}

# Emit OSC 7 (CWD reporting) after every command so psmux can track
# #{pane_current_path} reliably on Windows (no /proc/PID/cwd fallback).
# Wraps whatever prompt is already active (oh-my-posh, Starship, etc.).
if ($env:TMUX) {
    $script:__OrigPromptFn = $function:prompt
    function prompt {
        $uri = 'file://localhost/' + ($PWD.ProviderPath -replace '\\','/')
        [Console]::Write("`e]7;${uri}`e\")
        if ($script:__OrigPromptFn) { & $script:__OrigPromptFn } else { "PS> " }
    }
}

# Project Env
$env:QT_DIR="C:\Qt\5.15.10\msvc2017\"
$env:QT_ARM64_DIR="C:\Qt\5.15.10\win32-arm64-msvc2017\"
$env:PATH+=";$env:QT_DIR;$env:QT_DIR\bin"
